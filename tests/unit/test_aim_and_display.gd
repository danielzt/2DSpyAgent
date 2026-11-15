extends "res://tests/base_test.gd"
## Mira com o mouse, movimento independente da mira e ajuste da janela.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DisplaySetupScript := preload("res://scripts/autoload/display_setup.gd")
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
	for a in ["p1_right", "p1_up", "p1_use_left"]:
		Input.action_release(a)
	player.queue_free()
	for b in tree.get_nodes_in_group("bullets"):
		b.queue_free()
	await wait_frames(2)


func test_aim_at_world_point() -> void:
	player.aim_at(Vector2(500, 100))
	assert_eq(player.facing(), Vector2.UP)
	player.aim_at(Vector2(900, 500))
	assert_eq(player.facing(), Vector2.RIGHT)


func test_aim_at_own_position_keeps_direction() -> void:
	player.aim_at(Vector2(900, 500))
	player.aim_at(player.global_position)
	assert_eq(player.facing(), Vector2.RIGHT)


func test_mouse_motion_activates_mouse_aim_for_player_one() -> void:
	assert_false(player.mouse_active)
	player._input(InputEventMouseMotion.new())
	assert_true(player.mouse_active)


func test_player_two_ignores_mouse() -> void:
	player.player_index = 2
	player._input(InputEventMouseMotion.new())
	assert_false(player.mouse_active)


func test_mouse_aim_overrides_movement_direction() -> void:
	player.mouse_active = true
	player.mouse_world_provider = func(): return Vector2(500, 0)  # mouse acima
	Input.action_press("p1_right")
	await wait_physics_frames(10)
	assert_true(player.facing().y < -0.99, "mira no mouse, não no movimento")
	assert_gt(player.global_position.x, 510.0, "continua andando com WASD")


func test_mouse_aim_follows_cursor_as_player_moves() -> void:
	player.mouse_active = true
	player.mouse_world_provider = func(): return Vector2(2000, 500)
	await wait_physics_frames(2)
	assert_eq(player.facing(), Vector2.RIGHT)
	player.mouse_world_provider = func(): return Vector2(500, 2000)
	await wait_physics_frames(2)
	assert_eq(player.facing(), Vector2.DOWN)


func test_without_mouse_facing_follows_movement() -> void:
	Input.action_press("p1_up")
	await wait_physics_frames(3)
	assert_eq(player.facing(), Vector2.UP)


func test_left_click_fires_toward_mouse() -> void:
	player.mouse_active = true
	player.mouse_world_provider = func(): return Vector2(1500, 500)
	Input.action_press("p1_use_left")
	await wait_physics_frames(3)
	Input.action_release("p1_use_left")
	var shot = null
	for b in tree.get_nodes_in_group("bullets"):
		if b.shooter == player:
			shot = b
	assert_true(shot != null, "clique esquerdo deveria atirar")
	assert_eq(shot.direction, Vector2.RIGHT)


# --- janela ---

func test_fit_size_is_a_fraction_of_the_screen() -> void:
	assert_eq(DisplaySetupScript.fit_size(Vector2i(1920, 1080)), Vector2i(1632, 918))
	assert_eq(DisplaySetupScript.fit_size(Vector2i(2560, 1440), 0.5), Vector2i(1280, 720))


func test_fit_size_never_below_minimum() -> void:
	assert_eq(DisplaySetupScript.fit_size(Vector2i(500, 300)), DisplaySetupScript.MIN_SIZE)


func test_fit_size_keeps_screen_aspect() -> void:
	var s := DisplaySetupScript.fit_size(Vector2i(3440, 1440))
	assert_almost_eq(float(s.x) / s.y, 3440.0 / 1440.0, 0.01)


func test_fullscreen_toggle_modes() -> void:
	assert_eq(DisplaySetupScript.next_mode(Window.MODE_WINDOWED), Window.MODE_FULLSCREEN)
	assert_eq(DisplaySetupScript.next_mode(Window.MODE_MAXIMIZED), Window.MODE_FULLSCREEN)
	assert_eq(DisplaySetupScript.next_mode(Window.MODE_FULLSCREEN), Window.MODE_WINDOWED)
	assert_eq(DisplaySetupScript.next_mode(Window.MODE_EXCLUSIVE_FULLSCREEN), Window.MODE_WINDOWED)


func test_project_stretch_settings_adapt_to_any_aspect() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")
	assert_true(ProjectSettings.get_setting("display/window/size/resizable"))
