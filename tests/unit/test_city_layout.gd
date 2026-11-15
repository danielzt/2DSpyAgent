extends "res://tests/base_test.gd"

const CityLayout := preload("res://scripts/world/city_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const Palette := preload("res://scripts/art/palette.gd")

var layout


func before_each() -> void:
	layout = CityLayout.new()


func _world() -> Rect2:
	return Rect2(0, 0, CityLayout.city_size(), CityLayout.city_size())


# --- ruas e calçadas ---

func test_street_corridor_is_asphalt_plus_two_sidewalks() -> void:
	assert_almost_eq(CityLayout.ROAD, CityLayout.ASPHALT + CityLayout.SIDEWALK * 2.0)
	assert_almost_eq(CityLayout.LOT, CityLayout.BLOCK - CityLayout.ROAD)
	assert_gt(CityLayout.SIDEWALK, 24.0, "calçada larga o bastante para pedestres")


func test_there_is_one_lot_per_block() -> void:
	assert_eq(layout.lots.size(), CityLayout.CELLS * CityLayout.CELLS)
	for i in layout.lots.size():
		var lot: Rect2 = layout.lots[i]
		var cx: int = i / CityLayout.CELLS
		var cy: int = i % CityLayout.CELLS
		assert_true(_world().encloses(lot))
		assert_eq(lot, CityLayout.lot_rect(cx, cy))
		# o lote é o que sobra entre os corredores das ruas em volta
		assert_almost_eq(lot.size.x, CityLayout.BLOCK - CityLayout.corridor(cx) / 2.0 - CityLayout.corridor(cx + 1) / 2.0)
		assert_almost_eq(lot.size.y, CityLayout.BLOCK - CityLayout.corridor(cy) / 2.0 - CityLayout.corridor(cy + 1) / 2.0)
	assert_almost_eq(layout.lots[0].size.x, CityLayout.LOT, 0.01, "lote entre ruas comuns")


func test_lots_leave_room_for_streets() -> void:
	# lotes vizinhos ficam separados pelo corredor inteiro (asfalto + calçadas)
	assert_almost_eq(layout.lots[CityLayout.CELLS].position.x - layout.lots[0].end.x, CityLayout.ROAD)


# --- avenidas ---

func test_two_avenues_cross_at_the_center_and_are_wider() -> void:
	var line := CityLayout.AVENUE_LINE
	assert_eq(line, CityLayout.CELLS / 2, "avenidas cruzam no centro")
	assert_true(CityLayout.is_avenue(line))
	assert_false(CityLayout.is_avenue(line - 1))
	assert_gt(CityLayout.asphalt(line), CityLayout.asphalt(1))
	assert_almost_eq(CityLayout.corridor(line), CityLayout.AVENUE_ASPHALT + CityLayout.SIDEWALK * 2.0)
	assert_almost_eq(CityLayout.corridor(1), CityLayout.ROAD)
	assert_almost_eq(CityLayout.AVENUE_ROAD, 240.0)


func test_lots_beside_an_avenue_are_narrower_on_that_axis() -> void:
	var line := CityLayout.AVENUE_LINE
	var shrink := (CityLayout.AVENUE_ROAD - CityLayout.ROAD) / 2.0
	for cell in [line - 1, line]:
		assert_almost_eq(CityLayout.lot_rect(cell, 0).size.x, CityLayout.LOT - shrink)
		assert_almost_eq(CityLayout.lot_rect(cell, 0).size.y, CityLayout.LOT)
		assert_almost_eq(CityLayout.lot_rect(0, cell).size.y, CityLayout.LOT - shrink)
	# os dois lotes vizinhos da avenida ficam separados pelo corredor inteiro dela
	var gap := CityLayout.lot_rect(line, 0).position.x - CityLayout.lot_rect(line - 1, 0).end.x
	assert_almost_eq(gap, CityLayout.AVENUE_ROAD)
	# a avenida horizontal continua na estrada do campo
	assert_almost_eq(line * CityLayout.BLOCK, 3360.0)


func test_no_building_stands_on_an_avenue() -> void:
	var axis := CityLayout.AVENUE_LINE * CityLayout.BLOCK
	var half := CityLayout.AVENUE_ROAD / 2.0
	for b in layout.buildings:
		var rect: Rect2 = b.rect
		assert_false(rect.intersects(Rect2(axis - half, 0, half * 2.0, CityLayout.city_size())), "prédio %d na avenida" % b.id)
		assert_false(rect.intersects(Rect2(0, axis - half, CityLayout.city_size(), half * 2.0)), "prédio %d na avenida" % b.id)


# --- prédios ---

func test_buildings_are_inside_their_lots_and_the_world() -> void:
	for b in layout.buildings:
		assert_true(_world().encloses(b.rect), "prédio %d fora do mundo" % b.id)
		var inside_a_lot := false
		for lot in layout.lots:
			if lot.grow(0.5).encloses(b.rect):
				inside_a_lot = true
		assert_true(inside_a_lot, "prédio %d invade a rua" % b.id)


func test_buildings_do_not_overlap() -> void:
	for i in layout.buildings.size():
		for j in range(i + 1, layout.buildings.size()):
			assert_false(layout.buildings[i].rect.intersects(layout.buildings[j].rect),
				"prédios %d e %d se sobrepõem" % [i, j])


func test_buildings_are_not_all_the_same_size() -> void:
	var sizes := {}
	for b in layout.buildings:
		sizes[(b.rect as Rect2).size] = true
	assert_gt(sizes.size(), 60.0, "prédios muito parecidos")


func test_building_footprints_vary_within_lots() -> void:
	var full := 0
	var smaller := 0
	for b in layout.buildings:
		if (b.rect as Rect2).size.x >= CityLayout.LOT - 1.0 and (b.rect as Rect2).size.y >= CityLayout.LOT - 1.0:
			full += 1
		else:
			smaller += 1
	assert_gt(smaller, 40.0)
	assert_true(full < layout.buildings.size() / 3, "poucos prédios devem ocupar o lote todo")


func test_some_lots_hold_two_buildings_and_some_are_parks() -> void:
	var per_lot := {}
	for b in layout.buildings:
		for i in layout.lots.size():
			if layout.lots[i].grow(0.5).encloses(b.rect):
				per_lot[i] = per_lot.get(i, 0) + 1
	var doubles := 0
	for k in per_lot:
		if per_lot[k] == 2:
			doubles += 1
	assert_gt(doubles, 10.0, "devem existir lotes divididos em dois prédios")
	assert_gt(layout.parks.size(), 5.0)
	assert_true(layout.lots.size() - per_lot.size() == layout.parks.size(), "lote sem prédio é parque")


func test_buildings_have_minimum_size() -> void:
	for b in layout.buildings:
		assert_true((b.rect as Rect2).size.x >= CityLayout.MIN_BUILDING - 0.01, "prédio %d estreito" % b.id)
		assert_true((b.rect as Rect2).size.y >= 240.0 - 0.01, "prédio %d baixo" % b.id)


func test_ids_are_sequential_and_unique() -> void:
	for i in layout.buildings.size():
		assert_eq(layout.buildings[i].id, i)
	assert_eq(layout.building_by_id(5).id, 5)
	assert_eq(layout.building_by_id(99999), {})


# --- portas ---

func test_door_is_on_the_bottom_edge_inside_the_building_width() -> void:
	for b in layout.buildings:
		var rect: Rect2 = b.rect
		var door: Rect2 = b.door
		assert_almost_eq(door.position.y, rect.end.y, 0.001)
		assert_true(door.position.x >= rect.position.x + 8.0 and door.end.x <= rect.end.x - 8.0, "porta fora do prédio %d" % b.id)


func test_doors_are_not_always_centered() -> void:
	var off_center := 0
	for b in layout.buildings:
		if absf((b.door as Rect2).get_center().x - (b.rect as Rect2).get_center().x) > 10.0:
			off_center += 1
	assert_gt(off_center, layout.buildings.size() / 2.0)


func test_exit_spawn_is_outside_buildings_and_door() -> void:
	for b in layout.buildings:
		assert_eq(layout.building_at(b.exit_spawn), -1, "exit_spawn dentro de prédio %d" % b.id)
		assert_false((b.door as Rect2).has_point(b.exit_spawn))
		assert_true(_world().has_point(b.exit_spawn))
		for tree in layout.trees:
			assert_gt(tree.distance_to(b.exit_spawn), 30.0, "árvore na saída do prédio %d" % b.id)


# --- determinismo ---

func test_same_seed_is_deterministic() -> void:
	var a := CityLayout.new(7)
	var b := CityLayout.new(7)
	assert_eq(a.buildings.size(), b.buildings.size())
	for i in a.buildings.size():
		assert_eq(a.buildings[i].rect, b.buildings[i].rect)
		assert_eq(a.buildings[i].color, b.buildings[i].color)
		assert_eq(a.buildings[i].door, b.buildings[i].door)
	assert_eq(a.trees, b.trees)


func test_different_seed_changes_the_city() -> void:
	var a := CityLayout.new(1)
	var b := CityLayout.new(2)
	# a cor vem de uma paleta pequena e pode coincidir; o formato do prédio não
	assert_ne(a.buildings[0].rect, b.buildings[0].rect)
	assert_ne(a.trees, b.trees)


# --- parques e árvores ---

func test_trees_stay_off_buildings_and_streets() -> void:
	for t in layout.trees:
		assert_eq(layout.building_at(t), -1)
		var in_a_lot := false
		for lot in layout.lots:
			if lot.grow(-20.0).has_point(t):
				in_a_lot = true
		assert_true(in_a_lot, "árvore fora de um lote")


# --- lojas ---

func test_shops_are_assigned() -> void:
	# as cotas das lojas saíram do SHOP_PLAN e agora vêm da tabela de tipos
	var counts := {}
	for b in layout.buildings:
		if b.shop != "":
			counts[b.shop] = counts.get(b.shop, 0) + 1
			assert_eq(b.shop, BuildingDefs.shop_of(b.type))
	assert_eq(counts.get("armory", 0), 2)
	assert_eq(counts.get("pharmacy", 0), 3)
	assert_eq(counts.get("agent_store", 0), 2)
	# mercado e posto passaram a vender (comida para levar) na Fase 3
	assert_true(counts.get("market", 0) >= BuildingDefs.min_count("market"))
	assert_true(counts.get("gas_station", 0) >= BuildingDefs.min_count("gas_station"))
	assert_eq(counts.size(), 5)


func test_building_colors_come_from_the_palette() -> void:
	for b in layout.buildings:
		assert_true(Palette.contains(b.color), "prédio %d" % b.id)


func test_parked_cars_avoid_the_avenues() -> void:
	for cell in CityLayout.PARKED_CELLS:
		assert_false(CityLayout.is_avenue(cell.x))
	assert_almost_eq(CityLayout.park_offset(1), CityLayout.PARK_OFFSET)
	assert_gt(CityLayout.park_offset(CityLayout.AVENUE_LINE), CityLayout.park_offset(1))


func test_shop_buildings_are_big_enough() -> void:
	for b in layout.buildings:
		if b.shop != "":
			assert_true((b.rect as Rect2).size.x >= 160.0 and (b.rect as Rect2).size.y >= 160.0)


# --- pontos fixos ---

func test_player_spawn_is_on_the_street() -> void:
	var p := CityLayout.spawn_point()
	assert_eq(layout.building_at(p), -1)
	assert_true(_world().has_point(p))


func test_building_at() -> void:
	var b: Dictionary = layout.buildings[10]
	assert_eq(layout.building_at(b.rect.get_center()), b.id)
	assert_eq(layout.building_at(Vector2(-10, -10)), -1)


func test_parked_cars_sit_at_the_curb_on_asphalt() -> void:
	for v in CityLayout.vehicle_spawns():
		var p: Vector2 = v.position
		assert_eq(layout.building_at(p), -1)
		var from_center := absf(fposmod(p.x + CityLayout.BLOCK / 2.0, CityLayout.BLOCK) - CityLayout.BLOCK / 2.0)
		assert_gt(from_center, 40.0, "estacionado rente ao meio-fio, não no meio da rua")
		assert_true(from_center + 13.0 <= CityLayout.ASPHALT / 2.0, "dentro do asfalto")
