extends "res://tests/base_test.gd"
## Rota pelas ruas até o ponto marcado (Fase 6) e ruas estreitas nos bairros de casas.

const RoutePlanner := preload("res://scripts/world/route_planner.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	var profile: RefCounted = GameState.profile_for(1)
	profile.waypoints.clear()
	profile.active_waypoint = -1


func after_each() -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	GameState.set_outside()
	await wait_frames(2)


func _on_a_street(p: Vector2) -> bool:
	var snapped := RoutePlanner.snap(p)
	return (snapped.pos as Vector2).distance_to(p) < 1.0


# --- grade de ruas ---

func test_grid_nodes_and_neighbors() -> void:
	assert_true(RoutePlanner.is_node_valid(Vector2i(0, 0)))
	assert_true(RoutePlanner.is_node_valid(Vector2i(CityLayout.CELLS, CityLayout.CELLS)))
	assert_false(RoutePlanner.is_node_valid(Vector2i(-1, 3)))
	assert_false(RoutePlanner.is_node_valid(Vector2i(CityLayout.CELLS + 1, 2)), "o campo só tem a estrada")
	assert_true(RoutePlanner.is_node_valid(Vector2i(CityLayout.CELLS + 3, RoutePlanner.ROAD_LINE)))
	assert_eq(RoutePlanner.neighbors(Vector2i(5, 5)).size(), 4)
	assert_eq(RoutePlanner.neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(RoutePlanner.neighbors(Vector2i(CityLayout.CELLS + 3, RoutePlanner.ROAD_LINE)).size(), 2)


func test_node_path_is_the_shortest_on_the_grid() -> void:
	var path := RoutePlanner.node_path(Vector2i(1, 1), Vector2i(4, 3))
	assert_eq(path.size(), 6, "3 + 2 passos = 6 cruzamentos")
	assert_eq(path[0], Vector2i(1, 1))
	assert_eq(path[path.size() - 1], Vector2i(4, 3))
	assert_eq(RoutePlanner.node_path(Vector2i(2, 2), Vector2i(2, 2)), [Vector2i(2, 2)])
	var to_country := RoutePlanner.node_path(Vector2i(2, 2), Vector2i(CityLayout.CELLS + 4, RoutePlanner.ROAD_LINE))
	assert_gt(float(to_country.size()), 10.0)
	for node in to_country:
		assert_true(RoutePlanner.is_node_valid(node))


func test_snap_finds_the_closest_street() -> void:
	var snapped := RoutePlanner.snap(Vector2(1130, 600))
	assert_almost_eq((snapped.pos as Vector2).x, 1120.0, 0.01, "rua vertical da linha 2")
	assert_almost_eq((snapped.pos as Vector2).y, 600.0, 0.01)


# --- rota ---

func test_route_starts_and_ends_where_asked() -> void:
	var from := Vector2(700, 900)
	var to := Vector2(4100, 2300)
	var path := RoutePlanner.plan(from, to)
	assert_eq(path[0], from)
	assert_eq(path[path.size() - 1], to)
	assert_gt(float(path.size()), 3.0)


func test_route_runs_along_streets_between_the_ends() -> void:
	var path := RoutePlanner.plan(Vector2(700, 900), Vector2(4100, 2300))
	# o miolo é feito de trechos retos de rua: horizontais ou verticais, sobre linhas da grade
	for i in range(1, path.size() - 2):
		var a := path[i]
		var b := path[i + 1]
		assert_true(is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y), "trecho torto entre %s e %s" % [a, b])
		assert_true(_on_a_street(a) and _on_a_street(b))


func test_route_is_not_shorter_than_the_straight_line_and_not_absurdly_long() -> void:
	for pair in [[Vector2(500, 500), Vector2(6000, 6000)], [Vector2(3000, 3400), Vector2(9500, 3300)], [Vector2(6000, 100), Vector2(100, 6000)]]:
		var path := RoutePlanner.plan(pair[0], pair[1])
		var length := RoutePlanner.length_of(path)
		var direct: float = (pair[0] as Vector2).distance_to(pair[1])
		assert_true(length >= direct - 0.01)
		var manhattan: float = absf(pair[0].x - pair[1].x) + absf(pair[0].y - pair[1].y)
		assert_true(length <= manhattan + 2.0 * CityLayout.BLOCK, "rota longa demais")


func test_route_to_the_countryside_follows_the_country_road() -> void:
	var target := Vector2(9500, 3330)
	var path := RoutePlanner.plan(Vector2(1000, 1000), target)
	var last_street := path[path.size() - 2]
	assert_almost_eq(last_street.y, CityLayout.BLOCK * RoutePlanner.ROAD_LINE, 0.01, "chega pela estrada do campo")
	assert_true(last_street.x > CityLayout.city_size())


func test_route_on_the_same_street_segment_is_direct() -> void:
	var path := RoutePlanner.plan(Vector2(560, 700), Vector2(560, 1000))
	assert_eq(path[0], Vector2(560, 700))
	assert_eq(path[path.size() - 1], Vector2(560, 1000))
	assert_true(RoutePlanner.length_of(path) < 400.0)


func test_route_is_deterministic_and_has_no_repeated_points() -> void:
	var a := RoutePlanner.plan(Vector2(800, 2000), Vector2(5200, 4300))
	var b := RoutePlanner.plan(Vector2(800, 2000), Vector2(5200, 4300))
	assert_eq(a, b)
	for i in range(1, a.size()):
		assert_gt(a[i].distance_to(a[i - 1]), 0.4)


func test_dots_are_evenly_spaced_along_the_route() -> void:
	var path: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]
	var dots := RoutePlanner.dots(path, 25.0)
	assert_eq(dots.size(), 8)
	assert_eq(dots[0], Vector2(0, 0))
	assert_eq(dots[4], Vector2(100, 0))
	assert_eq(dots[5], Vector2(100, 25))
	assert_eq(RoutePlanner.dots([] as Array[Vector2], 10.0).size(), 0)


