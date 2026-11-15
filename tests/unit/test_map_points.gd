extends "res://tests/base_test.gd"
## Neblina do mapa e pontos marcados pelo jogador (Fase 6, itens 6.6 e 6.7).

const MapIcons := preload("res://scripts/art/map_icons.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const MapPanelScript := preload("res://scripts/ui/map_panel.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var layout
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	layout = WorldLayout.new()
	# a ficha nova já traz a casa do agente (conhecida, explorada e marcada): estes testes
	# começam do zero
	var profile: RefCounted = GameState.profile_for(1)
	profile.waypoints.clear()
	profile.active_waypoint = -1
	profile.known_buildings.clear()
	profile.explored.clear()


func after_each() -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	GameState.set_outside()
	await wait_frames(2)


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	extras.append(node)
	return node


func _player(pos := Vector2(1000, 1000)) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = pos
	_add(player)
	await wait_physics_frames(2)
	return player


func _panel_with_profile() -> Array:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	var profile: RefCounted = GameState.profile_for(1)
	panel.open(layout, profile.known_buildings, Vector2(3000, 3000), [], profile)
	return [panel, profile]


# --- neblina ---

func test_exploring_clears_the_blocks_around_the_player() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	assert_false(profile.is_explored(Vector2(3000, 3000)))
	var added: int = profile.explore(Vector2(3000, 3000))
	assert_gt(float(added), 3.0)
	assert_true(profile.is_explored(Vector2(3000, 3000)))
	assert_true(profile.is_explored(Vector2(3500, 3000)), "o quarteirão vizinho")
	assert_false(profile.is_explored(Vector2(5000, 3000)), "longe continua com neblina")
	assert_eq(profile.explore(Vector2(3000, 3000)), 0, "explorar de novo não soma")


func test_exploring_works_at_the_world_edges() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	assert_gt(float(profile.explore(Vector2(5, 5))), 0.0)
	assert_gt(float(profile.explore(Vector2(13430, 6710))), 0.0)
	assert_true(profile.is_explored(Vector2(5, 5)))


func test_world_explores_around_the_player() -> void:
	var main := MAIN_SCENE.instantiate()
	_add(main)
	await wait_physics_frames(2)
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = Vector2(9000, 2000)
	main.get_node("World").mark_seen_buildings()
	assert_true(player.profile.is_explored(Vector2(9000, 2000)))


func test_visiting_a_building_explores_its_door() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	GameState.set_inside(2, Vector2(4000, 4000))
	assert_true(profile.is_explored(Vector2(4000, 4000)))


func test_fog_draws_without_errors_and_with_the_documented_opacity() -> void:
	var canvas := Control.new()
	_add(canvas)
	canvas.size = Vector2(100, 100)
	var profile: RefCounted = GameState.profile_for(1)
	profile.explore(Vector2(560, 560))
	var drawn := [0]
	canvas.draw.connect(func() -> void:
		MapView._draw_fog(canvas, profile, Rect2(0, 0, 1120, 1120), Rect2(0, 0, 100, 100))
		drawn[0] += 1)
	canvas.queue_redraw()
	await wait_frames(2)
	assert_gt(float(drawn[0]), 0.0)
	assert_eq(MapView.FOG_ALPHA, 0.88)


func test_new_game_clears_waypoints_and_fog() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	profile.add_waypoint(Vector2(1, 1))
	profile.explore(Vector2(100, 100))
	GameState.new_game()
	var fresh: RefCounted = GameState.profile_for(1)
	assert_eq(fresh.waypoints.size(), 1, "só o ponto da casa")
	assert_eq(fresh.waypoints[0].name, "Casa")
	assert_false(fresh.is_explored(Vector2(100, 100)), "a neblina voltou")


# --- pontos (dados) ---

func test_adding_waypoints_names_and_limits_them() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	assert_eq(profile.active_waypoint, -1)
	assert_true(profile.active_waypoint_data().is_empty())
	profile.add_waypoint(Vector2(100, 100))
	profile.add_waypoint(Vector2(200, 100))
	assert_eq(profile.waypoints[0].name, "Ponto 1")
	assert_eq(profile.waypoints[1].name, "Ponto 2")
	assert_eq(profile.active_waypoint, 1, "o último vira o ativo")
	for i in 6:
		profile.add_waypoint(Vector2(i * 300.0, 0))
	assert_eq(profile.waypoints.size(), profile.MAX_WAYPOINTS)
	assert_eq(profile.active_waypoint, profile.MAX_WAYPOINTS - 1)


func test_removing_waypoints_keeps_the_active_one_consistent() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	profile.add_waypoint(Vector2(0, 0))
	profile.add_waypoint(Vector2(500, 0))
	profile.add_waypoint(Vector2(1000, 0))
	profile.active_waypoint = 2
	profile.remove_waypoint(0)
	assert_eq(profile.active_waypoint, 1, "o ativo acompanha a lista")
	assert_eq(profile.active_waypoint_data().pos, Vector2(1000, 0))
	profile.remove_waypoint(1)
	assert_eq(profile.active_waypoint, 0)
	profile.remove_waypoint(0)
	assert_eq(profile.active_waypoint, -1)
	profile.remove_waypoint(5)
	assert_eq(profile.waypoints.size(), 0)


func test_waypoint_near_picks_the_closest_within_the_radius() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	profile.add_waypoint(Vector2(1000, 1000))
	profile.add_waypoint(Vector2(1100, 1000))
	assert_eq(profile.waypoint_near(Vector2(1090, 1000), 50.0), 1)
	assert_eq(profile.waypoint_near(Vector2(1000, 1030), 50.0), 0)
	assert_eq(profile.waypoint_near(Vector2(5000, 5000), 50.0), -1)


# --- clique no mapa ---

func test_clicking_the_map_places_a_waypoint_at_that_spot() -> void:
	var pair: Array = await _panel_with_profile()
	var panel = pair[0]
	var profile = pair[1]
	var screen := Vector2(1280, 720)
	var dest: Rect2 = panel.map_rect(screen)
	assert_eq(panel.place_waypoint(dest.get_center(), screen), 0)
	assert_eq(profile.waypoints.size(), 1)
	assert_true((profile.waypoints[0].pos as Vector2).distance_to(panel.view_rect().get_center()) < 5.0)


func test_clicking_outside_the_map_does_nothing() -> void:
	var pair: Array = await _panel_with_profile()
	assert_eq(pair[0].place_waypoint(Vector2(2, 2), Vector2(1280, 720)), -1)
	assert_eq(pair[1].waypoints.size(), 0)


func test_clicking_an_existing_point_selects_it_and_right_click_removes() -> void:
	var pair: Array = await _panel_with_profile()
	var panel = pair[0]
	var profile = pair[1]
	var screen := Vector2(1280, 720)
	var dest: Rect2 = panel.map_rect(screen)
	panel.place_waypoint(dest.position + Vector2(100, 100), screen)
	panel.place_waypoint(dest.position + Vector2(300, 300), screen)
	assert_eq(profile.active_waypoint, 1)
	assert_eq(panel.place_waypoint(dest.position + Vector2(102, 101), screen), 0, "perto de um ponto: escolhe ele")
	assert_eq(profile.waypoints.size(), 2)
	assert_eq(profile.active_waypoint, 0)
	assert_true(panel.remove_waypoint_at(dest.position + Vector2(301, 299), screen))
	assert_eq(profile.waypoints.size(), 1)
	assert_false(panel.remove_waypoint_at(dest.position + Vector2(400, 50), screen), "nada perto")


func test_mouse_events_on_the_map_place_and_remove_points() -> void:
	var pair: Array = await _panel_with_profile()
	var panel = pair[0]
	var dest: Rect2 = panel.map_rect(panel._canvas.size)
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.position = dest.get_center()
	panel._on_canvas_input(left)
	assert_eq(pair[1].waypoints.size(), 1)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = dest.get_center()
	panel._on_canvas_input(right)
	assert_eq(pair[1].waypoints.size(), 0)


func test_panel_without_a_profile_ignores_clicks() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	panel.open(layout, {}, Vector2(3000, 3000), [])
	assert_eq(panel.place_waypoint(Vector2(600, 300), Vector2(1280, 720)), -1)


# --- direção no HUD ---

func test_hud_points_to_the_active_waypoint_with_a_distance() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(1000 + 3200, 1000), "Casa")
	await wait_frames(2)
	assert_eq(player.hud.waypoint_text(), "Casa  100 m")
	assert_true(player.hud.waypoint_arrow_visible())
	player.profile.remove_waypoint(0)
	await wait_frames(2)
	assert_eq(player.hud.waypoint_text(), "")
	assert_false(player.hud.waypoint_arrow_visible())


func test_no_arrow_when_the_waypoint_is_close_but_the_text_stays() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(1000 + 200, 1000), "Perto")
	await wait_frames(2)
	assert_false(player.hud.waypoint_arrow_visible())
	assert_true(player.hud.waypoint_text().begins_with("Perto"))


func test_arriving_removes_the_waypoint_and_tells_the_player() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(1050, 1000), "Esquina")
	await wait_frames(2)
	assert_eq(player.profile.waypoints.size(), 0)
	assert_true(player.hud.toast_text().contains("Chegou"))


func test_waypoint_is_not_followed_inside_buildings() -> void:
	var player = await _player(Vector2(1000, 1000))
	player.profile.add_waypoint(Vector2(5000, 1000), "Longe")
	GameState.set_inside(3, Vector2.ZERO)
	await wait_frames(2)
	assert_eq(player.hud.waypoint_text(), "")
	GameState.set_outside()
	await wait_frames(2)
	assert_ne(player.hud.waypoint_text(), "")


func test_pin_glyphs_exist() -> void:
	for glyph in ["pin", "pin_on"]:
		assert_true(MapIcons.GLYPHS.has(glyph))
		assert_true(MapIcons.canvas(glyph).only_palette_colors())
