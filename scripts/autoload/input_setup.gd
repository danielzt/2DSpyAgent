extends Node
## Registra em runtime as ações de input de cada jogador (p1_*, p2_*).
## Jogador 1: WASD anda, mouse mira, botão esquerdo/direito usam a mão esquerda/direita,
##   E interage, F conversa, I inventário, C ficha. Gamepad 0.
## Jogador 2: setas, Enter interage, Num. conversa, Num0/Num1 mãos, Num2 inventário, Num3 ficha. Gamepad 1.
## Ações: p{N}_up, _down, _left, _right, _interact, _talk, _use_left, _use_right, _inventory, _character.

const DEADZONE := 0.2

const PLAYER_KEYS := {
	1: {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_E, "talk": KEY_F,
		"use_left": KEY_NONE, "use_right": KEY_NONE, "inventory": KEY_I, "character": KEY_C,
		"mouse": true, "pad": 0},
	2: {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "interact": KEY_ENTER,
		"talk": KEY_KP_PERIOD, "use_left": KEY_KP_0, "use_right": KEY_KP_1, "inventory": KEY_KP_2,
		"character": KEY_KP_3, "mouse": false, "pad": 1},
}


func _ready() -> void:
	for n in PLAYER_KEYS:
		_register_player(n, PLAYER_KEYS[n])


## Nome da primeira tecla de teclado da ação (para exibir em instruções).
static func key_label(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return "?"


func _register_player(n: int, k: Dictionary) -> void:
	var pad: int = k.pad
	_set_action("p%d_up" % n, _move_events(k.up, JOY_BUTTON_DPAD_UP, pad, JOY_AXIS_LEFT_Y, -1.0))
	_set_action("p%d_down" % n, _move_events(k.down, JOY_BUTTON_DPAD_DOWN, pad, JOY_AXIS_LEFT_Y, 1.0))
	_set_action("p%d_left" % n, _move_events(k.left, JOY_BUTTON_DPAD_LEFT, pad, JOY_AXIS_LEFT_X, -1.0))
	_set_action("p%d_right" % n, _move_events(k.right, JOY_BUTTON_DPAD_RIGHT, pad, JOY_AXIS_LEFT_X, 1.0))
	_set_action("p%d_interact" % n, _button_events(k.interact, JOY_BUTTON_A, pad))
	_set_action("p%d_talk" % n, _button_events(k.talk, JOY_BUTTON_Y, pad))
	_set_action("p%d_inventory" % n, _button_events(k.inventory, JOY_BUTTON_BACK, pad))
	_set_action("p%d_character" % n, _button_events(k.character, JOY_BUTTON_START, pad))
	var left := _button_events(k.use_left, JOY_BUTTON_X, pad)
	var right := _button_events(k.use_right, JOY_BUTTON_B, pad)
	if k.mouse:
		left.append(_mouse_event(MOUSE_BUTTON_LEFT))
		right.append(_mouse_event(MOUSE_BUTTON_RIGHT))
	_set_action("p%d_use_left" % n, left)
	_set_action("p%d_use_right" % n, right)


func _set_action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)  # idempotente
	else:
		InputMap.add_action(action, DEADZONE)
	for e in events:
		InputMap.action_add_event(action, e)


func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _button_events(key: Key, button: JoyButton, pad: int) -> Array:
	var events: Array = []
	if key != KEY_NONE:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		events.append(key_event)
	var button_event := InputEventJoypadButton.new()
	button_event.device = pad
	button_event.button_index = button
	events.append(button_event)
	return events


func _move_events(key: Key, button: JoyButton, pad: int, axis: JoyAxis, axis_value: float) -> Array:
	var events := _button_events(key, button, pad)
	var axis_event := InputEventJoypadMotion.new()
	axis_event.device = pad
	axis_event.axis = axis
	axis_event.axis_value = axis_value
	events.append(axis_event)
	return events
