extends "res://tests/base_test.gd"
## Leitor de plantas em mapa de texto (PlanParser): formato, validação, peças de várias células,
## paredes e faces, itens de parede e de cima de móvel, vagas, rotas, zonas, saída, seed e espelho.

const PlanParser := preload("res://scripts/interior/plan_parser.gd")


## Grade P (40x23) com borda de parede e piso livre dentro.
static func _grid(fill := ".", border := "#") -> Array:
	var size: Vector2i = PlanParser.SIZES["P"]
	var rows: Array = []
	for y in size.y:
		var row := ""
		for x in size.x:
			var edge := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			row += border if edge and border != "" else fill
		rows.append(row)
	return rows


## Escreve `text` na grade a partir de (x, y).
static func _stamp(rows: Array, x: int, y: int, text: String) -> void:
	var row: String = rows[y]
	rows[y] = row.substr(0, x) + text + row.substr(x + text.length())


## Planta mínima válida: sala única, saída de 3 células, uma cama de casal, uma janela,
## um sofá com uma pessoa sentada, uma enfermeira em ronda e uma zona.
static func fixture() -> Dictionary:
	var floor_grid := _grid("w", "w")
	var objects := _grid()
	var detail := _grid(".", ".")
	_stamp(objects, 19, 22, "EEE")
	_stamp(objects, 5, 0, "J")
	for y in range(2, 5):
		_stamp(objects, 3, y, "bbb")
	_stamp(objects, 10, 3, "sss")
	_stamp(detail, 11, 3, "2")
	_stamp(detail, 20, 10, "1")
	_stamp(detail, 26, 10, "a")
	_stamp(detail, 26, 14, "a")
	_stamp(detail, 30, 6, "$$$")
	_stamp(detail, 30, 7, "$$$")
	_stamp(objects, 15, 3, "t")
	_stamp(detail, 15, 3, "p")
	return {
		"size": "P",
		"floor_grid": floor_grid,
		"object_grid": objects,
		"detail_grid": detail,
		"floor_legend": {"w": {"room": "Sala", "floor": "floor/wood", "wall": "plaster_cream"}},
		"object_legend": {
			"b": {"item": "double_bed", "size": [2.5, 2.5], "align": "top"},
			"s": {"item": "sofa", "size": [3, 1]},
			"t": {"item": "table"},
			"J": {"wall_item": "window"},
		},
		"detail_legend": {
			"1": {"npc": "enfermeiro", "staff": true, "act": "patrol", "route": "a", "facing": "left"},
			"2": {"npc": "morador", "act": "sit"},
			"a": {"route": "a"},
			"$": {"zone": "heal"},
			"p": {"on": "plate", "size": [0.5, 0.5]},
		},
		"variants": [],
	}


func _has_error(errors: Array, fragment: String) -> bool:
	for e in errors:
		if (e as String).contains(fragment):
			return true
	return false


func test_valid_fixture_has_no_errors() -> void:
	assert_eq(PlanParser.validate(fixture()), [] as Array[String])


func test_errors_point_to_line_column_and_letter() -> void:
	var short := fixture()
	short.object_grid[3] = (short.object_grid[3] as String).substr(0, 30)
	assert_true(_has_error(PlanParser.validate(short), "linha 3"), str(PlanParser.validate(short)))
	var unknown := fixture()
	_stamp(unknown.object_grid, 8, 8, "Z")
	assert_true(_has_error(PlanParser.validate(unknown), "Z"))
	var bent := fixture()
	_stamp(bent.object_grid, 8, 10, "ss")
	_stamp(bent.object_grid, 8, 11, "s")
	assert_true(_has_error(PlanParser.validate(bent), "retangular"))
	var no_exit := fixture()
	_stamp(no_exit.object_grid, 19, 22, "###")
	assert_true(_has_error(PlanParser.validate(no_exit), "saída"))


