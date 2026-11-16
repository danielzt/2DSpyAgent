extends RefCounted
## Lógica pura do runner de testes (sem nós), usada por `run_tests.gd` e `run_parallel.gd`:
## argumentos, descoberta dos testes, divisão em lotes paralelos e soma dos resultados.
## Testada em tests/unit/test_runner_tools.gd.

const TEST_DIR := "res://tests/unit"
## Peso (ms) de um teste sem tempo medido, na divisão em lotes.
const DEFAULT_MS := 100
## Onde o runner guarda o tempo de cada teste (por máquina, fora do git), para equilibrar os lotes.
const TIMINGS_PATH := "user://test_timings.json"
## Separador de "arquivo::método" nos ids de teste.
const SEP := "::"


## Lê os argumentos depois de `--`. Termos soltos filtram arquivos pelo nome; `verbose`/`-v` lista
## tudo; `chave=valor` vira opção (`jobs=6`, `plan=...`, `shard=2`, `out=...`).
static func parse_args(args: PackedStringArray) -> Dictionary:
	var result := {"verbose": false, "only": [], "options": {}}
	for arg in args:
		if arg in ["verbose", "-v", "--verbose"]:
			result.verbose = true
		elif arg.contains("="):
			var key := arg.get_slice("=", 0).trim_prefix("--")
			result.options[key] = arg.substr(arg.find("=") + 1)
		else:
			result.only.append(arg)
	return result


## O arquivo entra no filtro? (sem filtro, todos entram)
static func wanted(file_name: String, only: Array) -> bool:
	if only.is_empty():
		return true
	for term in only:
		if file_name.contains(term):
			return true
	return false


## Arquivos `test_*.gd` de `dir`, filtrados e em ordem.
static func list_files(dir_path: String, only: Array) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and wanted(f, only):
			files.append(f)
	files.sort()
	return files


## Métodos `test_*` de um script, em ordem.
static func test_methods(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for m in script.get_script_method_list():
		if String(m.name).begins_with("test_") and not names.has(m.name):
			names.append(m.name)
	names.sort()
	return names


## Métodos `test_*` lidos do código-fonte, sem carregar o script (rápido; usado para montar os lotes).
static func test_methods_in_source(source: String) -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.create_from_string("(?m)^func (test_\\w+)\\s*\\(")
	for m in regex.search_all(source):
		if not names.has(m.get_string(1)):
			names.append(m.get_string(1))
	names.sort()
	return names


## Todos os ids "arquivo::método" dos arquivos filtrados, lidos do código-fonte.
static func list_test_ids(dir_path: String, only: Array) -> Array[String]:
	var ids: Array[String] = []
	for f in list_files(dir_path, only):
		for method in test_methods_in_source(FileAccess.get_file_as_string("%s/%s" % [dir_path, f])):
			ids.append(test_id(f, method))
	return ids


static func test_id(file_name: String, method: String) -> String:
	return file_name + SEP + method


static func file_of(id: String) -> String:
	return id.get_slice(SEP, 0)


static func method_of(id: String) -> String:
	return id.get_slice(SEP, 1)


## Divide os testes em `shards` lotes de tempo parecido (maior primeiro, cada um no lote mais leve).
## Determinístico: empates resolvidos pelo id e pelo índice do lote. Lotes vazios são descartados.
static func assign(ids: Array, timings: Dictionary, shards: int) -> Array:
	var count := maxi(1, mini(shards, ids.size()))
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var wa: int = int(timings.get(a, DEFAULT_MS))
		var wb: int = int(timings.get(b, DEFAULT_MS))
		return wa > wb if wa != wb else a < b)
	var lots: Array = []
	var loads: Array[int] = []
	for i in count:
		lots.append([])
		loads.append(0)
	for id in sorted:
		var lightest := 0
		for i in count:
			if loads[i] < loads[lightest]:
				lightest = i
		lots[lightest].append(id)
		loads[lightest] += int(timings.get(id, DEFAULT_MS))
	var result: Array = []
	for lot in lots:
		if not lot.is_empty():
			lot.sort()   # dentro do lote, na ordem de sempre (arquivo e método)
			result.append(lot)
	return result


## Soma o resultado de vários lotes: totais, linhas de relatório e tempos.
static func merge_results(results: Array) -> Dictionary:
	var merged := {"total": 0, "assertions": 0, "failed": 0, "report": [], "slow": [], "times": {}}
	for r in results:
		merged.total += int(r.get("total", 0))
		merged.assertions += int(r.get("assertions", 0))
		merged.failed += int(r.get("failed", 0))
		merged.report.append_array(r.get("report", []))
		merged.slow.append_array(r.get("slow", []))
		var times: Dictionary = r.get("times", {})
		for id in times:
			merged.times[id] = int(times[id])
	return merged


## Linha final, igual à do runner sequencial.
static func summary(total: int, assertions: int, failed: int) -> String:
	return "%d testes, %d asserções, %d falha(s)" % [total, assertions, failed]


## Número padrão de processos: metade dos núcleos, entre 2 e 8.
static func default_jobs(cores: int) -> int:
	return clampi(cores / 2, 2, 8)


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	return JSON.parse_string(text)


static func save_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


## Tempos medidos antes (vazio se não houver).
static func load_timings(path := TIMINGS_PATH) -> Dictionary:
	var data: Variant = load_json(path)
	return data if data is Dictionary else {}


## Junta tempos novos aos que já existiam e grava.
static func store_timings(times: Dictionary, path := TIMINGS_PATH) -> void:
	var all := load_timings(path)
	for id in times:
		all[id] = int(times[id])
	save_json(path, all)
