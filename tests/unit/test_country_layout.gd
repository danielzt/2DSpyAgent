extends "res://tests/base_test.gd"

const CountryLayout := preload("res://scripts/world/country_layout.gd")

var layout


func before_each() -> void:
	layout = CountryLayout.new(Vector2(5760, 0))


func test_has_farms_fields_and_trees() -> void:
	assert_eq(layout.buildings.size(), CountryLayout.FARM_COUNT)
	assert_eq(layout.fields.size(), CountryLayout.FIELD_COUNT)
	assert_eq(layout.trees.size(), CountryLayout.TREE_COUNT)


func test_everything_inside_region() -> void:
	var region: Rect2 = layout.region_rect()
	for b in layout.buildings:
		assert_true(region.encloses(b.rect))
	for f in layout.fields:
		assert_true(region.encloses(f))
	for t in layout.trees:
		assert_true(region.has_point(t))


func test_farm_ids_are_distinct_from_city() -> void:
	for b in layout.buildings:
		assert_true(b.id >= CountryLayout.FARM_ID_BASE)


func test_farm_doors_face_road_and_exit_spawn_is_free() -> void:
	for b in layout.buildings:
		assert_almost_eq(b.door.position.y, b.rect.end.y, 0.001)
		assert_true(layout.road.has_point(b.exit_spawn), "exit_spawn deveria estar na estrada")
		for other in layout.buildings:
			assert_false((other.rect as Rect2).has_point(b.exit_spawn))


func test_trees_keep_clear_of_road_farms_and_fields() -> void:
	for t in layout.trees:
		assert_false(layout.road.has_point(t))
		for b in layout.buildings:
			assert_false((b.rect as Rect2).grow(CountryLayout.TREE_TRUNK).has_point(t))
		for f in layout.fields:
			assert_false(f.has_point(t))


func test_fields_do_not_overlap() -> void:
	for i in layout.fields.size():
		for j in range(i + 1, layout.fields.size()):
			assert_false(layout.fields[i].intersects(layout.fields[j]))


func test_deterministic_by_seed() -> void:
	var a := CountryLayout.new(Vector2(5760, 0), 9)
	var b := CountryLayout.new(Vector2(5760, 0), 9)
	assert_eq(a.trees, b.trees)
	assert_eq(a.fields, b.fields)
	assert_ne(CountryLayout.new(Vector2(5760, 0), 10).trees, a.trees)


func test_road_is_aligned_with_a_city_street() -> void:
	# A rua da cidade passa em múltiplos de BLOCK; a estrada de terra a continua.
	assert_almost_eq(fmod(CountryLayout.ROAD_Y, 560.0), 0.0, 0.001)
	assert_almost_eq(layout.road.position.x, 5760.0, 0.001)


func test_vehicle_spawns_are_on_road() -> void:
	for s in layout.vehicle_spawns():
		assert_true(layout.road.has_point(s.position))
