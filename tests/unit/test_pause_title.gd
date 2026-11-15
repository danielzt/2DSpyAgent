extends "res://tests/base_test.gd"
## Tela de título e de pausa (Fase 5): menu em fonte pixel, lista de controles, pausa que
## congela o jogo, opção de tremor de câmera e a arte da cidade à noite.

const PixelMenu := preload("res://scripts/ui/pixel_menu.gd")
const PausePanel := preload("res://scripts/ui/pause_panel.gd")
const ControlsText := preload("res://scripts/ui/controls_text.gd")
const TitleArt := preload("res://scripts/art/title_art.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TITLE_SCENE := preload("res://scenes/title/title.tscn")

var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	GameState.screen_shake = true


func after_each() -> void:
	tree.paused = false
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	GameState.set_outside()
	await wait_frames(3)


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	extras.append(node)
	return node


func _player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	_add(player)
	await wait_physics_frames(2)
	return player


func _event(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


# --- controles ---

func test_controls_list_comes_from_the_real_actions() -> void:
	for n in [1, 2]:
		var lines := ControlsText.lines(n)
		assert_eq(lines.size(), 9)
		for pair in lines:
			assert_ne(pair[0], "")
			assert_ne(pair[1], "")
			assert_false((pair[1] as String).contains("?"), "tecla desconhecida em %s" % pair[0])
	var p1 := ControlsText.lines(1)
	assert_eq(p1[0][1], "W A S D")
	assert_eq(p1[3][1], "E")
	assert_eq(p1[7][1], "M")
	assert_eq(p1[8][1], "Escape")


func test_player_two_controls_use_other_keys() -> void:
	var p2 := ControlsText.lines(2)
	assert_ne(p2[0][1], ControlsText.lines(1)[0][1])
	assert_eq(p2[3][1], "Enter")


# --- menu ---

func _menu() -> Control:
	var menu := PixelMenu.new()
	_add(menu)
	var items: Array[String] = ["Um", "Dois", "Três"]
	menu.set_items(items)
	return menu


func test_menu_moves_and_wraps() -> void:
	var menu := _menu()
	await wait_frames(1)
	assert_eq(menu.selected, 0)
	menu.move(1)
	assert_eq(menu.selected, 1)
	menu.move(-2)
	assert_eq(menu.selected, 2, "volta ao fim")
	menu.move(1)
	assert_eq(menu.selected, 0, "volta ao início")


func test_menu_choose_emits_the_selected_index() -> void:
	var menu := _menu()
	var got := []
	menu.chosen.connect(func(i: int) -> void: got.append(i))
	menu.move(1)
	menu.choose()
	assert_eq(got, [1])


func test_menu_reads_the_player_actions() -> void:
	var menu := _menu()
	var got := []
	menu.chosen.connect(func(i: int) -> void: got.append(i))
	await wait_frames(1)
	Input.action_press("p1_down")
	await wait_frames(2)
	Input.action_release("p1_down")
	assert_eq(menu.selected, 1)
	Input.action_press("p1_interact")
	await wait_frames(2)
	Input.action_release("p1_interact")
	assert_eq(got, [1])


func test_inactive_menu_ignores_input() -> void:
	var menu := _menu()
	menu.active = false
	await wait_frames(1)
	Input.action_press("p1_down")
	await wait_frames(2)
	Input.action_release("p1_down")
	assert_eq(menu.selected, 0)


func test_menu_mouse_hover_and_click() -> void:
	var menu := _menu()
	await wait_frames(1)
	var got := []
	menu.chosen.connect(func(i: int) -> void: got.append(i))
	var move := InputEventMouseMotion.new()
	move.position = Vector2(30, PixelMenu.ROW * 2.0 + 10.0)
	menu._gui_input(move)
	assert_eq(menu.selected, 2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(30, PixelMenu.ROW * 1.0 + 10.0)
	menu._gui_input(click)
	assert_eq(got, [1])
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(30, PixelMenu.ROW * 9.0)
	menu._gui_input(outside)
	assert_eq(got, [1], "clique fora dos itens não escolhe")


func test_menu_size_grows_with_its_items() -> void:
	var menu := _menu()
	var small: float = menu.size.x
	var items: Array[String] = ["Um", "Dois", "Um item com um texto bem mais comprido"]
	menu.set_items(items)
	assert_gt(menu.size.x, small)
	assert_eq(menu.size.y, PixelMenu.ROW * 3.0)


# --- pausa ---

func test_pause_freezes_the_game_and_resumes() -> void:
	var player = await _player()
	player.pause()
	assert_true(player.pause_panel.is_open())
	assert_true(tree.paused)
	player.pause_panel.close()
	assert_false(player.pause_panel.is_open())
	await wait_frames(4)
	assert_false(tree.paused, "o jogo volta depois de dois quadros")


func test_pause_key_opens_the_pause_through_the_input_event() -> void:
	var player = await _player()
	player._unhandled_input(_event("p1_pause"))
	assert_true(player.pause_panel.is_open())


func test_pause_is_not_opened_over_another_panel() -> void:
	var player = await _player()
	player.toggle_inventory()
	player.pause()
	assert_false(player.pause_panel.is_open())
	assert_false(tree.paused)


func test_pause_stops_the_player_from_moving() -> void:
	var player = await _player()
	player.pause()
	Input.action_press("p1_right")
	await wait_physics_frames(6)
	Input.action_release("p1_right")
	assert_almost_eq(player.global_position.x, 500.0, 0.5)


func test_pause_menu_options() -> void:
	var player = await _player()
	player.pause()
	var panel = player.pause_panel
	assert_eq(panel.menu().items.size(), 3)
	assert_eq(panel.menu().items[PausePanel.SHAKE], "Tremor de câmera: SIM")
	panel.menu().chosen.emit(PausePanel.SHAKE)
	assert_false(GameState.screen_shake)
	assert_eq(panel.menu().items[PausePanel.SHAKE], "Tremor de câmera: NÃO")
	panel.menu().chosen.emit(PausePanel.SHAKE)
	assert_true(GameState.screen_shake)
	panel.menu().chosen.emit(PausePanel.RESUME)
	assert_false(panel.is_open())


func test_pause_shows_the_door_position_inside_a_building() -> void:
	var player = await _player()
	GameState.set_inside(4, Vector2(1234, 567))
	player.pause()
	assert_eq(player.pause_panel.player_position, Vector2(1234, 567))


func test_pause_map_fits_the_screen_layout() -> void:
	var player = await _player()
	player.pause()
	var rect: Rect2 = player.pause_panel.map_rect()
	assert_gt(rect.size.x, 300.0)
	assert_true(rect.size.x <= PausePanel.MAP_SIZE.x + 0.1 and rect.size.y <= PausePanel.MAP_SIZE.y + 0.1)


func test_pause_panel_sits_above_the_other_layers() -> void:
	var player = await _player()
	assert_gt(float(player.pause_panel.layer), float(player.map_panel.layer))
	assert_gt(float(player.pause_panel.layer), float(player.hud.layer))


# --- título ---

func test_title_art_is_deterministic_and_uses_the_palette() -> void:
	var a: RefCounted = TitleArt.canvas()
	var b: RefCounted = TitleArt.canvas()
	assert_eq(a.width, TitleArt.WIDTH)
	assert_eq(a.height, TitleArt.HEIGHT)
	assert_eq(a.image.get_data(), b.image.get_data())
	assert_true(a.only_palette_colors())
	assert_ne(TitleArt.canvas(7).image.get_data(), a.image.get_data(), "outra seed, outra cidade")


func test_title_art_has_lit_windows_a_moon_and_stars() -> void:
	var canvas: RefCounted = TitleArt.canvas()
	var counts := {}
	for y in canvas.height:
		for x in canvas.width:
			var c: Color = canvas.get_px(x, y)
			counts[c] = counts.get(c, 0) + 1
	var amber: Color = preload("res://scripts/art/palette.gd").get_color("amber")
	var cream: Color = preload("res://scripts/art/palette.gd").get_color("cream")
	assert_gt(float(counts.get(amber, 0)), 200.0, "janelas âmbar acesas")
	assert_gt(float(counts.get(cream, 0)), 200.0, "lua e janelas")


func test_title_scene_is_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/title/title.tscn")


func test_title_menu_has_new_game_and_controls() -> void:
	var title := TITLE_SCENE.instantiate()
	_add(title)
	await wait_frames(2)
	var items: Array[String] = title.menu().items
	assert_eq(items[TitleScreen.NEW_GAME], "Novo jogo")
	assert_eq(items[TitleScreen.CONTROLS], "Controles")
	assert_eq(items.has("Sair"), not OS.has_feature("web"))


func test_title_controls_overlay_opens_and_closes() -> void:
	var title := TITLE_SCENE.instantiate()
	_add(title)
	await wait_frames(2)
	title.menu().chosen.emit(TitleScreen.CONTROLS)
	assert_true(title.controls_open)
	assert_false(title.menu().active, "o menu espera")
	title._unhandled_input(_event("ui_cancel"))
	assert_false(title.controls_open)
	assert_true(title.menu().active)
	assert_true(title.menu().visible)


func test_title_draws_in_odd_screen_sizes() -> void:
	var title := TITLE_SCENE.instantiate()
	_add(title)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)  # para poder fixar o tamanho
	for s in [Vector2(1280, 720), Vector2(640, 360), Vector2(3440, 1440)]:
		title.size = s
		title._place_menu()
		title.queue_redraw()
		await wait_frames(1)
	title.controls_open = true
	title.queue_redraw()
	await wait_frames(1)
	assert_true(title.is_inside_tree())
