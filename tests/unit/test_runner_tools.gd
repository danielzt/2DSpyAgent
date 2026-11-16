extends "res://tests/base_test.gd"
## Ferramentas da suíte: lógica do runner (argumentos, descoberta, lotes paralelos, soma dos
## resultados, tempos), cache de plantas dos testes e as asserções baratas `ok`/`fail`.

const Lib := preload("res://tests/runner_lib.gd")
const Layouts := preload("res://tests/layout_cache.gd")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")
const ParserTest := preload("res://tests/unit/test_plan_parser.gd")
const BaseTest := preload("res://tests/base_test.gd")

const TMP_TIMINGS := "user://test_runner_tools_timings.json"


func after_each() -> void:
	Plans.clear_overrides()
	if FileAccess.file_exists(TMP_TIMINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_TIMINGS))


# --- argumentos ---

func test_args_split_filters_verbose_and_options() -> void:
	var args := Lib.parse_args(PackedStringArray(["combat", "verbose", "jobs=6", "--plan=user://p.json", "traffic"]))
	assert_true(args.verbose)
	assert_eq(args.only, ["combat", "traffic"])
	assert_eq(args.options, {"jobs": "6", "plan": "user://p.json"})


func test_option_value_can_contain_equals() -> void:
	assert_eq(Lib.parse_args(PackedStringArray(["out=a=b"])).options.out, "a=b")


func test_no_args_means_everything() -> void:
	var args := Lib.parse_args(PackedStringArray())
	assert_false(args.verbose)
	assert_true(args.only.is_empty())
	assert_true(Lib.wanted("test_x.gd", []))


func test_file_filter_matches_any_term() -> void:
	assert_true(Lib.wanted("test_combat.gd", ["traffic", "combat"]))
	assert_false(Lib.wanted("test_npc.gd", ["traffic", "combat"]))


# --- descoberta ---

func test_methods_are_read_from_the_source() -> void:
	var src := "extends X\nfunc test_b() -> void:\n\tpass\nfunc _helper():\n\tpass\nfunc test_a(): pass\n# func test_comment()\n\tfunc test_indented():\n"
	assert_eq(Lib.test_methods_in_source(src), ["test_a", "test_b"] as Array[String])


func test_source_discovery_matches_the_loaded_script() -> void:
	# a leitura rápida pelo texto acha os mesmos métodos que o script carregado
	for f in Lib.list_files(Lib.TEST_DIR, ["runner_tools", "score", "plans"]):
		var path := "%s/%s" % [Lib.TEST_DIR, f]
		assert_eq(Lib.test_methods_in_source(FileAccess.get_file_as_string(path)), Lib.test_methods(load(path)), f)


func test_ids_cover_every_file_and_round_trip() -> void:
	var ids := Lib.list_test_ids(Lib.TEST_DIR, ["runner_tools"])
	assert_true(ids.has(Lib.test_id("test_runner_tools.gd", "test_ids_cover_every_file_and_round_trip")))
	var id := Lib.test_id("test_a.gd", "test_b")
	assert_eq(Lib.file_of(id), "test_a.gd")
	assert_eq(Lib.method_of(id), "test_b")


# --- lotes paralelos ---

func _flatten(lots: Array) -> Array:
	var all := []
	for lot in lots:
		all.append_array(lot)
	all.sort()
	return all


func _load_of(lot: Array, timings: Dictionary) -> int:
	var total := 0
	for id in lot:
		total += int(timings.get(id, Lib.DEFAULT_MS))
	return total


func test_every_test_lands_in_exactly_one_lot() -> void:
	var ids := []
	for i in 50:
		ids.append("test_f%d.gd::test_%d" % [i % 7, i])
	var lots := Lib.assign(ids, {}, 4)
	assert_eq(lots.size(), 4)
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	assert_eq(_flatten(lots), sorted_ids)


func test_slow_tests_are_spread_and_lots_are_balanced() -> void:
	var timings := {"a::slow1": 9000, "a::slow2": 8000, "b::slow3": 7000}
	var ids := ["a::slow1", "a::slow2", "b::slow3"]
	for i in 60:
		ids.append("c::t%02d" % i)
		timings["c::t%02d" % i] = 300
	var lots := Lib.assign(ids, timings, 3)
	for slow in ["a::slow1", "a::slow2", "b::slow3"]:
		var holders := 0
		for lot in lots:
			if lot.has(slow):
				holders += 1
				for other in ["a::slow1", "a::slow2", "b::slow3"]:
					if other != slow:
						assert_false(lot.has(other), "%s e %s no mesmo lote" % [slow, other])
		assert_eq(holders, 1)
	var loads := []
	for lot in lots:
		loads.append(_load_of(lot, timings))
	# total 42000 em 3 lotes: o maior não passa muito da média (14000)
	assert_true(loads.max() - loads.min() <= 1000, "lotes desequilibrados: %s" % [loads])


