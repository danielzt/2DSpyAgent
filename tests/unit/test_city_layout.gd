extends "res://tests/base_test.gd"

const CityLayout := preload("res://scripts/world/city_layout.gd")

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
	for lot in layout.lots:
		assert_true(_world().encloses(lot))
		assert_almost_eq(lot.size.x, CityLayout.LOT)


func test_lots_leave_room_for_streets() -> void:
	# lotes vizinhos ficam separados pelo corredor inteiro (asfalto + calçadas)
	assert_almost_eq(layout.lots[CityLayout.CELLS].position.x - layout.lots[0].end.x, CityLayout.ROAD)


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
	assert_ne(a.buildings[0].color, b.buildings[0].color)
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
	var counts := {}
	for b in layout.buildings:
		if b.shop != "":
			counts[b.shop] = counts.get(b.shop, 0) + 1
	for plan in CityLayout.SHOP_PLAN:
		assert_eq(counts.get(plan[0], 0), plan[1], plan[0])


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
