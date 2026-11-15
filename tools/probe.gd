extends SceneTree
## Ferramenta de desenvolvimento: abre o jogo de verdade, leva a câmera a pontos fixos,
## salva capturas em docs/img/ e mede o desempenho (vsync desligado).
##
## Uso (com janela, sem --headless):
##   godot --path . -s tools/probe.gd -- <prefixo> [hora]
## Gera docs/img/<prefixo>-<ponto>.png e imprime tempo de quadro, chamadas de desenho e nós.
## `hora` (0-24) só tem efeito quando o relógio do mundo existir.

const MAIN_SCENE := "res://scenes/main.tscn"
const SHOT_SIZE := Vector2i(1280, 720)
const SETTLE_FRAMES := 40
const MEASURE_SECONDS := 4.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "captura"
	var hour: float = float(args[1]) if args.size() > 1 else -1.0

	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main   # para a troca de cena (entrar em prédio) funcionar
	await process_frame
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = SHOT_SIZE
	root.get_window().move_to_center()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var clock := root.get_node_or_null("WorldClock")
	if clock != null and hour >= 0.0:
		clock.set_hour(hour)
		clock.paused = true

	var world: Node = main.get_node("World")
	var player: Node2D = get_nodes_in_group("players")[0]
	var layout = world.layout
	var shop: Dictionary = {}
	for b in layout.city.buildings:
		if b.shop != "":
			shop = b
			break
	var park: Rect2 = layout.city.parks[0]
	var points := {
		"centro": Vector2(560, 560),
		"loja": shop.exit_spawn,
		"parque": Vector2(park.get_center().x, park.end.y + 60.0),
		"borda": Vector2(layout.city.city_size(), 3360),
		"fazenda": layout.country.buildings[3].exit_spawn + Vector2(0, 60),
		"plantacao": (layout.country.fields[0] as Rect2).position + Vector2(200, -80),
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))
	var total_ms := 0.0
	print("ponto;ms_por_quadro;fps;desenhos;nos")
	for point_name in points:
		var pos: Vector2 = points[point_name]
		for i in SETTLE_FRAMES:
			_hold(player, pos)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/img/%s-%s.png" % [prefix, point_name])

		var frames := 0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < int(MEASURE_SECONDS * 1_000_000.0):
			_hold(player, pos)
			await process_frame
			frames += 1
		var ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(frames)
		total_ms += ms
		print("%s;%.3f;%.0f;%d;%d" % [point_name, ms, 1000.0 / ms,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("media;%.3f;%.0f" % [total_ms / points.size(), 1000.0 * points.size() / total_ms])

	# Interior de uma loja (a troca de cena é adiada: espera alguns quadros).
	root.get_node("GameState").go_inside(shop.id, shop.exit_spawn, shop.shop)
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/img/%s-interior.png" % prefix)
	quit()


## Mantém o jogador (e a câmera) parado no ponto, vivo e fora de veículos.
func _hold(player: Node2D, pos: Vector2) -> void:
	player.global_position = pos
	player.health = player.max_health()
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
