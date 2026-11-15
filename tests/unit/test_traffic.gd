extends "res://tests/base_test.gd"
## Rotas e carros de trânsito (IA).

const TrafficRoute := preload("res://scripts/vehicle/traffic_route.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var cars: Array = []
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	Score.reset()


func after_each() -> void:
	for n in cars + extras:
		if is_instance_valid(n):
			n.queue_free()
	cars.clear()
	extras.clear()
	await wait_frames(1)


func _spawn_traffic_car(node: Vector2i, dir: Vector2i, seed_value := 3) -> Node:
	var car := CAR_SCENE.instantiate()
	car.ai_controlled = true
	car.ai_seed = seed_value
	car.position = TrafficRoute.lane_point(node, dir) - Vector2(dir) * 120.0
	car.rotation = Vector2(dir).angle()
	car.start_route(node, dir)
	tree.root.add_child(car)
	cars.append(car)
	return car


# --- rotas (puras) ---

func test_valid_nodes_are_inside_the_grid() -> void:
	assert_true(TrafficRoute.is_valid_node(Vector2i(1, 1)))
	assert_true(TrafficRoute.is_valid_node(Vector2i(CityLayout.CELLS - 1, CityLayout.CELLS - 1)))
	assert_false(TrafficRoute.is_valid_node(Vector2i(0, 5)))
	assert_false(TrafficRoute.is_valid_node(Vector2i(CityLayout.CELLS, 5)))


func test_lane_is_on_the_right_hand_side() -> void:
	var node := Vector2i(3, 3)
	var center := TrafficRoute.node_position(node)
	assert_eq(TrafficRoute.lane_point(node, Vector2i(1, 0)), center + Vector2(0, TrafficRoute.LANE_OFFSET))   # leste: sul
	assert_eq(TrafficRoute.lane_point(node, Vector2i(-1, 0)), center + Vector2(0, -TrafficRoute.LANE_OFFSET))  # oeste: norte
	assert_eq(TrafficRoute.lane_point(node, Vector2i(0, 1)), center + Vector2(-TrafficRoute.LANE_OFFSET, 0))   # sul: oeste
	assert_eq(TrafficRoute.lane_point(node, Vector2i(0, -1)), center + Vector2(TrafficRoute.LANE_OFFSET, 0))   # norte: leste


func test_lane_stays_on_the_road() -> void:
	var half_asphalt := CityLayout.ASPHALT / 2.0
	assert_true(TrafficRoute.LANE_OFFSET + 13.0 < half_asphalt, "carro precisa caber no asfalto")


func test_choices_never_reverse_and_stay_in_grid() -> void:
	var options := TrafficRoute.choices(Vector2i(5, 5), Vector2i(1, 0))
	assert_eq(options.size(), 3)
	assert_false(options.has(Vector2i(-1, 0)))
	var corner := TrafficRoute.choices(Vector2i(1, 1), Vector2i(-1, 0))
	assert_eq(corner, [Vector2i(0, 1)])


func test_random_walk_stays_inside_grid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var node := Vector2i(6, 6)
	var dir := Vector2i(1, 0)
	for i in 1000:
		dir = TrafficRoute.next_dir(node, dir, rng)
		node += dir
		assert_true(TrafficRoute.is_valid_node(node), "saiu da grade em %s" % str(node))


func test_prefers_going_straight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var straight := 0
	for i in 300:
		if TrafficRoute.next_dir(Vector2i(6, 6), Vector2i(1, 0), rng) == Vector2i(1, 0):
			straight += 1
	assert_gt(straight, 150.0, "deveria seguir reto na maioria das vezes")


# --- carro de trânsito na cena ---

func test_traffic_car_drives_by_itself() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	var start: Vector2 = car.global_position
	await wait_physics_frames(120)
	assert_gt(car.global_position.distance_to(start), 150.0)
	assert_true(car.speed > 50.0)


func test_traffic_car_keeps_going_over_time() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	await wait_physics_frames(300)
	var mid: Vector2 = car.global_position
	await wait_physics_frames(300)
	assert_gt(car.global_position.distance_to(mid), 200.0, "carro parou")


func test_traffic_car_follows_its_lane() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	await wait_physics_frames(90)
	var lane_y: float = TrafficRoute.node_position(Vector2i(3, 3)).y + TrafficRoute.LANE_OFFSET
	assert_true(absf(car.global_position.y - lane_y) < 20.0, "saiu da faixa: y=%f" % car.global_position.y)


func test_lane_target_is_ahead_on_the_lane_line() -> void:
	var node := Vector2i(3, 3)
	var dir := Vector2i(1, 0)
	var lane_y: float = TrafficRoute.node_position(node).y + TrafficRoute.LANE_OFFSET
	# Carro no meio da rua (y = linha central), 300 px antes do cruzamento.
	var pos := TrafficRoute.node_position(node) + Vector2(-300, 0)
	var target := TrafficRoute.lane_target(pos, node, dir, 100.0)
	assert_almost_eq(target.y, lane_y, 0.001)
	assert_almost_eq(target.x, pos.x + 100.0, 0.001)


func test_reached_node_margin() -> void:
	var node := Vector2i(3, 3)
	var dir := Vector2i(1, 0)
	var lane := TrafficRoute.lane_point(node, dir)
	assert_false(TrafficRoute.reached_node(lane + Vector2(-200, 0), node, dir, 45.0))
	assert_true(TrafficRoute.reached_node(lane + Vector2(-30, 0), node, dir, 45.0))
	assert_true(TrafficRoute.reached_node(lane + Vector2(20, 0), node, dir, 45.0))


func test_traffic_never_drives_in_the_middle_of_the_road() -> void:
	# Em retas (rumo alinhado a um eixo), o carro deve estar na faixa da direita:
	# a ~28 px da linha central da rua, nunca sobre ela.
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0), 3)
	var good := 0
	var samples := 0
	for i in 2400:
		await tree.physics_frame
		if i % 6 != 0 or car.speed < 60.0:
			continue
		var heading := Vector2.RIGHT.rotated(car.rotation)
		var horizontal := absf(heading.x) > 0.99
		var vertical := absf(heading.y) > 0.99
		if not (horizontal or vertical):
			continue  # fazendo curva
		var p: Vector2 = car.global_position
		var offset := absf(p.y - roundf(p.y / CityLayout.BLOCK) * CityLayout.BLOCK) if horizontal else absf(p.x - roundf(p.x / CityLayout.BLOCK) * CityLayout.BLOCK)
		samples += 1
		if offset > 12.0 and offset < 46.0:
			good += 1
	assert_gt(samples, 30.0, "poucas amostras em linha reta")
	assert_gt(float(good) / samples, 0.9, "carro andando fora da faixa: %d de %d bons" % [good, samples])


