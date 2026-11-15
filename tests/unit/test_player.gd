extends "res://tests/base_test.gd"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var player


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	tree.root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	for n in [1, 2]:
		for d in ["up", "down", "left", "right"]:
			Input.action_release("p%d_%s" % [n, d])
	player.queue_free()
	await wait_frames(1)


func test_belongs_to_players_group() -> void:
	assert_true(player.is_in_group("players"))


func test_stays_still_without_input() -> void:
	var start: Vector2 = player.global_position
	await wait_physics_frames(10)
	assert_eq(player.global_position, start)


func test_moves_right() -> void:
	var start_x: float = player.global_position.x
	Input.action_press("p1_right")
	await wait_physics_frames(10)
	assert_gt(player.global_position.x, start_x + 10.0)
	assert_almost_eq(player.global_position.y, 500.0, 0.01)


func test_moves_up_and_left() -> void:
	Input.action_press("p1_up")
	Input.action_press("p1_left")
	await wait_physics_frames(10)
	assert_true(player.global_position.x < 500.0)
	assert_true(player.global_position.y < 500.0)


func test_diagonal_speed_is_normalized() -> void:
	Input.action_press("p1_down")
	Input.action_press("p1_right")
	await wait_physics_frames(3)
	assert_almost_eq(player.velocity.length(), player.speed, 0.5)


func test_ignores_other_players_input() -> void:
	var start: Vector2 = player.global_position
	Input.action_press("p2_right")
	await wait_physics_frames(10)
	assert_eq(player.global_position, start)


func test_player_two_uses_its_own_actions() -> void:
	player.player_index = 2
	var start_x: float = player.global_position.x
	Input.action_press("p2_right")
	await wait_physics_frames(10)
	assert_gt(player.global_position.x, start_x + 10.0)


func test_blocked_by_solid_body() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 200)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = Vector2(540, 500)
	tree.root.add_child(wall)
	await wait_physics_frames(1)
	Input.action_press("p1_right")
	await wait_physics_frames(60)
	assert_true(player.global_position.x < 540.0 - 10.0 + 1.0, "atravessou a parede")
	wall.queue_free()


func test_camera_limits() -> void:
	player.set_camera_limits(Rect2(10, 20, 300, 400))
	var cam: Camera2D = player.get_node("Camera2D")
	assert_eq(cam.limit_left, 10)
	assert_eq(cam.limit_top, 20)
	assert_eq(cam.limit_right, 310)
	assert_eq(cam.limit_bottom, 420)
