extends SceneTree
## Ferramenta de desenvolvimento (Fase 6): capturas do bairro residencial, da casa do agente,
## do mapa com neblina e dos interiores completos em docs/img/.
##
## Uso (com janela, sem --headless):
##   godot --path . -s tools/probe_p6.gd -- <prefixo>
## Gera <prefixo>-residencial, -casa, -mapa, -interior-<tipo> (hospital, police, agent_home, ...).

const MAIN_SCENE := "res://scenes/main.tscn"
const INTERIOR_SCENE := "res://scenes/interior/interior.tscn"
const SHOT_SIZE := Vector2i(1280, 720)
const INTERIORS := ["hospital", "police", "agent_home", "house", "bank", "bar", "hotel", "restaurant",
	"club", "office", "gym", "cinema", "workshop", "warehouse", "hq", "armory"]


func _initialize() -> void:
	_run()


func _save(prefix: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/img/%s-%s.png" % [prefix, shot_name])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "fase6"
	await process_frame
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = SHOT_SIZE
	root.get_window().move_to_center()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))
	var clock: Node = root.get_node("WorldClock")
	var state: Node = root.get_node("GameState")
	clock.set_hour(12.0)
	clock.paused = true

	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	var world: Node = main.get_node("World")
	var player: Node2D = get_nodes_in_group("players")[0]
	var layout = world.layout
	var home: Dictionary = layout.home()

	# um lote de casas
	var houses: Array = []
	for b in layout.city.buildings:
		if b.get("forced", "") == "house":
			houses.append(b)
	var sample: Dictionary = houses[houses.size() / 2]
	player.global_position = sample.exit_spawn + Vector2(0, 120)
	await _frames(40)
	await _save(prefix, "residencial")
	player.global_position = home.exit_spawn
	await _frames(40)
	await _save(prefix, "casa")

	# mapa com neblina: o jogador só explorou o começo e o caminho até a casa
	player.profile.explored.clear()
	for step in 8:
		player.global_position = Vector2(560.0 + step * 560.0, 560.0)
		world.mark_seen_buildings()
	player.global_position = home.exit_spawn
	world.mark_seen_buildings()
	player.toggle_map()
	await _frames(4)
	await _save(prefix, "mapa")
	player.toggle_map()
	await _frames(2)
	main.queue_free()
	await _frames(3)

	# interiores
	var defs := preload("res://scripts/world/building_defs.gd")
	for type in INTERIORS:
		var id := 31
		state.set_inside(id, home.exit_spawn, defs.shop_of(type), type, defs.type_name(type), 280.0)
		var interior: Node = (load(INTERIOR_SCENE) as PackedScene).instantiate()
		root.add_child(interior)
		current_scene = interior
		await _frames(30)
		await _save(prefix, "interior-%s" % type)
		interior.queue_free()
		await _frames(3)
	print("capturas salvas com o prefixo ", prefix)
	quit()
