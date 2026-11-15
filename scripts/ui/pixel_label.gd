extends Control
## Rótulo do HUD na fonte pixel, com placa retrô atrás e barra opcional (vida).
## O texto vira uma textura só quando muda; o desenho não roda a cada quadro.

const Palette := preload("res://scripts/art/palette.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")

## Tamanho de um texel na tela, em px.
const PIXEL := 2.0
const PAD := Vector2(8.0, 6.0)
const BORDER := 2.0
const PLATE_ALPHA := 0.82
const BAR_HEIGHT := 6.0
const BAR_GAP := 4.0

var text := "":
	set(value):
		if value == text:
			return
		text = value
		_refresh()

## Cor do texto e da borda (nomes da paleta).
var color_name := "white"
var accent_name := "light"
## 0 esquerda, 1 centro, 2 direita (para textos de várias linhas).
var align := 0
## Barra sob o texto: -1 = sem barra; 0 a 1 = fração preenchida.
var bar_ratio := -1.0:
	set(value):
		if is_equal_approx(value, bar_ratio):
			return
		bar_ratio = value
		_refresh()
var bar_color_name := "red"

var _texture: ImageTexture
var _preset := Control.PRESET_TOP_LEFT
var _margin := 16
var _shift := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh()


## Canto da tela em que o rótulo fica, margem e deslocamento extra.
func place(preset: Control.LayoutPreset, margin := 16, shift := Vector2.ZERO) -> void:
	_preset = preset
	_margin = margin
	_shift = shift
	_apply_layout()


## Tamanho da placa para o texto atual.
func plate_size() -> Vector2:
	if text == "":
		return Vector2.ZERO
	var size := Vector2(PixelFont.measure(text)) * PIXEL + PAD * 2.0
	if bar_ratio >= 0.0:
		size.y += BAR_HEIGHT + BAR_GAP
	return size


func _refresh() -> void:
	if text == "":
		_texture = null
	else:
		_texture = PixelFont.render(text, Palette.get_color(color_name), Color(0, 0, 0, 0), 0, align).to_texture()
	custom_minimum_size = plate_size()
	if is_inside_tree():
		_apply_layout()
	queue_redraw()


## Posiciona a placa a partir do canto escolhido. As margens são calculadas aqui (e não
## pelo preset do Control) porque o tamanho mínimo só é atualizado no quadro seguinte.
func _apply_layout() -> void:
	set_anchors_preset(_preset)
	var plate := plate_size()
	var m := float(_margin)
	var origin := Vector2(m, m)
	match _preset:
		Control.PRESET_TOP_RIGHT:
			origin = Vector2(-plate.x - m, m)
		Control.PRESET_BOTTOM_LEFT:
			origin = Vector2(m, -plate.y - m)
		Control.PRESET_BOTTOM_RIGHT:
			origin = Vector2(-plate.x - m, -plate.y - m)
		Control.PRESET_CENTER_TOP:
			origin = Vector2(-plate.x / 2.0, m)
		Control.PRESET_CENTER_BOTTOM:
			origin = Vector2(-plate.x / 2.0, -plate.y - m)
	origin = (origin + _shift).round()
	offset_left = origin.x
	offset_top = origin.y
	offset_right = origin.x + plate.x
	offset_bottom = origin.y + plate.y


func _draw() -> void:
	if _texture == null:
		return
	var plate := plate_size()
	var ink := Palette.get_color("ink")
	var accent := Palette.get_color(accent_name)
	# Placa com cantos chanfrados: a borda não cobre os cantos.
	draw_rect(Rect2(BORDER, BORDER, plate.x - BORDER * 2.0, plate.y - BORDER * 2.0), Color(ink.r, ink.g, ink.b, PLATE_ALPHA))
	draw_rect(Rect2(BORDER, 0.0, plate.x - BORDER * 2.0, BORDER), accent)
	draw_rect(Rect2(BORDER, plate.y - BORDER, plate.x - BORDER * 2.0, BORDER), accent)
	draw_rect(Rect2(0.0, BORDER, BORDER, plate.y - BORDER * 2.0), accent)
	draw_rect(Rect2(plate.x - BORDER, BORDER, BORDER, plate.y - BORDER * 2.0), accent)
	var text_size := Vector2(_texture.get_size()) * PIXEL
	draw_texture_rect(_texture, Rect2(PAD, text_size), false)
	if bar_ratio >= 0.0:
		var bar := Rect2(PAD.x, PAD.y + text_size.y + BAR_GAP, plate.x - PAD.x * 2.0, BAR_HEIGHT)
		draw_rect(bar, Palette.get_color("shadow"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(bar_ratio, 0.0, 1.0), bar.size.y)), Palette.get_color(bar_color_name))
