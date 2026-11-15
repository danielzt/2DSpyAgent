extends "res://tests/base_test.gd"

const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")


func test_interior_is_much_bigger_than_building() -> void:
	# Proporção interna diferente da externa (como em Retro City).
	var building_size: float = CityLayout.BLOCK - CityLayout.ROAD
	assert_gt(InteriorLayout.SIZE.x, building_size * 4.0)


func test_generates_requested_furniture() -> void:
	for id in [0, 1, 5, 63]:
		var layout := InteriorLayout.new(id)
		assert_eq(layout.furniture.size(), InteriorLayout.FURNITURE_COUNT, "prédio %d" % id)


func test_furniture_inside_room() -> void:
	var room := Rect2(Vector2.ZERO, InteriorLayout.SIZE)
	for id in 10:
		for r in InteriorLayout.new(id).furniture:
			assert_true(room.encloses(r))


func test_furniture_does_not_block_exit_or_spawn() -> void:
	for id in 20:
		var layout := InteriorLayout.new(id)
		for r in layout.furniture:
			assert_false(r.intersects(InteriorLayout.CLEAR_ZONE), "prédio %d" % id)
			assert_false(r.has_point(InteriorLayout.spawn_point()))
			assert_false(r.intersects(InteriorLayout.exit_door()))


func test_furniture_does_not_overlap() -> void:
	var layout := InteriorLayout.new(3)
	for i in layout.furniture.size():
		for j in range(i + 1, layout.furniture.size()):
			assert_false(layout.furniture[i].intersects(layout.furniture[j]))


func test_deterministic_per_building() -> void:
	assert_eq(InteriorLayout.new(4).furniture, InteriorLayout.new(4).furniture)


func test_different_buildings_differ() -> void:
	assert_ne(InteriorLayout.new(1).furniture, InteriorLayout.new(2).furniture)


func test_exit_door_inside_room_and_spawn_outside_door() -> void:
	var room := Rect2(Vector2.ZERO, InteriorLayout.SIZE)
	assert_true(room.encloses(InteriorLayout.exit_door()))
	assert_false(InteriorLayout.exit_door().has_point(InteriorLayout.spawn_point()))
	assert_true(room.has_point(InteriorLayout.spawn_point()))
