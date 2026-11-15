extends Control
## Minimapa do HUD (Fase 5): janela de 1 quarteirão e meio de raio em volta do jogador, com os
## bairros, os prédios e os ícones dos lugares conhecidos. Alvos (pistas de crime, criminosos
## revelados) aparecem como losangos vermelhos, presos à borda quando estão fora da janela.

const MapView := preload("res://scripts/ui/map_view.gd")
const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const SIDE := 200.0
const BORDER := 2.0
const ICON_SCALE := 1.0
const MARKER_SCALE := 1.0
## O desenho é refeito no máximo a cada tanto, ou quando o jogador anda mais que isto.
const REDRAW_INTERVAL := 0.2
const REDRAW_DISTANCE := 6.0

var layout
var known := {}
var center := Vector2.ZERO
var targets: Array = []

var _since_draw := 0.0
var _drawn_center := Vector2(-1.0e9, -1.0e9)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = Vector2(SIDE, SIDE)


## Atualiza o estado; o redesenho é limitado para o minimapa ser barato.
func set_state(p_layout, p_known: Dictionary, p_center: Vector2, p_targets: Array, delta := 0.0) -> void:
	layout = p_layout
	known = p_known
	targets = p_targets
	center = p_center
	_since_draw += delta
	if _since_draw >= REDRAW_INTERVAL or center.distance_to(_drawn_center) >= REDRAW_DISTANCE:
		redraw_now()


func redraw_now() -> void:
	_since_draw = 0.0
	_drawn_center = center
	queue_redraw()


## Janela do mundo mostrada agora.
func view() -> Rect2:
	return MapView.view_around(center)


func _draw() -> void:
	var dest := Rect2(Vector2.ZERO, size)
	if layout == null:
		draw_rect(dest, Palette.get_color("ink"))
		return
	var area := view()
	MapView.draw(self, layout, known, area, dest, ICON_SCALE)
	for target in targets:
		var screen := MapView.to_screen(target, area, dest)
		MapView.draw_glyph(self, "alert", screen.clamp(dest.position + Vector2(6, 6), dest.end - Vector2(6, 6)), MARKER_SCALE, dest)
	MapView.draw_glyph(self, "you", dest.get_center(), MARKER_SCALE, dest)
	var edge := Palette.get_color("neon_cyan")
	draw_rect(dest, edge, false, BORDER)
