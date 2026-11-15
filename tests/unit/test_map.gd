extends "res://tests/base_test.gd"
## Mapa e minimapa (Fase 5): ícones, geometria, o que o jogador conhece, minimapa no HUD,
## mapa de tela cheia e a tecla M.

const MapIcons := preload("res://scripts/art/map_icons.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const MapPanelScript := preload("res://scripts/ui/map_panel.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
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


func _player(pos := Vector2(500, 500)) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = pos
	_add(player)
	await wait_physics_frames(2)
	return player


# --- ícones ---

func test_every_building_type_has_a_glyph_and_a_legend_entry() -> void:
	for type in BuildingDefs.ORDER:
		var glyph := MapIcons.glyph_of(type)
		assert_ne(glyph, "", "tipo sem glifo: %s" % type)
		assert_true(MapIcons.GLYPHS.has(glyph), "glifo inexistente: %s" % glyph)
		assert_ne(MapIcons.label_of(glyph), "", "glifo sem legenda: %s" % glyph)


func test_glyphs_are_7x7_and_icons_9x9_with_palette_colors() -> void:
	for glyph in MapIcons.glyphs():
		var rows: Array = MapIcons.GLYPHS[glyph]
		assert_eq(rows.size(), 7, "altura de %s" % glyph)
		for row in rows:
			assert_eq((row as String).length(), 7, "largura de %s" % glyph)
		var canvas: RefCounted = MapIcons.canvas(glyph)
		assert_eq(canvas.width, MapIcons.SIDE)
		assert_eq(canvas.height, MapIcons.SIDE)
		assert_true(canvas.only_palette_colors(), "cor fora da paleta em %s" % glyph)
		assert_gt(canvas.opaque_count(), 20.0)


func test_every_legend_label_is_used_by_some_building_type() -> void:
	var used := {}
	for type in MapIcons.GLYPH_OF:
		used[MapIcons.GLYPH_OF[type]] = true
	for glyph in MapIcons.LABELS:
		assert_true(used.has(glyph), "legenda sem prédio: %s" % glyph)


func test_map_icon_textures_are_cached() -> void:
	var a := SpriteFactory.map_icon("bank")
	var before := SpriteFactory.build_count()
	assert_true(SpriteFactory.map_icon("bank") == a)
	assert_eq(SpriteFactory.build_count(), before)


# --- geometria ---

func test_district_colors_are_palette_names() -> void:
	for id in DistrictLayout.IDS + ["country"]:
		assert_true(Palette_has(MapView.lot_color_name(id)), id)
		assert_true(Palette_has(MapView.building_color_name(id)), id)


func Palette_has(color_name: String) -> bool:
	return preload("res://scripts/art/palette.gd").COLORS.has(color_name)


func test_world_rect_covers_city_and_country() -> void:
	var world := MapView.world_rect(layout)
	assert_true(world.encloses(Rect2(Vector2.ZERO, Vector2(CityLayout.city_size(), CityLayout.city_size()))))
	assert_true(world.encloses(layout.country.region_rect()))


func test_fit_keeps_the_aspect_and_centers() -> void:
	var view := Rect2(0, 0, 1000, 500)
	var fitted := MapView.fit(view, Rect2(100, 100, 400, 400))
	assert_almost_eq(fitted.size.x / fitted.size.y, 2.0, 0.001)
	assert_eq(fitted.size, Vector2(400, 200))
	assert_eq(fitted.get_center(), Vector2(300, 300))


func test_world_screen_conversion_round_trips() -> void:
	var view := Rect2(1000, 2000, 1680, 1680)
	var dest := Rect2(30, 40, 200, 200)
	for p in [Vector2(1000, 2000), Vector2(1800, 2900), Vector2(2680, 3680)]:
		assert_almost_eq(MapView.to_world(MapView.to_screen(p, view, dest), view, dest).distance_to(p), 0.0, 0.01)
	assert_eq(MapView.to_screen(view.get_center(), view, dest), dest.get_center())


func test_minimap_window_is_a_block_and_a_half_around_the_player() -> void:
	var view := MapView.view_around(Vector2(3000, 3000))
	assert_eq(view.get_center(), Vector2(3000, 3000))
	assert_eq(view.size.x, CityLayout.BLOCK * 3.0)
	assert_eq(MapView.MINIMAP_RADIUS, CityLayout.BLOCK * 1.5)


# --- o que o jogador conhece ---

func test_only_known_buildings_get_icons() -> void:
	var all: Array[Dictionary] = layout.buildings()
	var known := {all[0].id: true, all[5].id: true}
	var icons := MapView.known_icons(layout, known)
	assert_eq(icons.size(), 2)
	for icon in icons:
		assert_true(known.has(icon.id))
		assert_eq(icon.glyph, MapIcons.glyph_of(icon.type))
	assert_eq(MapView.known_icons(layout, {}).size(), 0)


func test_icons_in_a_window_are_inside_it() -> void:
	var known := {}
	for b in layout.buildings():
		known[b.id] = true
	var view := MapView.view_around(Vector2(3360, 3360))
	var inside := MapView.icons_in(layout, known, view)
	assert_gt(inside.size(), 0.0)
	assert_true(inside.size() < known.size())
	for icon in inside:
		assert_true(view.has_point(icon.pos))


func test_profile_marks_a_building_once() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	assert_true(profile.know_building(11))
	assert_false(profile.know_building(11))
	assert_eq(profile.known_buildings.size(), 1)


func test_world_reveals_buildings_near_the_player_only() -> void:
	var main := MAIN_SCENE.instantiate()
	_add(main)
	await wait_physics_frames(2)
	var player = tree.get_nodes_in_group("players")[0]
	var world: Node = main.get_node("World")
	var near: Dictionary = world.layout.city.buildings[0]
	var far: Dictionary = world.layout.city.buildings[140]
	player.global_position = (near.rect as Rect2).get_center()
	player.profile.known_buildings.clear()  # o início da fase já viu o que cerca o ponto de partida
	var added: int = world.mark_seen_buildings()
	assert_gt(float(added), 0.0)
	var known: Dictionary = player.profile.known_buildings
	assert_true(known.has(near.id))
	assert_false(known.has(far.id))
	assert_eq(world.mark_seen_buildings(), 0, "já vistos não contam de novo")


func test_seen_buildings_use_the_view_radius() -> void:
	var main := MAIN_SCENE.instantiate()
	_add(main)
	await wait_physics_frames(2)
	var player = tree.get_nodes_in_group("players")[0]
	var world: Node = main.get_node("World")
	var b: Dictionary = world.layout.city.buildings[10]
	var rect: Rect2 = b.rect
	player.global_position = Vector2(rect.get_center().x, rect.end.y + world.SEEN_RADIUS - 5.0)
	world.mark_seen_buildings()
	assert_true(player.profile.known_buildings.has(b.id), "dentro do raio")
	player.profile.known_buildings.erase(b.id)
	player.global_position = Vector2(rect.get_center().x, rect.end.y + world.SEEN_RADIUS + 60.0)
	world.mark_seen_buildings()
	assert_false(player.profile.known_buildings.has(b.id), "fora do raio")


# --- minimapa ---

func test_minimap_sits_in_the_hud_and_hides_inside_buildings() -> void:
	var player = await _player()
	await wait_frames(2)
	assert_true(player.hud.minimap_visible(), "na rua")
	GameState.set_inside(3, Vector2.ZERO)
	await wait_frames(2)
	assert_false(player.hud.minimap_visible(), "dentro de um prédio")
	GameState.set_outside()
	await wait_frames(2)
	assert_true(player.hud.minimap_visible())


func test_minimap_follows_the_player_and_shows_targets() -> void:
	var player = await _player(Vector2(3360, 3360))
	player.targets = [Vector2(3600, 3400)]
	await wait_frames(3)
	var minimap: Control = player.hud.minimap()
	assert_eq(minimap.center, Vector2(3360, 3360))
	assert_eq(minimap.targets.size(), 1)
	assert_eq(minimap.view().get_center(), Vector2(3360, 3360))
	assert_eq(minimap.size, Vector2(Minimap.SIDE, Minimap.SIDE))


func test_minimap_redraw_is_throttled() -> void:
	var minimap := Minimap.new()
	_add(minimap)
	await wait_frames(1)
	minimap.set_state(layout, {}, Vector2(1000, 1000), [], 0.0)
	var drawn := Vector2(1000, 1000)
	assert_eq(minimap._drawn_center, drawn)
	minimap.set_state(layout, {}, Vector2(1002, 1000), [], 0.01)
	assert_eq(minimap._drawn_center, drawn, "andou pouco e foi rápido: não redesenha")
	minimap.set_state(layout, {}, Vector2(1020, 1000), [], 0.01)
	assert_eq(minimap._drawn_center, Vector2(1020, 1000), "andou o bastante")
	minimap.set_state(layout, {}, Vector2(1020, 1000), [], Minimap.REDRAW_INTERVAL + 0.01)
	assert_eq(minimap._since_draw, 0.0, "passou o intervalo")


func test_minimap_draws_without_errors_everywhere() -> void:
	var minimap := Minimap.new()
	_add(minimap)
	await wait_frames(1)
	for p in [Vector2(10, 10), Vector2(3360, 3360), Vector2(6700, 3360), Vector2(10000, 2000), Vector2(13400, 6700)]:
		minimap.set_state(layout, {1: true}, p, [p + Vector2(100, 100)], 1.0)
		await wait_frames(1)
	assert_true(minimap.is_inside_tree())


# --- mapa de tela cheia ---

func test_map_panel_opens_on_the_players_region() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	panel.open(layout, {}, Vector2(3000, 3000), [])
	assert_true(panel.is_open())
	assert_eq(panel.mode, MapPanelScript.CITY)
	panel.close()
	panel.open(layout, {}, Vector2(9000, 3000), [])
	assert_eq(panel.mode, MapPanelScript.COUNTRY)
	assert_eq(panel.view_rect(), layout.country.region_rect())
	panel.toggle_mode()
	assert_eq(panel.mode, MapPanelScript.CITY)
	assert_eq(panel.view_rect().size, Vector2(CityLayout.city_size(), CityLayout.city_size()))


func test_map_panel_fits_the_view_inside_the_screen() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	panel.open(layout, {}, Vector2(3000, 3000), [])
	for screen in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(960, 540)]:
		var rect: Rect2 = panel.map_rect(screen)
		assert_true(Rect2(Vector2.ZERO, screen).encloses(rect), "mapa fora da tela %s" % str(screen))
		assert_almost_eq(rect.size.x, rect.size.y, 0.5, "mapa quadrado")


