extends "res://tests/base_test.gd"
## Dia e noite no mundo: tinta ambiente, camada de luz (janelas, letreiros, postes, faróis),
## interiores que não escurecem, portas fechadas fora do horário e população por hora.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const LightChunk := preload("res://scripts/world/light_chunk.gd")
const BuildingArt := preload("res://scripts/art/building_art.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var main: Node
var nodes: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	GameState.set_outside()
	GameState.has_return = false
	WorldClock.paused = true


func after_each() -> void:
	Input.action_release("p1_interact")
	if main != null and is_instance_valid(main):
		main.queue_free()
	main = null
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	await wait_frames(3)
	for n in tree.root.get_children():
		if n.name == "Interior" or n.name == "Main":
			n.queue_free()
	GameState.set_outside()
	await wait_frames(2)


func _start(hour: float) -> Node:
	WorldClock.set_hour(hour)
	main = MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await wait_frames(2)
	return main.get_node("World")


func _player() -> Node:
	return tree.get_nodes_in_group("players")[0]


func _count(node: Node, type_name: String) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		total += _count(child, type_name)
	return total


# --- arte das luzes (pura) ---

func test_lit_windows_are_a_seeded_part_of_the_facade_windows() -> void:
	var city := CityLayout.new()
	var lit_total := 0
	var all_total := 0
	for b in city.buildings.slice(0, 60):
		var style := BuildingStyle.for_building(b)
		var all := BuildingArt.window_cells(b, style)
		var lit := BuildingArt.lit_window_cells(b, style)
		assert_eq(lit, BuildingArt.lit_window_cells(b, style), "padrão determinístico")
		for cell in lit:
			assert_true(all.has(cell))
		var fraction := BuildingArt.lit_fraction(b)
		assert_true(fraction >= 0.4 and fraction <= 0.7)
		lit_total += lit.size()
		all_total += all.size()
	var ratio := float(lit_total) / float(all_total)
	assert_true(ratio > 0.4 and ratio < 0.7, "%.2f das janelas acesas" % ratio)


func test_window_cells_match_the_drawn_facade() -> void:
	var city := CityLayout.new()
	for b in city.buildings.slice(0, 20):
		var style := BuildingStyle.for_building(b)
		var canvas: RefCounted = BuildingArt.render(b, style)
		var navy := preload("res://scripts/art/palette.gd").get_color("navy")
		for cell in BuildingArt.window_cells(b, style):
			assert_eq(canvas.get_px(cell.x + 1, cell.y), navy, "prédio %d: janela fora do lugar" % b.id)
			assert_true(cell.y >= BuildingArt.facade_top(b, style))


func test_window_light_canvas_covers_only_the_facade() -> void:
	var city := CityLayout.new()
	for b in city.buildings.slice(0, 20):
		var style := BuildingStyle.for_building(b)
		var canvas: RefCounted = BuildingArt.window_lights(b, style)
		assert_eq(canvas.width, int((b.rect as Rect2).size.x / 2.0))
		assert_eq(canvas.height, BuildingStyle.facade_texels(style.floors))
		assert_true(canvas.only_palette_colors())
		if not BuildingArt.lit_window_cells(b, style).is_empty():
			assert_gt(canvas.opaque_count(), 0.0)


func test_sign_canvas_matches_the_sign_on_the_building() -> void:
	var city := CityLayout.new()
	var with_sign := 0
	for b in city.buildings:
		var style := BuildingStyle.for_building(b)
		var placement := BuildingArt.sign_placement(b, style)
		var canvas: RefCounted = BuildingArt.sign_canvas(b, style)
		if placement.is_empty():
			assert_true(canvas == null)
			continue
		with_sign += 1
		var rect: Rect2i = placement.rect
		assert_eq(Vector2i(canvas.width, canvas.height), rect.size)
		assert_true(rect.position.x >= 0 and rect.end.x <= int((b.rect as Rect2).size.x / 2.0), "letreiro fora do prédio %d" % b.id)
		if with_sign <= 12:
			# o letreiro avulso é igual ao desenhado no prédio
			var whole: RefCounted = BuildingArt.render(b, style)
			assert_eq(canvas.get_px(2, 2), whole.get_px(rect.position.x + 2, rect.position.y + 2))
	assert_gt(with_sign, 100.0)


func test_glow_gets_stronger_toward_the_center() -> void:
	var glow: RefCounted = LightChunk.glow_canvas()
	assert_almost_eq(glow.get_px(16, 16).a, 1.0)
	assert_gt(glow.get_px(16, 16).a, glow.get_px(16, 5).a)
	assert_gt(glow.get_px(16, 5).a, glow.get_px(16, 1).a)
	assert_almost_eq(glow.get_px(0, 0).a, 0.0)


func test_window_use_by_building_type() -> void:
	assert_eq(LightChunk.window_use("house"), "home")
	assert_eq(LightChunk.window_use("apartment"), "home")
	assert_eq(LightChunk.window_use("office"), "office")
	assert_eq(LightChunk.window_use("bar"), "")
	var house := {"type": "house"}
	var office := {"type": "office"}
	var hotel := {"type": "hotel"}
	for b in [house, office, hotel]:
		assert_false(LightChunk.windows_lit(b, 12.0))
		assert_true(LightChunk.windows_lit(b, 19.0))
	assert_false(LightChunk.windows_lit(house, 1.0), "moradia dorme")
	assert_false(LightChunk.windows_lit(office, 21.0), "escritório apaga às 20:00")
	assert_true(LightChunk.windows_lit(hotel, 1.0))


func test_signs_light_up_when_open_at_night() -> void:
	var bar := {"type": "bar"}
	var bank := {"type": "bank"}
	var club := {"type": "club"}
	assert_false(LightChunk.sign_lit(bar, 12.0), "de dia o neon fica apagado")
	assert_true(LightChunk.sign_lit(bar, 22.0))
	assert_false(LightChunk.sign_lit(bar, 4.0), "bar fechado às 03:00")
	assert_false(LightChunk.sign_lit(bank, 22.0), "banco fechado à noite")
	assert_true(LightChunk.sign_lit(club, 22.0, true))
	assert_false(LightChunk.sign_lit(club, 22.0, false), "o neon da boate pisca")
	assert_true(LightChunk.sign_lit(bar, 22.0, false), "os outros não piscam")
	assert_true(LightChunk.front_lit({"type": "gas_station"}, 23.0), "vitrine do posto 24 h")
	assert_false(LightChunk.front_lit({"type": "armory"}, 23.0), "loja fechada")
	assert_false(LightChunk.front_lit({"type": "hotel"}, 23.0), "hotel não tem vitrine")
	assert_false(LightChunk.front_lit({"type": "gas_station"}, 12.0))


# --- mundo ---

func test_ambient_tint_follows_the_clock() -> void:
	var world := await _start(12.0)
	assert_true(world.ambient is CanvasModulate)
	assert_eq(world.ambient.color, Color.WHITE)
	WorldClock.set_hour(23.0)
	await wait_frames(2)
	assert_eq(world.ambient.color, DayCycle.ambient_color(23.0))
	assert_true(DayCycle.luminance(world.ambient.color) >= DayCycle.MIN_LUMINANCE)
	WorldClock.set_hour(18.5)
	await wait_frames(2)
	assert_eq(world.ambient.color, DayCycle.ambient_color(18.5))


func test_light_layer_is_separate_additive_and_has_no_light2d() -> void:
	var world := await _start(22.0)
	var lights: CanvasLayer = world.lights
	assert_true(lights.follow_viewport_enabled, "a camada de luz acompanha a câmera")
	assert_true(lights.layer > 0 and lights.layer < _player().hud.layer, "acima do mundo, abaixo do HUD")
	assert_eq(lights.chunks.size(), CityLayout.CELLS * CityLayout.CELLS)
	assert_eq(tree.get_nodes_in_group("light_chunks").size(), CityLayout.CELLS * CityLayout.CELLS * 2)
	for block in lights.chunks:
		var pair: Dictionary = lights.chunks[block]
		assert_true(pair["glow"].material is CanvasItemMaterial)
		assert_eq((pair["glow"].material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
		assert_true(pair["emissive"].material == null, "o emissivo é redesenhado sem mistura")
	assert_eq(_count(main, "Light2D"), 0, "brilho aditivo, sem Light2D")
	assert_eq(_count(main, "CanvasModulate"), 1)


func test_every_building_and_lamp_belongs_to_a_light_chunk() -> void:
	var world := await _start(22.0)
	var buildings := 0
	var lamps := 0
	for block in world.lights.chunks:
		var chunk: Node = world.lights.chunks[block]["emissive"]
		buildings += chunk.buildings.size()
		for prop in chunk.props:
			if prop.kind == "lamp":
				lamps += 1
		for b in chunk.buildings:
			assert_eq(CityLayout.DistrictLayout.cell_of((b.rect as Rect2).get_center()), block)
	assert_eq(buildings, world.layout.city.buildings.size())
	assert_gt(lamps, 300.0)


func test_lights_are_off_by_day_and_on_at_night() -> void:
	var world := await _start(12.0)
	for chunk in tree.get_nodes_in_group("light_chunks"):
		assert_false(chunk.visible, "luz acesa ao meio-dia")
	WorldClock.set_hour(22.0)
	await wait_frames(2)
	for chunk in tree.get_nodes_in_group("light_chunks"):
		assert_true(chunk.visible)
		assert_almost_eq(chunk.hour, 22.0, 0.01)
	WorldClock.set_hour(9.0)
	await wait_frames(2)
	for chunk in tree.get_nodes_in_group("light_chunks"):
		assert_false(chunk.visible, "luz acesa às 09:00")
	assert_eq(world.lights.chunks.size(), 144)


func test_lamps_light_from_18_to_0630() -> void:
	var world := await _start(16.0)
	var chunk: Node = world.lights.chunks[Vector2i(3, 3)]["glow"]
	assert_false(chunk.visible)
	WorldClock.set_hour(18.25)
	await wait_frames(2)
	assert_true(chunk.visible, "postes acendem às 18:00")
	WorldClock.set_hour(6.25)
	await wait_frames(2)
	assert_true(chunk.visible)
	WorldClock.set_hour(6.75)
	await wait_frames(2)
	assert_true(not chunk.visible or DayCycle.darkness(6.75) > 0.0)
	assert_false(DayCycle.light_on("lamp", 6.75))


func test_headlights_follow_moving_cars_at_night() -> void:
	var world := await _start(22.0)
	await wait_frames(2)
	var moving := 0
	var parked := 0
	for car in tree.get_nodes_in_group("vehicles"):
		var sprites: Array = world.lights.follower_sprites(car)
		assert_eq(sprites.size(), 2, "farol e lanterna")
		if car.ai_controlled:
			moving += 1
			assert_true(sprites[0].visible and sprites[1].visible)
			assert_true(sprites[0].material is CanvasItemMaterial)
			var ahead: Vector2 = sprites[0].global_position - car.global_position
			assert_gt(ahead.dot(Vector2.RIGHT.rotated(car.global_rotation)), 20.0, "o farol fica à frente do carro")
			var behind: Vector2 = sprites[1].global_position - car.global_position
			assert_true(behind.dot(Vector2.RIGHT.rotated(car.global_rotation)) < -10.0, "a lanterna fica atrás")
		else:
			parked += 1
			assert_false(sprites[0].visible, "carro estacionado fica apagado")
	assert_gt(moving, 0.0)
	assert_gt(parked, 0.0)
	WorldClock.set_hour(12.0)
	await wait_frames(2)
	for sprite in tree.get_nodes_in_group("follow_lights"):
		assert_false(sprite.visible, "farol aceso de dia")


func test_player_has_a_faint_halo_at_night() -> void:
	var world := await _start(23.0)
	await wait_frames(2)
	var sprites: Array = world.lights.follower_sprites(_player())
	assert_eq(sprites.size(), 1)
	assert_true(sprites[0].visible)
	assert_eq(sprites[0].global_position, _player().global_position)
	assert_true(sprites[0].modulate.a < 0.4, "halo fraco")
	WorldClock.set_hour(12.0)
	await wait_frames(2)
	assert_false(sprites[0].visible)


func test_hud_shows_the_clock() -> void:
	await _start(21.5)
	await wait_frames(2)
	assert_eq(_player().hud.clock_text(), "21:30")


# --- interiores ---

func test_interiors_do_not_darken_at_night() -> void:
	WorldClock.set_hour(23.0)
	GameState.set_inside(4, Vector2.ZERO, "", "bar", "Bar de Teste")
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	nodes.append(interior)
	await wait_frames(2)
	assert_eq(_count(interior, "CanvasModulate"), 0, "interior tem iluminação própria")
	assert_eq(_count(interior, "Light2D"), 0)
	assert_eq(tree.get_nodes_in_group("light_chunks").size(), 0)


# --- horário de funcionamento ---

func _door_of(type: String) -> Node:
	var layout := WorldLayout.new()
	for d in tree.get_nodes_in_group("building_doors"):
		if d.building_type == type:
			return d
	return null


func test_closed_building_shows_when_it_opens_and_does_not_let_in() -> void:
	await _start(20.0)
	for n in tree.get_nodes_in_group("npcs") + tree.get_nodes_in_group("traffic"):
		n.queue_free()
	var door := _door_of("bank")
	assert_true(door.is_closed())
	var p := _player()
	assert_true(door.prompt_text(p).contains("Fechado — abre às 09:00"), door.prompt_text(p))
	assert_true(door.prompt_text(p).contains(door.building_name))
	p.global_position = door.return_position
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	assert_true(p.current_prompt().contains("Fechado"), p.current_prompt())
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_false(GameState.is_inside(), "entrou em prédio fechado")
	assert_true(p.hud.toast_text().contains("Fechado"))


func test_doors_open_and_close_with_the_clock() -> void:
	await _start(10.0)
	var bank := _door_of("bank")
	var bar := _door_of("bar")
	var police := _door_of("police")
	var house := _door_of("house")
	assert_false(bank.is_closed())
	assert_true(bar.is_closed(), "bar só abre às 17:00")
	assert_true(bank.prompt_text(_player()).contains("entrar"))
	WorldClock.set_hour(22.0)
	assert_true(bank.is_closed())
	assert_false(bar.is_closed())
	for hour in [3.0, 10.0, 22.0]:
		WorldClock.set_hour(hour)
		assert_false(police.is_closed(), "delegacia 24 h")
		assert_false(house.is_closed())


func test_exit_door_is_never_closed() -> void:
	WorldClock.set_hour(4.0)
	GameState.set_inside(4, Vector2.ZERO, "", "bank", "Banco de Teste")
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	nodes.append(interior)
	await wait_frames(2)
	var exit: Node = tree.get_nodes_in_group("exit_doors")[0]
	assert_false(exit.is_closed(), "sempre dá para sair")


# --- população conforme a hora ---

func test_fewer_pedestrians_and_cars_when_the_world_starts_at_night() -> void:
	var world := await _start(22.0)
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_NIGHT)
	assert_eq(world.active_traffic(), DayCycle.TRAFFIC_NIGHT)
	main.queue_free()
	await wait_frames(3)
	world = await _start(2.0)
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_LATE)
	main.queue_free()
	await wait_frames(3)
	world = await _start(12.0)
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_DAY)
	assert_eq(world.active_traffic(), DayCycle.TRAFFIC_DAY)


