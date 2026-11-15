extends "res://tests/base_test.gd"
## Projéteis, arma do jogador, vida e morte.

const BulletScript := preload("res://scripts/combat/bullet.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var player
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	Score.reset()
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	tree.root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	Input.action_release("p1_use_left")
	player.queue_free()
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	for b in tree.get_nodes_in_group("bullets"):
		b.queue_free()
	await wait_frames(2)


func _npc(pos: Vector2, kind := "innocent", seed_value := 1) -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.kind = kind
	npc.ai_seed = seed_value
	npc.global_position = pos
	tree.root.add_child(npc)
	extras.append(npc)
	return npc


func _wall(center: Vector2, size: Vector2) -> Node:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = center
	tree.root.add_child(wall)
	extras.append(wall)
	return wall


func _is_dead(npc) -> bool:
	return not is_instance_valid(npc) or npc.dead


# --- projétil ---

func test_bullet_flies_in_its_direction() -> void:
	var b = BulletScript.fire(tree.root, Vector2(0, 2000), Vector2.RIGHT, null, "npcs")
	extras.append(b)
	await wait_physics_frames(10)
	assert_gt(b.position.x, 100.0)
	assert_almost_eq(b.position.y, 2000.0, 0.01)


func test_bullet_expires() -> void:
	var b = BulletScript.fire(tree.root, Vector2(0, 2000), Vector2.RIGHT, null, "npcs")
	await wait_physics_frames(60)
	await wait_frames(2)
	assert_false(is_instance_valid(b))


func test_bullet_damages_target_and_disappears() -> void:
	var npc := _npc(Vector2(700, 500))
	npc.set_physics_process(false)
	var b = BulletScript.fire(tree.root, Vector2(600, 500), Vector2.RIGHT, player, "npcs")
	await wait_physics_frames(15)
	await wait_frames(1)
	assert_eq(npc.health, 2)
	assert_false(is_instance_valid(b))


func test_bullet_stops_at_wall_and_spares_what_is_behind() -> void:
	var npc := _npc(Vector2(800, 500))
	npc.set_physics_process(false)
	_wall(Vector2(700, 500), Vector2(20, 200))
	BulletScript.fire(tree.root, Vector2(600, 500), Vector2.RIGHT, player, "npcs")
	await wait_physics_frames(30)
	assert_eq(npc.health, 3)


func test_bullet_ignores_its_shooter() -> void:
	BulletScript.fire(tree.root, player.global_position, Vector2.RIGHT, player, "players")
	await wait_physics_frames(10)
	assert_eq(player.health, player.MAX_HEALTH)


func test_enemy_bullet_hurts_player_not_npcs() -> void:
	var other := _npc(Vector2(650, 500))
	other.set_physics_process(false)
	BulletScript.fire(tree.root, Vector2(600, 500), Vector2.RIGHT, null, "players")
	await wait_physics_frames(20)
	assert_eq(other.health, 3, "tiro de criminal não fere NPCs")
	assert_eq(player.health, player.MAX_HEALTH, "ainda não chegou ao jogador")
	player.global_position = Vector2(760, 500)
	BulletScript.fire(tree.root, Vector2(700, 500), Vector2.RIGHT, null, "players")
	await wait_physics_frames(15)
	assert_eq(player.health, player.MAX_HEALTH - 1)


func test_player_bullet_passes_through_other_players() -> void:
	var other := PLAYER_SCENE.instantiate()
	other.player_index = 2
	other.global_position = Vector2(650, 500)
	tree.root.add_child(other)
	extras.append(other)
	var npc := _npc(Vector2(800, 500))
	npc.set_physics_process(false)
	BulletScript.fire(tree.root, Vector2(600, 500), Vector2.RIGHT, player, "npcs")
	await wait_physics_frames(25)
	assert_eq(other.health, other.MAX_HEALTH)
	assert_eq(npc.health, 2, "atravessa o aliado e acerta o NPC")


func test_enemy_bullet_hits_driver_through_the_car() -> void:
	var car := CAR_SCENE.instantiate()
	car.global_position = Vector2(700, 500)
	tree.root.add_child(car)
	extras.append(car)
	await wait_physics_frames(2)
	player.enter_vehicle(car)
	BulletScript.fire(tree.root, Vector2(600, 500), Vector2.RIGHT, null, "players")
	await wait_physics_frames(15)
	assert_eq(player.health, player.MAX_HEALTH - 1)


# --- arma do jogador ---

func test_fire_spawns_bullet_in_facing_direction() -> void:
	player.face(Vector2.RIGHT)
	var b = player.fire()
	assert_true(is_instance_valid(b))
	assert_eq(b.direction, Vector2.RIGHT)
	assert_eq(b.target_group, "npcs")
	assert_gt(b.position.x, player.global_position.x)
	assert_eq(b.shooter, player)


func test_fire_respects_cooldown() -> void:
	assert_true(is_instance_valid(player.fire()))
	assert_eq(player.fire(), null, "recarga")
	await wait_physics_frames(18)
	assert_true(is_instance_valid(player.fire()))


func test_cannot_fire_while_driving() -> void:
	var car := CAR_SCENE.instantiate()
	car.global_position = Vector2(500, 540)
	tree.root.add_child(car)
	extras.append(car)
	player.enter_vehicle(car)
	assert_eq(player.fire(), null)


func test_holding_fire_button_shoots_repeatedly() -> void:
	player.face(Vector2.UP)
	Input.action_press("p1_use_left")
	var seen := {}
	for i in 60:
		await tree.physics_frame
		for b in tree.get_nodes_in_group("bullets"):
			if b.shooter == player:
				seen[b.get_instance_id()] = true
	Input.action_release("p1_use_left")
	assert_true(seen.size() >= 3, "esperava ao menos 3 tiros, vieram %d" % seen.size())


func test_player_facing_follows_movement() -> void:
	Input.action_press("p1_left")
	await wait_physics_frames(3)
	Input.action_release("p1_left")
	assert_eq(player.facing(), Vector2.LEFT)


func test_shooting_kills_innocent_and_costs_points() -> void:
	var npc := _npc(Vector2(600, 500))
	npc.set_physics_process(false)
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_left")
	await wait_physics_frames(80)
	Input.action_release("p1_use_left")
	assert_true(_is_dead(npc))
	assert_eq(Score.points, -100)


func test_shooting_kills_criminal_and_gains_points() -> void:
	var npc := _npc(Vector2(600, 500), "criminal")
	npc.set_physics_process(false)
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_left")
	await wait_physics_frames(80)
	Input.action_release("p1_use_left")
	assert_true(_is_dead(npc))
	assert_eq(Score.points, 50)


# --- vida ---

func test_take_damage_reduces_health() -> void:
	player.take_damage(3)
	assert_eq(player.health, player.MAX_HEALTH - 3)


func test_death_respawns_with_full_health() -> void:
	var emitted := [false]
	player.died.connect(func(): emitted[0] = true)
	player.respawn_position = Vector2(123, 456)
	player.global_position = Vector2(900, 900)
	player.take_damage(player.MAX_HEALTH)
	assert_eq(player.health, player.MAX_HEALTH)
	assert_eq(player.global_position, Vector2(123, 456))
	assert_true(emitted[0])


func test_death_while_driving_leaves_the_car() -> void:
	var car := CAR_SCENE.instantiate()
	car.global_position = Vector2(500, 540)
	tree.root.add_child(car)
	extras.append(car)
	player.enter_vehicle(car)
	player.take_damage(player.MAX_HEALTH)
	assert_eq(player.vehicle, null)
	assert_eq(car.driver, null)
	assert_true(player.visible)


func test_hud_shows_health() -> void:
	await wait_frames(2)
	assert_eq(player.hud.health_text(), "Vida: 10/10")
	player.take_damage(4)
	await wait_frames(2)
	assert_eq(player.hud.health_text(), "Vida: 6/10")