func test_lots_are_deterministic_and_sorted_inside() -> void:
	var ids := ["z::t1", "a::t2", "m::t3", "a::t1", "b::t9"]
	var lots_a := Lib.assign(ids, {"m::t3": 900}, 2)
	var lots_b := Lib.assign(ids.duplicate(), {"m::t3": 900}, 2)
	assert_eq(lots_a, lots_b)
	for lot in lots_a:
		var sorted_lot: Array = lot.duplicate()
		sorted_lot.sort()
		assert_eq(lot, sorted_lot, "lote em ordem de arquivo e método")


func test_never_more_lots_than_tests() -> void:
	assert_eq(Lib.assign(["a::t1", "a::t2"], {}, 8).size(), 2)
	assert_eq(Lib.assign(["a::t1"], {}, 0).size(), 1)
	assert_eq(Lib.assign([], {}, 4).size(), 0)


func test_default_jobs_is_half_the_cores_within_limits() -> void:
	assert_eq(Lib.default_jobs(1), 2)
	assert_eq(Lib.default_jobs(8), 4)
	assert_eq(Lib.default_jobs(64), 8)


# --- resultados e tempos ---

func test_results_are_summed() -> void:
	var merged := Lib.merge_results([
		{"total": 3, "assertions": 10, "failed": 1, "report": ["\n== test_a.gd", "  FALHA test_x"], "slow": ["  [lento] test_y: 900 ms"], "times": {"a::x": 5}},
		{"total": 2, "assertions": 4, "failed": 0, "report": [], "slow": [], "times": {"b::z": 7}},
	])
	assert_eq(merged.total, 5)
	assert_eq(merged.assertions, 14)
	assert_eq(merged.failed, 1)
	assert_eq(merged.report.size(), 2)
	assert_eq(merged.slow.size(), 1)
	assert_eq(merged.times, {"a::x": 5, "b::z": 7})
	assert_eq(Lib.summary(5, 14, 1), "5 testes, 14 asserções, 1 falha(s)")


func test_timings_are_merged_into_the_file() -> void:
	assert_eq(Lib.load_timings(TMP_TIMINGS), {})
	Lib.store_timings({"a::x": 10, "a::y": 20}, TMP_TIMINGS)
	Lib.store_timings({"a::y": 25, "b::z": 30}, TMP_TIMINGS)
	var t := Lib.load_timings(TMP_TIMINGS)
	assert_eq(int(t["a::x"]), 10)
	assert_eq(int(t["a::y"]), 25)
	assert_eq(int(t["b::z"]), 30)


func test_corrupted_timings_are_ignored() -> void:
	var file := FileAccess.open(TMP_TIMINGS, FileAccess.WRITE)
	file.store_string("[1, 2")
	file.close()
	assert_eq(Lib.load_timings(TMP_TIMINGS), {})


# --- cache de plantas ---

func test_cache_returns_the_same_layout_as_a_fresh_one() -> void:
	var cached = Layouts.layout(7, "bar")
	var fresh := InteriorLayout.new(7, "bar")
	assert_true(cached == Layouts.layout(7, "bar"), "a segunda chamada reaproveita a planta")
	assert_eq(str([cached.size, cached.items, cached.npc_slots, cached.walls, cached.zones]),
			str([fresh.size, fresh.items, fresh.npc_slots, fresh.walls, fresh.zones]))
	assert_false(cached == Layouts.layout(8, "bar"), "outro prédio, outra planta")
	assert_false(cached == Layouts.layout(7, "hotel"), "outro tipo, outra planta")


func test_cache_is_skipped_while_a_plan_is_injected() -> void:
	var before := Layouts.size()
	Plans.override("cinema", ParserTest.fixture())
	var injected = Layouts.layout(3, "cinema")
	assert_eq(injected.size, Vector2(1280, 736), "usa a planta injetada")
	assert_eq(Layouts.size(), before, "nada guardado com planta injetada")
	Plans.clear_overrides()
	assert_eq(Layouts.layout(3, "cinema").size, Vector2(1792, 1024), "volta à planta do cinema")
	assert_false(Plans.has_overrides())


# --- asserções baratas ---

func test_ok_counts_and_fail_records() -> void:
	var t = BaseTest.new()
	assert_true(t.ok(true))
	assert_false(t.ok(false))
	assert_eq(t.assertions, 2)
	assert_eq(t.failures.size(), 0, "ok() sozinho não falha")
	t.fail("deu errado")
	assert_eq(t.failures, ["deu errado"] as Array[String])


# --- isolamento entre testes (o runner libera sobras em root) ---
# Os dois rodam em ordem no mesmo processo: o primeiro deixa um nó pendurado de propósito.

func test_isolation_1_leaves_a_node_behind() -> void:
	var stray := Node2D.new()
	stray.add_to_group("runner_leftover_probe")
	tree.root.add_child(stray)
	assert_eq(tree.get_nodes_in_group("runner_leftover_probe").size(), 1)


func test_isolation_2_starts_with_a_clean_tree() -> void:
	assert_eq(tree.get_nodes_in_group("runner_leftover_probe").size(), 0, "sobra do teste anterior")
