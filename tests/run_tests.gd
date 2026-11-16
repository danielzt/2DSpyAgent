extends SceneTree
## Executa os testes de res://tests/unit/test_*.gd num único processo.
## Uso: godot --headless --fixed-fps 60 --path . -s tests/run_tests.gd
## Por padrão só mostra os problemas (arquivo e testes com falha, mais o resumo final).
## Para listar todos os testes: ... -s tests/run_tests.gd -- verbose
## Filtro por arquivo: `-- combat traffic` (combina com `verbose`).
## Suíte inteira em paralelo (mais rápido): tests/run_parallel.gd (ver docs/testes.md).
## Modo lote (usado por run_parallel.gd): `-- plan=<json> shard=<i> out=<json>` roda só os testes do
## lote `i` do plano e grava o resultado em `out`.
## Código de saída: 0 = tudo passou, 1 = falhas.

const Lib := preload("res://tests/runner_lib.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const SaveGame := preload("res://scripts/save/save_game.gd")
const Options := preload("res://scripts/save/options.gd")
const Fx := preload("res://scripts/effects/fx.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")

## Filhos de `root` que existiam antes dos testes (autoloads); o resto é sobra de teste.
var _baseline := {}


func _initialize() -> void:
	# save e opções de teste: nunca tocam nos arquivos do jogador, e cada processo tem os seus
	# (vários runners podem rodar ao mesmo tempo, em paralelo ou em worktrees diferentes)
	var pid := OS.get_process_id()
	SaveGame.path = "user://test_save_%d.json" % pid
	Options.path = "user://test_options_%d.cfg" % pid
	_run_all()


## Zera o estado global dos autoloads antes de cada teste.
func _reset_globals() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.reset_players()
		game_state.autosave = false
	var score := root.get_node_or_null("Score")
	if score != null:
		score.reset()
	var clock := root.get_node_or_null("WorldClock")
	if clock != null:
		clock.reset()
	SaveGame.delete()
	Options.fullscreen = false
	Options.volume = Options.MAX_VOLUME
	Options.shake = true
	# a largura das ruas é estado estático: volta à da cidade padrão entre os testes
	CityLayout.use_seed(2024)
	var transition := root.get_node_or_null("Transition")
	if transition != null:
		transition.reset()
	Fx.reset()
	Plans.clear_overrides()


## Libera o que o teste deixou pendurado em `root` (partículas, itens no chão, cenas): sem isso o
## resultado de um teste dependia de quem rodou antes dele, o que quebrava a divisão em lotes.
func _free_leftovers() -> void:
	var freed := false
	for child in root.get_children():
		if not _baseline.has(child.get_instance_id()):
			child.queue_free()
			freed = true
	if freed:
		await process_frame


## Testes a rodar, agrupados por arquivo: [[arquivo, [métodos] ou null = todos], ...].
func _selection(args: Dictionary) -> Array:
	var groups: Array = []
	if args.options.has("plan"):
		var plan: Variant = Lib.load_json(args.options.plan)
		var shard := int(args.options.get("shard", "0"))
		if not plan is Array or shard >= plan.size():
			push_error("plano de testes inválido: %s (lote %d)" % [args.options.plan, shard])
			return groups
		for id in plan[shard]:
			var file := Lib.file_of(id)
			if groups.is_empty() or groups[-1][0] != file:
				groups.append([file, []])
			groups[-1][1].append(Lib.method_of(id))
		return groups
	for f in Lib.list_files(Lib.TEST_DIR, args.only):
		groups.append([f, null])
	return groups


func _run_all() -> void:
	var args := Lib.parse_args(OS.get_cmdline_user_args())
	var verbose: bool = args.verbose
	var total := 0
	var failed := 0
	var assertions := 0
	var report: Array[String] = []   # linhas de falha (também vão para o resultado do lote)
	var slow: Array[String] = []
	var times := {}
	for child in root.get_children():
		_baseline[child.get_instance_id()] = true

	for group in _selection(args):
		var f: String = group[0]
		if verbose:
			print("\n== %s" % f)
		var script: GDScript = load("%s/%s" % [Lib.TEST_DIR, f])
		if script == null or not script.can_instantiate():
			failed += 1
			total += 1
			var line := "FALHA %s: não foi possível carregar o script (erro de parse?)" % f
			print(line)
			report.append(line)
			continue
		var announced := false
		var names: Array = group[1] if group[1] != null else Lib.test_methods(script)
		for test_name in names:
			var t = script.new()
			t.tree = self
			total += 1
			_reset_globals()
			var t0 := Time.get_ticks_msec()
			await t.before_each()
			await t.call(test_name)
			await t.after_each()
			await _free_leftovers()
			assertions += t.assertions
			var ms := Time.get_ticks_msec() - t0
			times[Lib.test_id(f, test_name)] = ms
			if ms >= 500:
				var slow_line := "  [lento] %s: %d ms" % [test_name, ms]
				print(slow_line)
				slow.append(slow_line)
			if t.failures.is_empty():
				if verbose:
					print("  ok    %s" % test_name)
			else:
				failed += 1
				if not announced:
					report.append("\n== %s" % f)
					if not verbose:
						print("\n== %s" % f)
					announced = true
				print("  FALHA %s" % test_name)
				report.append("  FALHA %s" % test_name)
				for msg in t.failures:
					print("        - %s" % msg)
					report.append("        - %s" % msg)

	_cleanup_files()
	if args.options.has("out"):
		Lib.save_json(args.options.out, {"total": total, "assertions": assertions, "failed": failed,
				"report": report, "slow": slow, "times": times})
	else:
		Lib.store_timings(times)   # equilibra os lotes de run_parallel.gd na próxima vez
	print(Lib.summary(total, assertions, failed))
	quit(1 if failed > 0 else 0)


## Apaga o save e as opções deste processo.
func _cleanup_files() -> void:
	SaveGame.delete()
	for path in [Options.path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
