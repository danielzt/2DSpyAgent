extends Sprite2D
## Partícula de efeito (faísca, poeira, clarão, cápsula): anda, perde velocidade,
## cresce e some. Vive em um nó do mundo e se remove sozinha.

const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

var velocity := Vector2.ZERO
## Perda de velocidade por segundo (px/s²).
var drag := 0.0
## Segundos de vida restantes e quanto antes do fim ela começa a esmaecer.
var life := 0.5
var fade_time := 0.2
## Crescimento da escala por segundo (poeira que se espalha).
var grow := 0.0
var tint := Color.WHITE


func _ready() -> void:
	add_to_group("fx")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if scale == Vector2.ONE:
		scale = Vector2(SpriteFactory.TEXEL, SpriteFactory.TEXEL)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	if grow != 0.0:
		scale += Vector2.ONE * grow * delta
	var fade := clampf(life / fade_time, 0.0, 1.0) if fade_time > 0.0 else 1.0
	modulate = Color(tint.r, tint.g, tint.b, tint.a * fade)