func test_traffic_drives_on_the_right_side_in_all_directions() -> void:
	# Direção -> lado esperado em relação à linha central (coordenadas de tela).
	var cases := [
		[Vector2i(1, 0), Vector2(0, 1)],   # leste: sul
		[Vector2i(-1, 0), Vector2(0, -1)], # oeste: norte
		[Vector2i(0, 1), Vector2(-1, 0)],  # sul: oeste
		[Vector2i(0, -1), Vector2(1, 0)],  # norte: leste
	]
	for c in cases:
		var node := Vector2i(6, 6)
		var lane := TrafficRoute.lane_point(node, c[0]) - TrafficRoute.node_position(node)
		assert_eq(lane.normalized(), c[1])


func test_traffic_car_cannot_be_stolen() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	var player := PLAYER_SCENE.instantiate()
	player.global_position = car.global_position + Vector2(0, 80)
	tree.root.add_child(player)
	extras.append(player)
	await wait_physics_frames(2)
	assert_false(player.enter_vehicle(car))
	assert_eq(car.driver, null)
	assert_false(car.get_node("InteractZone").monitoring)
	assert_true(car.is_in_group("traffic"))


func test_traffic_car_brakes_for_pedestrian_instead_of_running_over() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	var npc := NPC_SCENE.instantiate()
	npc.global_position = car.global_position + Vector2(260, 0)
	tree.root.add_child(npc)
	npc.set_physics_process(false)  # fica parado na pista
	extras.append(npc)
	await wait_physics_frames(240)
	assert_eq(npc.health, 3, "foi atropelado")
	assert_false(npc.dead)
	assert_true(car.global_position.x < npc.global_position.x - 20.0)


func test_stuck_traffic_car_recovers_by_reversing() -> void:
	var car := _spawn_traffic_car(Vector2i(3, 3), Vector2i(1, 0))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 400)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = car.global_position + Vector2(150, 0)
	tree.root.add_child(wall)
	extras.append(wall)
	await wait_physics_frames(400)
	# Não fica encostado na parede: bate, volta e tenta de novo (a posição varia).
	assert_true(car.global_position.x < wall.global_position.x - 10.0)
	assert_true(is_instance_valid(car))
