extends "res://tests/base_test.gd"

const WorldLayout := preload("res://scripts/world/world_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")

var layout


func before_each() -> void:
	layout = WorldLayout.new()


func test_world_is_much_bigger_than_before() -> void:
	var old_size := 3840.0
	assert_gt(WorldLayout.world_size().x, old_size * 3.0)
	assert_gt(WorldLayout.world_size().y, old_size)
	assert_true(WorldLayout.world_size().x >= 13000.0)


func test_has_two_regions() -> void:
	assert_eq(layout.regions.size(), 2)
	assert_eq(layout.regions[0].name, "Cidade")
	assert_eq(layout.regions[1].name, "Campo")


func test_regions_touch_but_do_not_overlap_and_fit_in_world() -> void:
	var world := Rect2(Vector2.ZERO, WorldLayout.world_size())
	var a: Rect2 = layout.regions[0].rect
	var b: Rect2 = layout.regions[1].rect
	assert_false(a.intersects(b))
	assert_almost_eq(a.end.x, b.position.x, 0.001)
	assert_true(world.encloses(a))
	assert_true(world.encloses(b))


func test_region_at() -> void:
	assert_eq(layout.region_at(WorldLayout.spawn_point()), "Cidade")
	assert_eq(layout.region_at(Vector2(CityLayout.city_size() + 500, 500)), "Campo")
	assert_eq(layout.region_at(Vector2(-5, -5)), "")
	assert_eq(layout.region_at(WorldLayout.world_size() + Vector2.ONE), "")


func test_building_ids_are_unique() -> void:
	var seen := {}
	for b in layout.buildings():
		assert_false(seen.has(b.id), "id repetido %d" % b.id)
		seen[b.id] = true


func test_buildings_do_not_overlap_across_regions() -> void:
	var all: Array = layout.buildings()
	for i in all.size():
		for j in range(i + 1, all.size()):
			assert_false(all[i].rect.intersects(all[j].rect))


func test_spawn_is_free_ground() -> void:
	assert_eq(layout.building_at(WorldLayout.spawn_point()), -1)


func test_vehicle_spawns_are_on_free_ground_inside_world() -> void:
	var world := Rect2(Vector2.ZERO, WorldLayout.world_size())
	var spawns: Array = layout.vehicle_spawns()
	assert_gt(spawns.size(), 5)
	for s in spawns:
		assert_true(world.has_point(s.position))
		# margem de 40 px ao redor do carro para não nascer encostado em prédio
		assert_eq(layout.building_at(s.position), -1)
		for off in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
			assert_eq(layout.building_at(s.position + off), -1)


func test_no_tree_next_to_vehicle_spawn() -> void:
	for s in layout.country.vehicle_spawns():
		for t in layout.country.trees:
			assert_gt(t.distance_to(s.position), 60.0)


# --- NPCs, trânsito, itens ---

func test_npc_counts() -> void:
	var walkers := 0
	var free_civilians := 0
	var criminals := 0
	for n in layout.npcs:
		if n.kind == "criminal":
			criminals += 1
		elif n.mode == "sidewalk":
			walkers += 1
		else:
			free_civilians += 1
	assert_eq(walkers, WorldLayout.CITY_PEDESTRIANS)
	assert_eq(free_civilians, WorldLayout.COUNTRY_CIVILIANS)
	assert_eq(criminals, WorldLayout.CITY_CRIMINALS + WorldLayout.COUNTRY_CRIMINALS)


func test_population_is_larger_than_before() -> void:
	assert_gt(layout.npcs.size(), 100.0)


func test_pedestrians_start_on_sidewalks() -> void:
	var half := WorldLayout.SidewalkGraph.half()
	for n in layout.npcs:
		if n.mode != "sidewalk":
			continue
		var p: Vector2 = n.position
		var a: Vector2 = WorldLayout.SidewalkGraph.position(n.from)
		var b: Vector2 = WorldLayout.SidewalkGraph.position(n.to)
		# fica no segmento entre os dois nós da calçada
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		assert_almost_eq(p.distance_to(closest), 0.0, 0.01)
		assert_true(WorldLayout.SidewalkGraph.is_valid(n.from) and WorldLayout.SidewalkGraph.is_valid(n.to))
		assert_gt(half, 0.0)


func test_npcs_spawn_on_free_ground_inside_world() -> void:
	var world := Rect2(Vector2.ZERO, WorldLayout.world_size())
	for n in layout.npcs:
		assert_true(world.has_point(n.position))
		assert_eq(layout.building_at(n.position), -1)