func test_at_night_the_surplus_pedestrians_go_home() -> void:
	var world := await _start(12.0)
	WorldClock.set_hour(23.5)
	world.sync_population()
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_LATE)
	var leaving := 0
	for npc in tree.get_nodes_in_group("npcs"):
		if npc.going_home:
			leaving += 1
			assert_true(npc.use_sidewalks, "só pedestres de calçada vão para casa")
			assert_eq(npc.kind, "innocent")
	assert_eq(leaving, DayCycle.CITY_PEDESTRIANS_DAY - DayCycle.CITY_PEDESTRIANS_LATE)
	world.sync_population()
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_LATE, "não manda mais ninguém embora")


func test_npc_going_home_disappears_at_a_home_door() -> void:
	var layout := WorldLayout.new()
	var home: Dictionary = layout.buildings_of(["house", "apartment"], Vector2(3000, 3000))[0]
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 9
	npc.position = home.exit_spawn + Vector2(10, 0)
	tree.root.add_child(npc)
	nodes.append(npc)
	var far := NPC_SCENE.instantiate()
	far.ai_seed = 10
	far.position = home.exit_spawn + Vector2(900, 900)
	far.stationary = true
	tree.root.add_child(far)
	nodes.append(far)
	await wait_physics_frames(3)
	assert_true(is_instance_valid(npc), "sem ir para casa ele fica")
	var doors := PackedVector2Array([home.exit_spawn])
	npc.go_home(doors)
	far.go_home(doors)
	await wait_physics_frames(4)
	await wait_frames(2)
	assert_false(is_instance_valid(npc), "chegou em casa e sumiu")
	assert_true(is_instance_valid(far), "longe de casa continua na rua")
	assert_eq(Score.points, 0, "ir para casa não conta como morte")


