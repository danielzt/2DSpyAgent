extends "res://tests/base_test.gd"
## NPCs: inocentes, criminosos, pontuação e atropelamento.

const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	Score.reset()


func after_each() -> void:
	Input.action_release("p1_up")
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	for b in tree.get_nodes_in_group("bullets"):
		b.queue_free()
	await wait_frames(2)


func _add(node: Node, pos: Vector2) -> Node:
	node.global_position = pos
	tree.root.add_child(node)
	extras.append(node)
	return node


func _npc(pos: Vector2, kind := "innocent", seed_value := 1) -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.kind = kind
	npc.ai_seed = seed_value
	return _add(npc, pos)


func _player(pos: Vector2) -> Node:
	return _add(PLAYER_SCENE.instantiate(), pos)


func _is_dead(npc) -> bool:
	return not is_instance_valid(npc) or npc.dead


func test_starts_with_full_health_in_npc_group() -> void:
	var npc := _npc(Vector2(0, 0))
	assert_eq(npc.health, 3)
	assert_true(npc.is_in_group("npcs"))
	assert_false(npc.dead)


func test_dies_after_three_hits() -> void:
	var npc := _npc(Vector2(0, 0))
	npc.take_damage(1)
	npc.take_damage(1)
	assert_false(npc.dead)
	npc.take_damage(1)
	assert_true(npc.dead)


func test_killing_innocent_as_player_costs_points() -> void:
	var p := _player(Vector2(300, 0))
	var npc := _npc(Vector2(0, 0))
	npc.take_damage(3, p)
	assert_eq(Score.points, -100)


func test_killing_criminal_as_player_gives_points() -> void:
	var p := _player(Vector2(300, 0))
	var npc := _npc(Vector2(0, 0), "criminal")
	npc.take_damage(3, p)
	assert_eq(Score.points, 50)


func test_kill_without_player_does_not_change_score() -> void:
	var npc := _npc(Vector2(0, 0))
	npc.take_damage(3, null)
	assert_eq(Score.points, 0)
	var other := _npc(Vector2(100, 0))
	other.take_damage(3, _npc(Vector2(200, 0), "criminal"))
	assert_eq(Score.points, 0)


func test_dying_twice_scores_once() -> void:
	var p := _player(Vector2(300, 0))
	var npc := _npc(Vector2(0, 0))
	npc.take_damage(3, p)
	npc.take_damage(3, p)
	assert_eq(Score.points, -100)


func test_died_signal_carries_kind() -> void:
	var got := [""]
	var npc := _npc(Vector2(0, 0), "criminal")
	npc.died.connect(func(k): got[0] = k)
	npc.take_damage(5)
	assert_eq(got[0], "criminal")


func test_dead_npc_is_removed() -> void:
	var npc := _npc(Vector2(0, 0))
	npc.take_damage(3)
	await wait_frames(2)
	assert_false(is_instance_valid(npc))


func test_innocent_flees_from_attacker() -> void:
	var p := _player(Vector2(-60, 0))
	var npc := _npc(Vector2(0, 0))
	await wait_physics_frames(1)
	npc.take_damage(1, p)
	var start_x: float = npc.global_position.x
	await wait_physics_frames(20)
	assert_gt(npc.global_position.x, start_x + 20.0)


func test_innocent_wanders() -> void:
	var npc := _npc(Vector2(0, 0), "innocent", 11)
	var start: Vector2 = npc.global_position
	await wait_physics_frames(300)
	assert_gt(npc.global_position.distance_to(start), 20.0)


func test_innocent_never_shoots() -> void:
	var p := _player(Vector2(100, 0))
	var npc := _npc(Vector2(0, 0))
	await wait_physics_frames(200)
	assert_eq(tree.get_nodes_in_group("bullets").size(), 0)
	assert_eq(p.health, p.MAX_HEALTH)


func test_criminal_shoots_player_in_range() -> void:
	var p := _player(Vector2(150, 0))
	var npc := _npc(Vector2(0, 0), "criminal", 5)
	await wait_physics_frames(240)
	assert_true(p.health < p.MAX_HEALTH, "criminal deveria acertar o jogador")


func test_criminal_ignores_distant_player() -> void:
	var p := _player(Vector2(2000, 0))
	var npc := _npc(Vector2(0, 0), "criminal", 5)
	await wait_physics_frames(150)
	var shot := 0
	for b in tree.get_nodes_in_group("bullets"):
		if b.shooter == npc:
			shot += 1
	assert_eq(shot, 0)


func test_criminal_closes_distance_to_player() -> void:
	var p := _player(Vector2(400, 0))
	var npc := _npc(Vector2(0, 0), "criminal", 5)
	await wait_physics_frames(90)
	assert_gt(npc.global_position.x, 40.0)


