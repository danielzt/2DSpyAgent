extends SceneTree
## Roda a suíte em vários processos do Godot ao mesmo tempo e junta o resultado.
## Uso: godot --headless --path . -s tests/run_parallel.gd [-- jobs=N] [-- termos de filtro]
## Divide os testes POR MÉTODO em N lotes de tempo parecido (tempos da última execução, em
## user://test_timings.json) e chama `tests/run_tests.gd -- plan=... shard=i out=...` em cada um.
## Mostra só as falhas, os testes lentos e o resumo (mesmo formato do runner sequencial).
## A saída completa de cada lote fica em user://test_runs/<pid>/lote_<i>.log quando algo falha.
## Código de saída: 0 = tudo passou, 1 = falhas.

const Lib := preload("res://tests/runner_lib.gd")
const POLL_MS := 20
const RUNS_DIR := "user://test_runs"
## Pastas de execuções antigas (falhas guardadas para consulta) somem depois disto.
const KEEP_SECONDS := 3600


func _initialize() -> void:
	var code := _run()
	quit(code)


func _run() -> int:
	var started := Time.get_ticks_msec()
	var args := Lib.parse_args(OS.get_cmdline_user_args())
	var jobs := int(args.options.get("jobs", str(Lib.default_jobs(OS.get_processor_count()))))
	var ids := Lib.list_test_ids(Lib.TEST_DIR, args.only)
	if ids.is_empty():
		print("nenhum teste encontrado")
		return 1
	var lots := Lib.assign(ids, Lib.load_timings(), jobs)

	_remove_old_runs()
	var run_dir := "%s/%d" % [RUNS_DIR, OS.get_process_id()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_dir))
	var plan_path := run_dir + "/plano.json"
	Lib.save_json(plan_path, lots)

	# um processo por lote
	var exe := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://")
	var children: Array[Dictionary] = []
	for i in lots.size():
		var out := "%s/lote_%d.json" % [run_dir, i]
		var child_args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", project,
				"-s", "res://tests/run_tests.gd", "--", "plan=" + plan_path, "shard=%d" % i, "out=" + out])
		var proc := OS.execute_with_pipe(exe, child_args, false)
		if proc.is_empty():
			print("FALHA: não foi possível iniciar o lote %d" % i)
			return 1
		var log_file := FileAccess.open("%s/lote_%d.log" % [run_dir, i], FileAccess.WRITE)
		children.append({"index": i, "pid": proc.pid, "stdio": proc.stdio, "stderr": proc.stderr,
				"log": log_file, "out": out, "done": false, "code": -1})

	# espera todos, esvaziando os pipes (senão o filho trava com o pipe cheio)
	var running := children.size()
	while running > 0:
		OS.delay_msec(POLL_MS)
		for c in children:
			if c.done:
				continue
			_drain(c)
			if not OS.is_process_running(c.pid):
				_drain(c)
				c.code = OS.get_process_exit_code(c.pid)
				c.done = true
				c.log.close()
				running -= 1

	# junta os resultados
	var results: Array = []
	var broken: Array[String] = []
	for c in children:
		var r: Variant = Lib.load_json(c.out)
		if r is Dictionary:
			results.append(r)
		else:
			broken.append("FALHA: o lote %d terminou sem resultado (código %d); saída em %s" % [
					c.index, c.code, ProjectSettings.globalize_path("%s/lote_%d.log" % [run_dir, c.index])])
	var merged := Lib.merge_results(results)
	var expected := 0
	for lot in lots:
		expected += lot.size()

	var slow: Array = merged.slow
	slow.sort()
	for line in slow:
		print(line)
	for line in merged.report:
		print(line)
	for line in broken:
		print(line)
	var failed: int = merged.failed + broken.size()
	if broken.is_empty() and merged.total != expected:
		print("FALHA: esperava %d testes, rodaram %d" % [expected, merged.total])
		failed += 1
	Lib.store_timings(merged.times)

	if failed == 0:
		_remove_dir(run_dir)
	else:
		print("saída completa de cada lote em %s" % ProjectSettings.globalize_path(run_dir))
	print("%d processos, %.1f s" % [lots.size(), (Time.get_ticks_msec() - started) / 1000.0])
	print(Lib.summary(merged.total, merged.assertions, failed))
	return 1 if failed > 0 else 0


## Copia para o log o que o filho já escreveu (pipes não bloqueantes).
func _drain(c: Dictionary) -> void:
	for key in ["stdio", "stderr"]:
		var pipe: FileAccess = c[key]
		if pipe == null:
			continue
		while true:
			var chunk := pipe.get_buffer(65536)
			if chunk.is_empty():
				break
			c.log.store_buffer(chunk)


## Apaga pastas de execuções com mais de KEEP_SECONDS. Não apaga as recentes: outro worktree
## pode estar rodando a suíte agora (a pasta user:// é a mesma para todos).
func _remove_old_runs() -> void:
	var dir := DirAccess.open(RUNS_DIR)
	if dir == null:
		return
	var now := int(Time.get_unix_time_from_system())
	for sub in dir.get_directories():
		var plan := "%s/%s/plano.json" % [RUNS_DIR, sub]
		var stamp := FileAccess.get_modified_time(plan) if FileAccess.file_exists(plan) else 0
		if now - stamp > KEEP_SECONDS:
			_remove_dir("%s/%s" % [RUNS_DIR, sub])


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