# --- HUD e jogador ---

func _player(pos := Vector2(1000, 1000)) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = pos
	tree.root.add_child(player)
	extras.append(player)
	await wait_physics_frames(2)
	return player


func test_hud_shows_a_dotted_trail_to_the_active_waypoint() -> void:
	var player = await _player(Vector2(1000, 1000))
	assert_eq(player.hud.route_dot_count(), 0)
	player.profile.add_waypoint(Vector2(4200, 3000), "Longe")
	await wait_frames(3)
	assert_gt(float(player.hud.route_dot_count()), 40.0)
	player.profile.remove_waypoint(0)
	await wait_frames(3)
	assert_eq(player.hud.route_dot_count(), 0)


func test_route_is_replanned_when_the_player_leaves_the_path() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(4200, 3000), "Longe")
	await wait_frames(3)
	var before: int = player.hud.route_dot_count()
	player.global_position = Vector2(4000, 2800)
	await wait_frames(3)
	assert_true(player.hud.route_dot_count() < before, "perto do destino a trilha é mais curta")


func test_route_is_not_shown_inside_buildings() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(4200, 3000), "Longe")
	GameState.set_inside(3, Vector2.ZERO)
	await wait_frames(3)
	assert_eq(player.hud.route_dot_count(), 0)


func test_hud_draws_the_trail_without_errors() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(1800, 1000), "Perto")
	await wait_frames(5)
	assert_true(player.hud.is_inside_tree())


# --- ruas estreitas ---

func test_narrow_streets_exist_and_are_narrower() -> void:
	var city := CityLayout.new(2024)
	assert_gt(float(CityLayout.narrow_lines.size()), 1.0)
	for line in CityLayout.narrow_lines:
		assert_eq(CityLayout.asphalt(line), CityLayout.NARROW_ASPHALT)
		assert_true(CityLayout.asphalt(line) < CityLayout.ASPHALT)
		assert_false(CityLayout.is_avenue(line))
		assert_eq(CityLayout.corridor(line), CityLayout.NARROW_ASPHALT + CityLayout.SIDEWALK * 2.0)
	assert_eq(city.world_seed, 2024)


func test_narrow_streets_are_the_ones_next_to_residential_blocks() -> void:
	var city := CityLayout.new(2024)
	for line in range(1, CityLayout.CELLS):
		var residential := 0
		var total := 0
		for other in CityLayout.CELLS:
			for side in [line - 1, line]:
				for cell in [Vector2i(side, other), Vector2i(other, side)]:
					total += 1
					if city.districts.district_of_cell(cell) == "residential":
						residential += 1
		var share := float(residential) / float(total)
		if CityLayout.is_avenue(line):
			continue
		assert_eq(CityLayout.narrow_lines.has(line), share >= CityLayout.NARROW_SHARE, "linha %d (%.2f)" % [line, share])


func test_narrow_streets_depend_on_the_seed_and_come_back_with_use_seed() -> void:
	CityLayout.new(2024)
	var base := CityLayout.narrow_lines.duplicate()
	CityLayout.new(99)
	assert_ne(CityLayout.narrow_lines.keys(), base.keys(), "outra seed, outras ruas estreitas")
	CityLayout.use_seed(2024)
	assert_eq(CityLayout.narrow_lines.keys(), base.keys())


func test_buildings_never_stand_on_narrow_streets_and_lots_are_larger_there() -> void:
	var city := CityLayout.new(2024)
	for line in CityLayout.narrow_lines:
		var axis: float = line * CityLayout.BLOCK
		var half := CityLayout.corridor(line) / 2.0
		for b in city.buildings:
			assert_false((b.rect as Rect2).intersects(Rect2(axis - half, 0, half * 2.0, CityLayout.city_size())), "prédio na rua %d" % line)
			assert_false((b.rect as Rect2).intersects(Rect2(0, axis - half, CityLayout.city_size(), half * 2.0)), "prédio na rua %d" % line)
	for line in CityLayout.narrow_lines:
		assert_gt(CityLayout.lot_rect(line, 8).size.x, CityLayout.LOT - 0.01)


func test_cars_fit_the_narrow_lanes() -> void:
	for line in CityLayout.narrow_lines:
		# a faixa do trânsito (26 px do eixo) mais a meia largura de um carro cabe no asfalto
		assert_true(26.0 + 22.0 <= CityLayout.asphalt(line) / 2.0, "faixa não cabe na rua %d" % line)
		assert_true(CityLayout.park_offset(line) > 0.0)
