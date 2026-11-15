extends CanvasLayer
## Tela de pausa (Esc): congela o jogo e mostra o mapa, os controles e um menu pequeno
## (continuar, tremor de câmera, voltar ao título). Fica acima do HUD e dos painéis.

const MapView := preload("res://scripts/ui/map_view.gd")
const PixelMenu := preload("res://scripts/ui/pixel_menu.gd")
const ControlsText := preload("res://scripts/ui/controls_text.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")

signal closed

const RESUME := 0
const SHAKE := 1
const TITLE := 2

const MARGIN := 40.0
const MAP_SIZE := Vector2(620.0, 330.0)
const COLUMN_GAP := 48.0
const CONTROLS_WIDTH := 500.0
const LINE_HEIGHT := 28.0

var player_index := 1
var layout
var known := {}
var player_position := Vector2.ZERO

var _is_open := false
var _canvas: Control
var _menu: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_screen)
	_canvas.resized.connect(_place_menu)
	add_child(_canvas)
	_menu = PixelMenu.new()
	_canvas.add_child(_menu)
	_menu.chosen.connect(_on_chosen)
	_refresh_items()
	visible = false


func _refresh_items() -> void:
	var items: Array[String] = ["Continuar", "Tremor de câmera: %s" % ("SIM" if GameState.screen_shake else "NÃO"), "Voltar ao título"]
	_menu.set_items(items)


## Posição do bloco: centralizado na tela, mapa à esquerda e controles à direita.
func _origin() -> Vector2:
	var total := MAP_SIZE.x + COLUMN_GAP + CONTROLS_WIDTH
	return Vector2(maxf((_canvas.size.x - total) / 2.0, MARGIN), 130.0)


func map_rect() -> Rect2:
	var origin := _origin()
	if layout == null:
		return Rect2(origin, MAP_SIZE)
	return MapView.fit(MapView.world_rect(layout), Rect2(origin, MAP_SIZE))


func _place_menu() -> void:
	if _menu != null and _canvas != null:
		_menu.position = _origin() + Vector2(0.0, MAP_SIZE.y + 36.0)


func open(p_layout, p_known: Dictionary, p_position: Vector2, p_player_index := 1) -> void:
	layout = p_layout
	known = p_known
	player_position = p_position
	player_index = p_player_index
	_refresh_items()
	_menu.selected = RESUME
	_is_open = true
	visible = true
	_place_menu()
	get_tree().paused = true
	_canvas.queue_redraw()


## Fecha a pausa. O jogo só volta depois de dois quadros, para a tecla que fechou a pausa
## não ser lida também como uma ação do jogador.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _is_open:
		get_tree().paused = false


func is_open() -> bool:
	return _is_open


func menu() -> Control:
	return _menu


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("p%d_pause" % player_index):
		get_viewport().set_input_as_handled()
		close()


func _on_chosen(index: int) -> void:
	match index:
		RESUME:
			close()
		SHAKE:
			GameState.screen_shake = not GameState.screen_shake
			_refresh_items()
			_canvas.queue_redraw()
		TITLE:
			_is_open = false
			visible = false
			get_tree().paused = false
			GameState.go_to_title()


func _text(content: String, color_name: String, pos: Vector2, text_scale := 2.0) -> void:
	var texture := SpriteFactory.text(content, color_name, "ink", 0)
	_canvas.draw_texture_rect(texture, Rect2(pos.round(), Vector2(texture.get_size()) * text_scale), false)


func _draw_screen() -> void:
	var ink := Palette.get_color("ink")
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(ink.r, ink.g, ink.b, 0.9))
	var title := SpriteFactory.text("PAUSA", "neon_cyan", "navy", 0)
	var title_size := Vector2(title.get_size()) * 6.0
	_canvas.draw_texture_rect(title, Rect2(Vector2((_canvas.size.x - title_size.x) / 2.0, 40.0).round(), title_size), false)
	var origin := _origin()
	# mapa
	if layout != null:
		var dest := map_rect()
		MapView.draw(_canvas, layout, known, MapView.world_rect(layout), dest, 1.0)
		MapView.draw_glyph(_canvas, "you", MapView.to_screen(player_position, MapView.world_rect(layout), dest), 1.5, dest.grow(20.0))
		_canvas.draw_rect(dest.grow(2.0), Palette.get_color("neon_cyan"), false, 2.0)
	# controles
	var x := origin.x + MAP_SIZE.x + COLUMN_GAP
	_text("CONTROLES", "amber", Vector2(x, origin.y), 3.0)
	var y := origin.y + 40.0
	for pair in ControlsText.lines(player_index):
		_text(pair[0], "light", Vector2(x, y))
		var keys := SpriteFactory.text(pair[1], "neon_cyan", "ink", 2)
		var keys_size := Vector2(keys.get_size()) * 2.0
		_canvas.draw_texture_rect(keys, Rect2(Vector2(x + CONTROLS_WIDTH - keys_size.x, y).round(), keys_size), false)
		y += LINE_HEIGHT
