extends "res://tests/base_test.gd"
## Bairros: divisão da grade, contiguidade, cotas, determinismo e efeito nos prédios.

const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")

const SEEDS := [2024, 1, 2, 3, 7, 42, 99, 1986, 12345, 777777]


func test_grid_matches_the_city() -> void:
	assert_eq(DistrictLayout.CELLS, CityLayout.CELLS)
	assert_almost_eq(DistrictLayout.BLOCK, CityLayout.BLOCK)


func test_there_are_six_districts_with_complete_data() -> void:
	assert_eq(DistrictLayout.IDS.size(), 6)
	var share := 0.0
	for id in DistrictLayout.IDS:
		var p: Dictionary = DistrictLayout.params(id)
		assert_ne(p.label, "")
		assert_gt((p.names as Array).size(), 0.0)
		assert_eq((p.shapes as Array).size(), 3)
		assert_true(p.floors[0] >= 1 and p.floors[1] >= p.floors[0])
		assert_true(p.park >= 0.0 and p.park < 0.5)
		for wall in p.walls:
			assert_true(TileFactory.has_tile(wall), wall)
		for roof in p.roofs:
			assert_true(TileFactory.has_tile(roof), roof)
		share += p.share
	assert_almost_eq(share, 1.0, 0.001)
	assert_eq(DistrictLayout.params("lua"), {})


func test_targets_add_up_to_the_whole_grid() -> void:
	var total := 0
	var targets := DistrictLayout.targets()
	for id in DistrictLayout.IDS:
		assert_true(targets[id] >= DistrictLayout.MIN_CELLS, id)
		total += targets[id]
	assert_eq(total, DistrictLayout.CELLS * DistrictLayout.CELLS)
	assert_gt(targets["residential"], targets["civic"])


func test_every_block_has_a_district() -> void:
	for s in SEEDS:
		var d := DistrictLayout.new(s)
		assert_eq(d.cells.size(), DistrictLayout.CELLS * DistrictLayout.CELLS, "seed %d" % s)
		for cx in DistrictLayout.CELLS:
			for cy in DistrictLayout.CELLS:
				assert_true(DistrictLayout.IDS.has(d.district_of_cell(Vector2i(cx, cy))))


func test_every_district_exists_is_big_enough_and_contiguous() -> void:
	for s in SEEDS:
		var d := DistrictLayout.new(s)
		for id in DistrictLayout.IDS:
			assert_true(d.count(id) >= DistrictLayout.MIN_CELLS, "seed %d: %s com %d quadras" % [s, id, d.count(id)])
			assert_true(d.is_contiguous(id), "seed %d: %s partido" % [s, id])


func test_sizes_stay_close_to_the_targets() -> void:
	var targets := DistrictLayout.targets()
	for s in SEEDS:
		var d := DistrictLayout.new(s)
		for id in DistrictLayout.IDS:
			assert_true(absi(d.count(id) - targets[id]) <= 10, "seed %d: %s com %d (alvo %d)" % [s, id, d.count(id), targets[id]])


func test_center_holds_the_four_middle_blocks() -> void:
	var mid := DistrictLayout.CELLS / 2
	for s in SEEDS:
		var d := DistrictLayout.new(s)
		for cell in [Vector2i(mid - 1, mid - 1), Vector2i(mid, mid - 1), Vector2i(mid - 1, mid), Vector2i(mid, mid)]:
			assert_eq(d.district_of_cell(cell), "center", "seed %d" % s)


func test_same_seed_gives_the_same_districts_and_names() -> void:
	var a := DistrictLayout.new(11)
	var b := DistrictLayout.new(11)
	assert_eq(a.cells, b.cells)
	assert_eq(a.names, b.names)


func test_different_seeds_change_the_map() -> void:
	var different := 0
	var base := DistrictLayout.new(1)
	for s in [2, 3, 4, 5]:
		if DistrictLayout.new(s).cells != base.cells:
			different += 1
	assert_gt(different, 2.0)


func test_district_at_point() -> void:
	var d := DistrictLayout.new()
	var center := Vector2.ONE * DistrictLayout.CELLS * DistrictLayout.BLOCK / 2.0
	assert_eq(d.district_at(center + Vector2(100, 100)), "center")
	assert_eq(d.district_at(Vector2(-5, 100)), "", "fora da cidade")
	assert_eq(d.district_at(Vector2(DistrictLayout.CELLS * DistrictLayout.BLOCK + 1.0, 100)), "")
	assert_eq(DistrictLayout.cell_of(Vector2(600, 1200)), Vector2i(1, 2))
	assert_eq(d.district_at(Vector2(600, 1200)), d.district_of_cell(Vector2i(1, 2)))


func test_district_names() -> void:
	var d := DistrictLayout.new()
	var seen := {}
	for id in DistrictLayout.IDS:
		var district_name: String = d.name_of(id)
		assert_true((DistrictLayout.params(id).names as Array).has(district_name))
		seen[district_name] = true
	assert_eq(seen.size(), 6, "nomes de bairro repetidos")
	assert_eq(d.name_of("lua"), "")
	assert_eq(d.name_at(Vector2(-10, -10)), "")
	assert_ne(d.name_at(Vector2(3000, 3000)), "")


# --- efeito na cidade ---

func test_every_building_carries_the_district_of_its_block() -> void:
	var city := CityLayout.new()
	for b in city.buildings:
		assert_eq(b.district, city.districts.district_at((b.rect as Rect2).get_center()), "prédio %d" % b.id)


func test_floors_follow_the_district_range() -> void:
	var city := CityLayout.new()
	for b in city.buildings:
		var floors: Array = DistrictLayout.params(b.district).floors
		assert_true(b.floors >= 1 and b.floors <= floors[1], "prédio %d (%s) com %d andares" % [b.id, b.district, b.floors])


func test_walls_follow_the_district_unless_the_type_has_its_own() -> void:
	var city := CityLayout.new()
	for b in city.buildings:
		var def: Dictionary = BuildingDefs.def(b.type)
		if def.has("wall"):
			assert_eq(b.wall, def.wall)
		else:
			assert_true((DistrictLayout.params(b.district).walls as Array).has(b.wall), "prédio %d" % b.id)


func test_districts_look_different() -> void:
	var city := CityLayout.new()
	var floors := {}
	var count := {}
	for b in city.buildings:
		floors[b.district] = floors.get(b.district, 0) + b.floors
		count[b.district] = count.get(b.district, 0) + 1
	for id in DistrictLayout.IDS:
		assert_gt(count.get(id, 0), 5.0, "bairro %s sem prédios" % id)
	var center: float = float(floors["center"]) / count["center"]
	var residential: float = float(floors["residential"]) / count["residential"]
	assert_gt(center, residential + 1.0, "o centro é mais alto que o bairro residencial")


func test_industrial_district_has_no_parks() -> void:
	var city := CityLayout.new()
	for park in city.parks:
		assert_ne(city.districts.district_at(park.get_center()), "industrial")
