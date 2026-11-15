extends SceneTree
## Ferramenta de desenvolvimento (Fase 5): captura as telas e os efeitos novos em docs/img/.
##
## Uso (com janela, sem --headless):
##   godot --path . -s tools/probe_ui.gd -- <prefixo>
## Gera <prefixo>-titulo, -controles, -tiro, -faiscas, -pneus, -iris, -minimapa, -mapa e -pausa.
## O mapa e o minimapa mostram os prédios que o jogador "viu" ao percorrer a avenida.

const TITLE_SCENE := "res://scenes/title/title.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const SHOT_SIZE := Vector2i(1280, 720)
const Fx := preload("res://scripts/effects/fx.gd")


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
	var prefix: String = args[0] if args.size() > 0 else "fase5"
	await process_frame
	root.get_window().mode = Window.MODE_WINDOWED
	root.get_window().size = SHOT_SIZE
	root.get_window().move_to_center()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))

	# Título e controles
	var title: Node = (load(TITLE_SCENE) as PackedScene).instantiate()
	root.add_child(title)
	await _frames(6)
	await _save(prefix, "titulo")
	title._set_controls(true)
	await _frames(3)
	await _save(prefix, "controles")
	title.queue_free()
	await _frames(2)

	# Jogo, à noite
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	var world: Node = main.get_node("World")
	var player: Node2D = get_nodes_in_group("players")[0]
	var clock: Node = root.get_node("WorldClock")
	clock.set_hour(21.0)
	clock.paused = true
	var layout = world.layout
	var line: float = layout.city.AVENUE_LINE * layout.city.BLOCK
	# percorre a avenida para "ver" prédios (é o que enche o mapa)
	for step in 12:
		player.global_position = Vector2(300.0 + step * 560.0, line + 300.0)
		world.mark_seen_buildings()
	for step in 8:
		player.global_position = Vector2(line + 300.0, 300.0 + step * 560.0)
		world.mark_seen_buildings()
	player.global_position = Vector2(line + 600.0, line + 300.0)
	await _frames(40)

	# Tiro: clarão, cápsula e tremor da escopeta
	player.aim_at(player.global_position + Vector2(200, 0))
	player.fire_hand("left")
	await _frames(1)
	await _save(prefix, "tiro")
	await _frames(20)
	Fx.sparks(world, player.global_position + Vector2(90, -10), Vector2.RIGHT)
	Fx.ground_hit(world, player.global_position + Vector2(-80, 40))
	await _frames(2)
	await _save(prefix, "faiscas")

	# Marcas de pneu em arco
	var marks: Node2D = world.tire_marks
	for i in 60:
		var a := -PI / 2.0 + i * 0.026
		var center := player.global_position + Vector2(-260, 260)
		for side in [-9.0, 9.0]:
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * (260.0 + side)
			marks.add_mark(int(side), p, a + PI / 2.0)
	clock.set_hour(12.0)  # de dia a marca aparece melhor
	await _frames(25)
	await _save(prefix, "pneus")
	clock.set_hour(21.0)
	await _frames(25)

	# Íris (meio fechada)
	var iris: Node = root.get_node("Transition")
	iris.set_ratio(0.45)
	await _frames(2)
	await _save(prefix, "iris")
	iris.set_ratio(1.0)

	# HUD com minimapa e mapa de tela cheia
	await _frames(20)
	await _save(prefix, "minimapa")
	player.toggle_map()
	await _frames(4)
	await _save(prefix, "mapa")
	player.toggle_map()
	await _frames(2)

	# Pausa
	player.pause()
	await _frames(4)
	await _save(prefix, "pausa")
	player.pause_panel.close()
	await _frames(4)
	print("capturas salvas com o prefixo ", prefix)
	quit()