func test_sizes_match_the_spec() -> void:
	assert_eq(PlanParser.SIZES["P"] * 32, Vector2i(1280, 736))
	assert_eq(PlanParser.SIZES["M"] * 32, Vector2i(1536, 864))
	assert_eq(PlanParser.SIZES["G"] * 32, Vector2i(1792, 1024))


func _items(parsed: Dictionary, kind: String) -> Array:
	var result := []
	for item in parsed.items:
		if item.kind == kind:
			result.append(item)
	return result


func _unmirrored_id() -> int:
	for id in 50:
		if not PlanParser.parse(fixture(), id).mirrored:
			return id
	return -1


func test_multi_cell_piece_is_one_item_with_real_size() -> void:
	var parsed := PlanParser.parse(fixture(), _unmirrored_id())
	var beds := _items(parsed, "double_bed")
	assert_eq(beds.size(), 1)
	assert_eq(beds[0].rect.size, Vector2(80, 80))
	assert_almost_eq(beds[0].rect.position.y, 64.0)
	assert_almost_eq(beds[0].rect.position.x, 3 * 32 + 8.0)
	assert_true(beds[0].solid)
	assert_eq(beds[0].layer, "floor")


func test_walls_merge_and_faces_take_the_style_of_the_room_below() -> void:
	var parsed := PlanParser.parse(fixture(), _unmirrored_id())
	var top_runs := 0
	for wall in parsed.walls:
		if wall.position.y == 0.0:
			top_runs += 1
			assert_eq(wall.size.y, 32.0)
	assert_eq(top_runs, 1, "a borda de cima (com a janela) vira um só retângulo")
	assert_gt(float(parsed.wall_faces.size()), 0.0)
	var face: Dictionary = parsed.wall_faces[0]
	assert_eq(face.style, "plaster_cream")
	assert_eq(face.rect.size.y, PlanParser.FACE_H)
	assert_eq(face.rect.position.y, 32.0)


func test_thin_walls_are_16_px() -> void:
	var plan := fixture()
	for y in range(10, 14):
		_stamp(plan.object_grid, 6, y, "|")
	assert_eq(PlanParser.validate(plan), [] as Array[String])
	var parsed := PlanParser.parse(plan, _unmirrored_id())
	var found := false
	for wall in parsed.walls:
		if wall.size.x == 16.0:
			found = true
			assert_almost_eq(wall.position.x, 6 * 32 + 8.0)
			assert_eq(wall.size.y, 128.0)
	assert_true(found)


func test_wall_item_sits_on_the_face() -> void:
	var parsed := PlanParser.parse(fixture(), _unmirrored_id())
	var windows := _items(parsed, "window")
	assert_eq(windows.size(), 1)
	assert_eq(windows[0].layer, "wall")
	assert_false(windows[0].solid)
	assert_eq(windows[0].rect.position.y, 32.0)
	assert_eq(windows[0].rect.size.y, 24.0)


func test_detail_layer_people_routes_zones_and_on_items() -> void:
	var parsed := PlanParser.parse(fixture(), _unmirrored_id())
	var nurse: Dictionary = {}
	for slot in parsed.npc_slots:
		if slot.role == "enfermeiro":
			nurse = slot
	assert_false(nurse.is_empty())
	assert_eq(nurse.act, "patrol")
	assert_true(nurse.staff)
	assert_eq(nurse.route.size(), 3)
	assert_eq(nurse.position, Vector2(20 * 32 + 16, 10 * 32 + 16))
	assert_eq(parsed.zones.size(), 1)
	assert_eq(parsed.zones[0].id, "heal")
	assert_eq(parsed.zones[0].rect.size, Vector2(96, 64))
	var plates := _items(parsed, "plate")
	assert_eq(plates.size(), 1)
	assert_eq(plates[0].layer, "on")
	assert_false(plates[0].solid)
	assert_eq(plates[0].rect.size, Vector2(16, 16))


func test_seated_npc_must_be_on_a_seat() -> void:
	var plan := fixture()
	_stamp(plan.detail_grid, 25, 18, "3")
	plan.detail_legend["3"] = {"npc": "cliente", "act": "sit"}
	assert_true(_has_error(PlanParser.validate(plan), "assento"))
	assert_eq(PlanParser.validate(fixture()), [] as Array[String], "o morador está sobre o sofá")