func test_map_panel_draws_every_mode_and_emits_closed() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	var closed := [0]
	panel.closed.connect(func() -> void: closed[0] += 1)
	var known := {}
	for b in layout.buildings():
		known[b.id] = true
	panel.open(layout, known, Vector2(3000, 3000), [Vector2(3300, 3000)])
	await wait_frames(3)
	panel.toggle_mode()
	await wait_frames(3)
	panel.close()
	panel.close()
	assert_eq(closed[0], 1, "fechou uma vez só")
	assert_false(panel.is_open())


func test_map_panel_finds_the_icon_under_the_mouse() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	var b: Dictionary = layout.city.buildings[0]
	panel.open(layout, {b.id: true}, Vector2(3000, 3000), [])
	var screen := Vector2(1280, 720)
	var at := MapView.to_screen((b.rect as Rect2).get_center(), panel.view_rect(), panel.map_rect(screen))
	assert_eq(panel.icon_near(at + Vector2(3, 2), screen).get("id", -1), b.id)
	assert_true(panel.icon_near(at + Vector2(80, 80), screen).is_empty())
	panel.open(layout, {}, Vector2(3000, 3000), [])
	assert_true(panel.icon_near(at, screen).is_empty(), "o que não é conhecido não aparece")


func test_district_names_are_placed_inside_the_city() -> void:
	var panel := MapPanelScript.new()
	_add(panel)
	await wait_frames(1)
	panel.open(layout, {}, Vector2(3000, 3000), [])
	var city := Rect2(Vector2.ZERO, Vector2(CityLayout.city_size(), CityLayout.city_size()))
	for id in DistrictLayout.IDS:
		assert_true(city.has_point(panel.district_center(id)), id)
		assert_ne(layout.city.districts.name_of(id), "")


