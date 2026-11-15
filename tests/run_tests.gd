extends SceneTree
## Executa todos os testes de res://tests/unit/test_*.gd.
## Uso: godot --headless --path . -s tests/run_tests.gd
## Por padrão só mostra os problemas (arquivo e testes com falha, mais o resumo final).
## Para listar todos os testes: ... -s tests/run_tests.gd -- verbose
## Filtro por arquivo: `-- combat traffic` (combina com `verbose`).
## Código de saída: 0 = tudo passou, 1 = falhas.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	_run_all()


## Zera o estado global dos autoloads antes de cada teste.
func _reset_globals() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.reset_players()
	var score := root.get_node_or_null("Score")
	if score != null:
		score.reset()
	var clock := root.get_node_or_null("WorldClock")
	if clock != null:
		clock.reset()
	var transition := root.get_node_or_null("Transition")
	if transition != null:
		transition.reset()


func _run_all() -> void:
	var total := 0
	var failed := 0
	var assertions := 0

	var files: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	# Filtro opcional: `-- combat traffic` roda só os arquivos cujo nome contém um dos termos.
	var only: Array = []
	var verbose := false
	for arg in OS.get_cmdline_user_args():
		if arg in ["verbose", "-v", "--verbose"]:
			verbose = true
		else:
			only.append(arg)
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			var wanted := only.is_empty()
			for term in only:
				if f.contains(term):
					wanted = true
			if wanted:
				files.append(f)
	files.sort()

	for f in files:
		if verbose:
			print("\n== %s" % f)
		var script: GDScript = load("%s/%s" % [TEST_DIR, f])
		if script == null or not script.can_instantiate():
			failed += 1
			total += 1
			print("FALHA %s: não foi possível carregar o script (erro de parse?)" % f)
			continue
		var announced := false
		var names: Array[String] = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				names.append(m.name)
		names.sort()
		for test_name in names:
			var t = script.new()
			t.tree = self
			total += 1
			_reset_globals()
			await t.before_each()
			await t.call(test_name)
			await t.after_each()
			assertions += t.assertions
			if t.failures.is_empty():
				if verbose:
					print("  ok    %s" % test_name)
			else:
				failed += 1
				if not verbose and not announced:
					print("\n== %s" % f)
					announced = true
				print("  FALHA %s" % test_name)
				for msg in t.failures:
					print("        - %s" % msg)

	print("%d testes, %d asserções, %d falha(s)" % [total, assertions, failed])
	quit(1 if failed > 0 else 0)
