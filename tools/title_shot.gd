extends SceneTree
## Ferramenta de desenvolvimento: abre a tela de título de verdade e salva capturas em docs/img/.
## Uso (com janela, sem --headless): godot --path . -s tools/title_shot.gd -- [prefixo]
## Gera docs/img/<prefixo>-1280.png e docs/img/<prefixo>-1920.png (dois tamanhos de janela).

const TITLE_SCENE := "res://scenes/title/title.tscn"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "titulo"
	_shoot(prefix)


func _shoot(prefix: String) -> void:
	var title: Node = load(TITLE_SCENE).instantiate()
	root.add_child(title)
	for screen in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = screen
		DisplayServer.window_set_size(screen)
		for i in 20:
			await process_frame
		var image := root.get_texture().get_image()
		var path := "res://docs/img/%s-%d.png" % [prefix, screen.x]
		image.save_png(ProjectSettings.globalize_path(path))
		print("captura: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	quit()