func test_running_over_with_car_kills_and_scores() -> void:
	var p := _player(Vector2(500, 900))
	var car := CAR_SCENE.instantiate()
	_add(car, Vector2(500, 500))
	var npc := _npc(Vector2(650, 500))
	npc.set_physics_process(false)
	await wait_physics_frames(2)
	p.enter_vehicle(car)
	car.speed = 300.0
	Input.action_press("p1_up")
	await wait_physics_frames(60)
	assert_true(_is_dead(npc), "deveria ter sido atropelado")
	assert_eq(Score.points, -100)


func test_slow_car_does_not_kill() -> void:
	var p := _player(Vector2(500, 900))
	var car := CAR_SCENE.instantiate()
	_add(car, Vector2(500, 500))
	var npc := _npc(Vector2(540, 500))
	npc.set_physics_process(false)
	await wait_physics_frames(2)
	p.enter_vehicle(car)
	car.speed = 40.0
	await wait_physics_frames(20)
	assert_false(_is_dead(npc))


# --- atividades nos interiores (Fase 7) ---

func _worker(pos: Vector2, activity: String, route := PackedVector2Array(), facing := "down") -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 7
	npc.activity = activity
	npc.route = route
	npc.facing = facing
	npc.stationary = true
	return _add(npc, pos)


func _shape_disabled(npc: Node) -> bool:
	return (npc.get_node("CollisionShape2D") as CollisionShape2D).disabled


func test_sitting_npc_has_no_collision_and_sits() -> void:
	var npc := _worker(Vector2(100, 100), "sit", PackedVector2Array(), "right")
	await wait_physics_frames(30)
	assert_eq(npc.pose(), "sit")
	assert_true(_shape_disabled(npc))
	assert_eq(npc.global_position, Vector2(100, 100))
	assert_eq(npc.sprite_direction(), "right")


func test_lying_npc_lies_down() -> void:
	var npc := _worker(Vector2(100, 100), "lie", PackedVector2Array(), "left")
	await wait_physics_frames(5)
	assert_eq(npc.pose(), "lie")
	assert_eq(npc.sprite_direction(), "down")
	assert_true(_shape_disabled(npc))


func test_working_npc_stays_and_animates() -> void:
	var npc := _worker(Vector2(100, 100), "work")
	await wait_physics_frames(60)
	assert_eq(npc.pose(), "work")
	assert_eq(npc.global_position, Vector2(100, 100))
	assert_false(_shape_disabled(npc))


func test_patrol_walks_only_between_route_points() -> void:
	var route := PackedVector2Array([Vector2(0, 0), Vector2(160, 0), Vector2(160, 160)])
	var npc := _worker(route[0], "patrol", route)
	var bounds := Rect2(Vector2(0, 0), Vector2(160, 160)).grow(16.0)
	var closest := [INF, INF, INF]
	for i in 1200:   # 20 s: ida, pausas de até 4 s e volta
		await wait_physics_frames(1)
		assert_true(bounds.has_point(npc.global_position), "saiu da rota: %s" % str(npc.global_position))
		for p in 3:
			closest[p] = minf(closest[p], npc.global_position.distance_to(route[p]))
	for p in 3:
		assert_true(closest[p] < npc.ARRIVE_DISTANCE + 1.0, "não passou pelo ponto %d (%.1f)" % [p, closest[p]])


func test_patrol_waits_when_blocked_and_moves_on() -> void:
	var route := PackedVector2Array([Vector2(0, 0), Vector2(160, 0), Vector2(160, 160)])
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 80)
	shape.shape = rect
	wall.add_child(shape)
	_add(wall, Vector2(80, 0))
	var npc := _worker(route[0], "patrol", route)
	var reached := false
	for i in 1200:   # 20 s: ida, pausas de até 4 s e volta
		await wait_physics_frames(1)
		if npc.global_position.distance_to(route[2]) < npc.ARRIVE_DISTANCE + 1.0:
			reached = true
			break
	assert_true(reached, "ficou preso tentando passar: %s" % str(npc.global_position))
	assert_eq(wall.global_position, Vector2(80, 0))


func test_attacked_sitting_npc_stands_up_and_flees() -> void:
	var npc := _worker(Vector2(200, 200), "sit")
	var attacker := Node2D.new()
	_add(attacker, Vector2(150, 200))
	await wait_physics_frames(3)
	npc.take_damage(1, attacker)
	await wait_physics_frames(30)
	assert_eq(npc.activity, "")
	assert_false(_shape_disabled(npc))
	assert_eq(npc.pose(), "stand")
	assert_gt(npc.global_position.distance_to(attacker.global_position), 60.0)


func test_post_npc_stays_put() -> void:
	var npc := _worker(Vector2(300, 300), "post", PackedVector2Array(), "up")
	await wait_physics_frames(300)
	assert_eq(npc.global_position, Vector2(300, 300))
	assert_eq(npc.pose(), "stand")