func test_in_the_morning_people_come_back_out_of_sight() -> void:
	var world := await _start(2.0)
	var p := _player()
	assert_eq(world.active_pedestrians(), DayCycle.CITY_PEDESTRIANS_LATE)
	WorldClock.set_hour(9.0)
	world.sync_population()
	await wait_frames(1)
	var back: int = world.active_pedestrians()
	assert_gt(back, DayCycle.CITY_PEDESTRIANS_LATE + 40.0)
	assert_true(back <= DayCycle.CITY_PEDESTRIANS_DAY)
	var layout := WorldLayout.new()
	for index in world._npc_nodes:
		if index >= DayCycle.CITY_PEDESTRIANS_LATE:
			var pos: Vector2 = layout.npcs[index].position
			assert_true(pos.distance_to(p.global_position) >= world.OFFSCREEN_DISTANCE, "pedestre surgiu à vista do jogador")
	# os carros também voltam, menos os que nasceriam à vista do jogador
	assert_gt(world.active_traffic(), DayCycle.TRAFFIC_NIGHT + 1.0)
	assert_true(world.active_traffic() <= DayCycle.TRAFFIC_DAY)


func test_night_traffic_leaves_only_out_of_sight() -> void:
	var world := await _start(12.0)
	var p := _player()
	WorldClock.set_hour(22.0)
	# traz um dos carros que deveriam sair para perto do jogador
	var near: Node2D = world._traffic_nodes[DayCycle.TRAFFIC_DAY - 1]
	near.set_physics_process(false)
	near.global_position = p.global_position + Vector2(300, 0)
	world.sync_population()
	await wait_frames(2)
	assert_true(is_instance_valid(near), "carro à vista não some")
	assert_eq(world.active_traffic(), DayCycle.TRAFFIC_NIGHT + 1)
	near.global_position = p.global_position + Vector2(4000, 0)
	world.sync_population()
	await wait_frames(2)
	assert_eq(world.active_traffic(), DayCycle.TRAFFIC_NIGHT)