func test_npcs_do_not_spawn_near_player_start() -> void:
	for n in layout.npcs:
		assert_gt(n.position.distance_to(WorldLayout.spawn_point()), WorldLayout.NPC_MIN_START_DISTANCE - 1.0)
		if n.kind == "criminal":
			assert_gt(n.position.distance_to(WorldLayout.spawn_point()), WorldLayout.CRIMINAL_MIN_START_DISTANCE - 1.0)


func test_criminals_in_both_regions_with_regional_crimes() -> void:
	var in_city := 0
	var in_country := 0
	for n in layout.npcs:
		if n.kind != "criminal":
			continue
		var region: String = layout.region_at(n.position)
		assert_eq(WorldLayout.CrimeProfiles.region_of(n.crime), region, "crime de outra região")
		if region == "Cidade":
			in_city += 1
		else:
			in_country += 1
	assert_eq(in_city, WorldLayout.CITY_CRIMINALS)
	assert_eq(in_country, WorldLayout.COUNTRY_CRIMINALS)


func test_civilians_have_no_crime() -> void:
	for n in layout.npcs:
		if n.kind == "innocent":
			assert_eq(n.crime, "")


func test_npcs_are_deterministic() -> void:
	assert_eq(WorldLayout.new().npcs, layout.npcs)


func test_npcs_avoid_trees() -> void:
	for n in layout.npcs:
		for t in layout.country.trees:
			assert_gt(t.distance_to(n.position), 40.0)
		for t in layout.city.trees:
			assert_gt(t.distance_to(n.position), 30.0)


func test_traffic_spawns_are_on_roads_and_free() -> void:
	var spawns: Array = layout.traffic_spawns()
	assert_eq(spawns.size(), WorldLayout.TRAFFIC.size())
	for s in spawns:
		assert_true(WorldLayout.TrafficRoute.is_valid_node(s.node))
		assert_eq(layout.building_at(s.position), -1)
		for off in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
			assert_eq(layout.building_at(s.position + off), -1)
		for v in layout.vehicle_spawns():
			assert_gt((v.position as Vector2).distance_to(s.position), 60.0, "nasce em cima de carro estacionado")


func test_traffic_spawns_do_not_overlap_each_other() -> void:
	var spawns: Array = layout.traffic_spawns()
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			assert_gt((spawns[i].position as Vector2).distance_to(spawns[j].position), 80.0)


func test_pickups_are_placed_on_free_ground_in_both_regions() -> void:
	assert_eq(layout.pickups.size(), WorldLayout.PICKUP_PLAN.size())
	var world := Rect2(Vector2.ZERO, WorldLayout.world_size())
	var regions := {}
	for p in layout.pickups:
		assert_true(world.has_point(p.position))
		assert_eq(layout.building_at(p.position), -1)
		assert_gt(p.position.distance_to(WorldLayout.spawn_point()), 149.0)
		regions[layout.region_at(p.position)] = true
	assert_true(regions.has("Cidade") and regions.has("Campo"))


func test_pickups_use_known_items() -> void:
	for p in layout.pickups:
		assert_true(p.item == "cash" or WorldLayout.PickupItemDefs.exists(p.item), p.item)
		assert_true(p.amount >= 1)


func test_pickups_are_deterministic() -> void:
	assert_eq(WorldLayout.new().pickups, layout.pickups)


func test_free_point_near_finds_open_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var center := WorldLayout.spawn_point()
	var p: Vector2 = layout.free_point_near(center, 300.0, 600.0, rng, layout.region_rect("Cidade"))
	assert_ne(p, Vector2.INF)
	assert_true(p.distance_to(center) >= 299.0 and p.distance_to(center) <= 601.0)
	assert_false(layout.is_blocked(p, 30.0))
	assert_eq(layout.region_at(p), "Cidade")


func test_free_point_near_fails_outside_the_area() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_eq(layout.free_point_near(Vector2(-5000, -5000), 10.0, 20.0, rng, layout.region_rect("Cidade")), Vector2.INF)


func test_shops_exist_in_both_regions() -> void:
	var shops := 0
	var farm := 0
	for b in layout.buildings():
		if b.shop != "":
			shops += 1
			if b.id >= 1000:
				farm += 1
	assert_eq(shops, 8)
	assert_eq(farm, 1)
