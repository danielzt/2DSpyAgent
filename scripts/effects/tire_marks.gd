extends Node2D
## Marcas de pneu no asfalto: freada e curva forte do carro do jogador. Guarda até
## MAX_MARKS marcas (as mais antigas somem primeiro) e as desenha todas num só nó,
## redesenhando só quando uma marca nova chega.

const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const MAX_MARKS := 200
## Distância mínima entre duas marcas da mesma roda (px).
const SPACING := 10.0
## Transparência da marca mais nova e da mais antiga.
const ALPHA_NEW := 0.7
const ALPHA_OLD := 0.25
const MARK_Z := 1

## Cada marca: {pos: Vector2, rot: float}. Índice 0 = a mais antiga.
var marks: Array[Dictionary] = []

var _last := {}


func _ready() -> void:
	add_to_group("tire_marks")
	z_index = MARK_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Marca de uma roda. `wheel_id` separa as rodas para o espaçamento. Retorna true se criou.
func add_mark(wheel_id: int, pos: Vector2, rot: float) -> bool:
	if _last.has(wheel_id) and (_last[wheel_id] as Vector2).distance_to(pos) < SPACING:
		return false
	_last[wheel_id] = pos
	marks.append({"pos": pos, "rot": rot})
	if marks.size() > MAX_MARKS:
		marks.pop_front()
	queue_redraw()
	return true


## A roda parou de deixar marca (o próximo risco começa sem ligar ao anterior).
func lift(wheel_id: int) -> void:
	_last.erase(wheel_id)


func clear() -> void:
	marks.clear()
	_last.clear()
	queue_redraw()


func _draw() -> void:
	var texture := SpriteFactory.fx("tire")
	var size := Vector2(texture.get_size()) * SpriteFactory.TEXEL
	var ink := Color.WHITE
	for i in marks.size():
		var m: Dictionary = marks[i]
		var age := float(i) / maxf(marks.size() - 1, 1)
		var alpha := lerpf(ALPHA_OLD, ALPHA_NEW, age)
		draw_set_transform(m.pos, m.rot, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-size / 2.0, size), false, Color(ink.r, ink.g, ink.b, alpha))
