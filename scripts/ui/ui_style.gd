extends RefCounted
## Estilo retrô compartilhado pelos painéis (inventário, ficha, loja, card de conversa):
## fundo escuro, borda dupla em cores da paleta e cantos retos.

const Palette := preload("res://scripts/art/palette.gd")

const BORDER := 4
const PANEL_ALPHA := 0.94


## Caixa de painel: fundo tinta, borda ciano e sombra dura.
static func panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var ink := Palette.get_color("ink")
	box.bg_color = Color(ink.r, ink.g, ink.b, PANEL_ALPHA)
	box.border_color = Palette.get_color("neon_cyan")
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.shadow_color = Palette.get_color("ink")
	box.shadow_size = 0
	box.shadow_offset = Vector2(6, 6)
	box.set_content_margin_all(BORDER)
	return box
