extends Node
## Ajusta a janela à tela do jogador e alterna tela cheia com F11.
## O conteúdo se adapta a qualquer proporção (stretch "expand" no project.godot).

const WINDOW_FRACTION := 0.85
const MIN_SIZE := Vector2i(640, 360)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	var screen := DisplayServer.screen_get_usable_rect().size
	win.min_size = MIN_SIZE
	win.size = fit_size(screen)
	win.move_to_center()


## Tamanho da janela: uma fração da área útil da tela, nunca menor que o mínimo.
static func fit_size(screen: Vector2i, fraction := WINDOW_FRACTION) -> Vector2i:
	return Vector2i(
		maxi(int(screen.x * fraction), MIN_SIZE.x),
		maxi(int(screen.y * fraction), MIN_SIZE.y))


## Alterna entre janela e tela cheia.
static func next_mode(mode: int) -> int:
	if mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return Window.MODE_WINDOWED
	return Window.MODE_FULLSCREEN


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var win := get_window()
		win.mode = next_mode(win.mode)
		get_viewport().set_input_as_handled()