func test_exit_and_spawn() -> void:
	var parsed := PlanParser.parse(fixture(), _unmirrored_id())
	var exit: Rect2 = parsed.exit
	assert_almost_eq(exit.end.y, parsed.size.y)
	assert_eq(exit.size.x, 96.0)
	assert_almost_eq(parsed.spawn.x, exit.get_center().x)
	assert_almost_eq(parsed.spawn.y, parsed.size.y - 48.0)


func test_parse_is_deterministic_and_mirrors_some() -> void:
	assert_eq(str(PlanParser.parse(fixture(), 7)), str(PlanParser.parse(fixture(), 7)))
	var mirrored := 0
	var sample: Dictionary = {}
	for id in 40:
		var parsed := PlanParser.parse(fixture(), id)
		if parsed.mirrored:
			mirrored += 1
			sample = parsed
	assert_true(mirrored > 8 and mirrored < 32, "%d espelhados" % mirrored)
	for slot in sample.npc_slots:
		if slot.role == "enfermeiro":
			assert_eq(slot.facing, "right")
			assert_eq(slot.position, Vector2(1280 - (20 * 32 + 16), 10 * 32 + 16))
			assert_eq(slot.route[1], Vector2(1280 - (26 * 32 + 16), 10 * 32 + 16))


func test_chance_and_variants_vary_by_seed() -> void:
	var plan := fixture()
	plan.object_legend["t"] = {"item": "table", "chance": 0.5}
	plan.variants = [{}, {"floors": {"w": "floor/tile"}, "walls": {"w": "brick"}, "tones": {"sofa": "blue"}}]
	var tables := {}
	var floors := {}
	var tones := {}
	for id in 30:
		var parsed := PlanParser.parse(plan, id)
		tables[_items(parsed, "table").size()] = true
		floors[parsed.floor_rects[0].floor] = true
		tones[_items(parsed, "sofa")[0].tone] = true
	assert_eq(tables.size(), 2, "a mesa opcional aparece em uns e não em outros")
	assert_true(floors.has("floor/wood") and floors.has("floor/tile"))
	assert_true(tones.has("") and tones.has("blue"))


func test_rugs_live_in_the_floor_grid_under_furniture() -> void:
	var plan := fixture()
	for y in range(9, 13):
		_stamp(plan.floor_grid, 4, y, "RRRRR")
	_stamp(plan.object_grid, 5, 10, "tt")
	plan.floor_legend["R"] = {"room": "Sala", "floor": "floor/wood", "wall": "plaster_cream", "rug": "rug", "tone": "blue"}
	assert_eq(PlanParser.validate(plan), [] as Array[String])
	var parsed := PlanParser.parse(plan, _unmirrored_id())
	var rugs := _items(parsed, "rug")
	assert_eq(rugs.size(), 1)
	assert_eq(rugs[0].rect, Rect2(4 * 32, 9 * 32, 160, 128))
	assert_false(rugs[0].solid)
	assert_eq(rugs[0].layer, "floor")
	assert_eq(rugs[0].tone, "blue")
	assert_eq(parsed.items[0].kind, "rug", "o tapete vem antes dos móveis (fica embaixo)")
	_stamp(plan.floor_grid, 9, 12, "R")
	assert_true(_has_error(PlanParser.validate(plan), "retangular"))


func test_piece_bigger_than_its_block_is_an_error() -> void:
	var plan := fixture()
	plan.object_legend["t"] = {"item": "table", "size": [2, 1]}
	assert_true(_has_error(PlanParser.validate(plan), "maior que o bloco"))


func test_legend_cannot_redefine_fixed_symbols() -> void:
	var plan := fixture()
	plan.object_legend["D"] = {"item": "desk"}
	assert_true(_has_error(PlanParser.validate(plan), "símbolo fixo"))