# --- tecla M ---

func test_pressing_the_map_key_opens_and_closes_the_map() -> void:
	var player = await _player()
	Input.action_press("p1_map")
	await wait_physics_frames(2)
	Input.action_release("p1_map")
	assert_true(player.map_panel.is_open(), "M abre")
	assert_true(player.panels_open())
	await wait_physics_frames(2)
	Input.action_press("p1_map")
	await wait_physics_frames(2)
	Input.action_release("p1_map")
	assert_false(player.map_panel.is_open(), "M fecha")


func test_map_is_not_available_inside_buildings() -> void:
	var player = await _player()
	GameState.set_inside(3, Vector2.ZERO)
	player.toggle_map()
	assert_false(player.map_panel.is_open())
	assert_true(player.hud.toast_visible())
	assert_true(player.hud.toast_text().contains("rua"))


func test_opening_other_panels_closes_the_map() -> void:
	var player = await _player()
	player.toggle_map()
	assert_true(player.map_panel.is_open())
	player.toggle_inventory()
	assert_false(player.map_panel.is_open())
	assert_true(player.inventory_panel.is_open())
	player.toggle_map()
	assert_true(player.map_panel.is_open())
	assert_false(player.inventory_panel.is_open())
	player.toggle_character()
	assert_false(player.map_panel.is_open())


func test_player_cannot_walk_or_shoot_with_the_map_open() -> void:
	var player = await _player()
	player.toggle_map()
	Input.action_press("p1_right")
	await wait_physics_frames(5)
	Input.action_release("p1_right")
	assert_almost_eq(player.global_position.x, 500.0, 0.5)
	assert_true(player.fire_hand("left") == null)


func test_map_key_belongs_to_each_player() -> void:
	for n in [1, 2]:
		assert_true(InputMap.has_action("p%d_map" % n))
		assert_true(InputMap.has_action("p%d_pause" % n))
	assert_eq(InputSetupScript.key_label("p1_map"), "M")
	assert_eq(InputSetupScript.key_label("p1_pause"), "Escape")
