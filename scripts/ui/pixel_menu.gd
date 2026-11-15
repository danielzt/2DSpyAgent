extends Control
## Menu vertical na fonte pixel (título e pausa). O item escolhido fica âmbar com uma seta.
## Navega com as ações dos jogadores (cima/baixo, interagir) e com o mouse (passar e clicar).
## Funciona com a árvore pausada (process_mode sempre).

const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

signal chosen(index: int)

const ROW := 48.0
const TEXT_SCALE := 3.0
const PAD_X := 24.0
const PLAYERS := [1, 2]

var items: Array[String] = []
var selected := 0
## Desligado, o menu ignora as teclas (usado quando outra tela está por cima).
var active := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_items(list: Array[String]) -> void:
	items = list
	selected = clampi(selected, 0, maxi(items.size() - 1, 0))
	_resize()
	queue_redraw()


func set_item(index: int, text: String) -> void:
	if index >= 0 and index < items.size():
		items[index] = text
		_resize()
		queue_redraw()


func _resize() -> void:
	var widest := 0.0
	for text in items:
		widest = maxf(widest, SpriteFactory.text(text, "white").get_size().x * TEXT_SCALE)
	custom_minimum_size = Vector2(widest + PAD_X * 2.0 + 40.0, ROW * items.size())
	size = custom_minimum_size


func move(step: int) -> void:
	if items.is_empty():
		return
	selected = posmod(selected + step, items.size())
	queue_redraw()


func choose() -> void:
	if not items.is_empty():
		chosen.emit(selected)


func _process(_delta: float) -> void:
	if not active or not is_visible_in_tree():
		return
	for n in PLAYERS:
		var prefix := "p%d_" % n
		if Input.is_action_just_pressed(prefix + "down"):
			move(1)
		elif Input.is_action_just_pressed(prefix + "up"):
			move(-1)
		elif Input.is_action_just_pressed(prefix + "interact"):
			choose()
	if Input.is_action_just_pressed("ui_down"):
		move(1)
	elif Input.is_action_just_pressed("ui_up"):
		move(-1)
	elif Input.is_action_just_pressed("ui_accept"):
		choose()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		var row := int(event.position.y / ROW)
		if row >= 0 and row < items.size() and row != selected:
			selected = row
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var row := int(event.position.y / ROW)
		if row >= 0 and row < items.size():
			selected = row
			choose()


func _draw() -> void:
	for i in items.size():
		var on := i == selected
		var texture := SpriteFactory.text(items[i], "amber" if on else "light", "ink")
		var size_px := Vector2(texture.get_size()) * TEXT_SCALE
		var y := i * ROW + (ROW - size_px.y) / 2.0
		if on:
			var arrow := SpriteFactory.prop("target_arrow")
			var arrow_size := Vector2(arrow.get_size()) * 3.0
			draw_texture_rect(arrow, Rect2(Vector2(0.0, i * ROW + (ROW - arrow_size.y) / 2.0), arrow_size), false)
		draw_texture_rect(texture, Rect2(Vector2(PAD_X + 16.0, y).round(), size_px), false)
