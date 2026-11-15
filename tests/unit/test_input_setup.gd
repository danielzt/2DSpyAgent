extends "res://tests/base_test.gd"

const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

const DIRECTIONS := ["up", "down", "left", "right"]


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()


func test_actions_exist_for_both_players() -> void:
	for n in [1, 2]:
		for d in DIRECTIONS:
			assert_true(InputMap.has_action("p%d_%s" % [n, d]), "p%d_%s" % [n, d])


func test_each_action_has_key_button_and_axis() -> void:
	for d in DIRECTIONS:
		var events := InputMap.action_get_events("p1_" + d)
		assert_eq(events.size(), 3, d)
		var kinds := {}
		for e in events:
			kinds[e.get_class()] = true
		assert_true(kinds.has("InputEventKey"))
		assert_true(kinds.has("InputEventJoypadButton"))
		assert_true(kinds.has("InputEventJoypadMotion"))


func test_registration_is_idempotent() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s._ready()
	s.free()
	assert_eq(InputMap.action_get_events("p1_up").size(), 3)


func test_players_use_different_keys() -> void:
	var k1: InputEventKey = _first_key("p1_up")
	var k2: InputEventKey = _first_key("p2_up")
	assert_eq(k1.physical_keycode, KEY_W)
	assert_eq(k2.physical_keycode, KEY_UP)


func test_players_use_different_gamepads() -> void:
	assert_eq(_first_motion("p1_left").device, 0)
	assert_eq(_first_motion("p2_left").device, 1)


func test_axis_directions() -> void:
	assert_eq(_first_motion("p1_up").axis, JOY_AXIS_LEFT_Y)
	assert_true(_first_motion("p1_up").axis_value < 0.0)
	assert_true(_first_motion("p1_down").axis_value > 0.0)
	assert_eq(_first_motion("p1_right").axis, JOY_AXIS_LEFT_X)
	assert_true(_first_motion("p1_right").axis_value > 0.0)


func test_interact_actions_exist_with_key_and_button() -> void:
	for n in [1, 2]:
		var events := InputMap.action_get_events("p%d_interact" % n)
		assert_eq(events.size(), 2)
	assert_eq(_first_key("p1_interact").physical_keycode, KEY_E)
	assert_eq(_first_key("p2_interact").physical_keycode, KEY_ENTER)


func test_hand_actions() -> void:
	for n in [1, 2]:
		assert_eq(InputMap.action_get_events("p%d_use_left" % n).size(), 2 if n == 2 else 2)
		assert_true(InputMap.has_action("p%d_use_right" % n))
	assert_eq(_first_key("p2_use_left").physical_keycode, KEY_KP_0)
	assert_eq(_first_key("p2_use_right").physical_keycode, KEY_KP_1)


func test_player_one_uses_hands_with_mouse_buttons() -> void:
	var left_mouse := false
	var right_mouse := false
	for e in InputMap.action_get_events("p1_use_left"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			left_mouse = true
	for e in InputMap.action_get_events("p1_use_right"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse = true
	assert_true(left_mouse, "botão esquerdo -> mão esquerda")
	assert_true(right_mouse, "botão direito -> mão direita")
	assert_eq(_first_key("p1_use_left"), null, "jogador 1 não usa as mãos pelo teclado")
	assert_eq(InputMap.action_get_events("p1_use_left").size(), 2)  # mouse + gamepad X
	assert_eq(InputMap.action_get_events("p1_use_right").size(), 2)  # mouse + gamepad B


func test_mouse_buttons_map_to_the_right_actions() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_true(InputMap.event_is_action(left, "p1_use_left"))
	assert_false(InputMap.event_is_action(left, "p1_use_right"))
	assert_true(InputMap.event_is_action(right, "p1_use_right"))
	assert_false(InputMap.event_is_action(right, "p2_use_right"))


func test_inventory_and_character_keys() -> void:
	assert_eq(_first_key("p1_inventory").physical_keycode, KEY_I)
	assert_eq(_first_key("p1_character").physical_keycode, KEY_C)
	assert_eq(_first_key("p2_inventory").physical_keycode, KEY_KP_2)
	assert_eq(_first_key("p2_character").physical_keycode, KEY_KP_3)


func test_talk_actions() -> void:
	assert_eq(_first_key("p1_talk").physical_keycode, KEY_F)
	assert_eq(_first_key("p2_talk").physical_keycode, KEY_KP_PERIOD)
	assert_eq(InputSetupScript.key_label("p1_talk"), "F")
	assert_eq(InputMap.action_get_events("p1_talk").size(), 2)


func test_key_label_for_prompts() -> void:
	assert_eq(InputSetupScript.key_label("p1_interact"), "E")
	assert_eq(InputSetupScript.key_label("acao_inexistente"), "?")


func _first_key(action: String) -> InputEventKey:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e
	return null


func _first_motion(action: String) -> InputEventJoypadMotion:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			return e
	return null
