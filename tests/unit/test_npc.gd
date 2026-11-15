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
