extends RefCounted
## Sprites de personagens (12x16 texels) escritos como texto e recoloridos por legenda.
## Direções: "down", "up", "right", "left" (espelho de "right").
## Quadros: 0 = parado, 1 e 2 = passos.
##
## Letras trocáveis: 1 roupa, 2 sombra/detalhe da roupa, 3 calça, 4 cabelo, 5 boné/gorro,
## f pele. As demais vêm da legenda padrão da paleta.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const WIDTH := 12
const HEIGHT := 16
## Tela final: sprite + anel (jogador) + sombra no chão.
const CANVAS := Vector2i(16, 20)
const ORIGIN := Vector2i(2, 1)
## Ponto da tela que coincide com o centro da colisão do personagem.
const PIVOT := Vector2i(8, 11)
const DIRECTIONS := ["down", "up", "right", "left"]
const FRAMES := 3

const FRONT := [
	"....kkkk....",
	"...k4444k...",
	"..k444444k..",
	"..k4ffff4k..",
	"..kfkffkfk..",
	"..kffffffk..",
	"...kffffk...",
	"..k111111k..",
	".k11111111k.",
	"kf11111111fk",
	"kf12111121fk",
	".k11111111k.",
	"..k333333k..",
	"..k33kk33k..",
	"..k33kk33k..",
	"..kkk..kkk..",
]
const BACK := [
	"....kkkk....",
	"...k4444k...",
	"..k444444k..",
	"..k444444k..",
	"..k444444k..",
	"..k444444k..",
	"...k4ff4k...",
	"..k111111k..",
	".k11111111k.",
	"kf11111111fk",
	"kf11211211fk",
	".k11111111k.",
	"..k333333k..",
	"..k33kk33k..",
	"..k33kk33k..",
	"..kkk..kkk..",
]
const SIDE := [
	"....kkkk....",
	"...k4444k...",
	"..k44444fk..",
	"..k444fffk..",
	"..k44ffkfk..",
	"..k4fffffk..",
	"...kffffk...",
	"...k1111k...",
	"..k111111k..",
	"..k11f111k..",
	"..k11f211k..",
	"..k111111k..",
	"...k3333k...",
	"...k3333k...",
	"...k33k3k...",
	"...kkkkkk...",
]
## Pernas (últimas 4 fileiras) no passo, de frente e de costas.
const STEP_LEGS := [
	"..k333333k..",
	"..k33kk33k..",
	"..k33k.kkk..",
	"..kkk.......",
]
## Pernas no passo, de lado (abertas).
const SIDE_STEP_LEGS := [
	"...k3333k...",
	"..k33kk33k..",
	".k33k..k33k.",
	".kkk....kkk.",
]

const SKINS := ["skin_light", "skin_dark"]
const HAIRS := ["brown_dark", "amber", "shadow", "orange", "gray"]
const HAIR_STYLES := ["short", "long", "cap", "bald"]
const SHIRTS := ["red", "blue", "green", "yellow", "white", "teal", "purple", "orange", "pink", "brown"]
const PANTS := ["navy", "brown", "slate", "shadow"]
const CAPS := ["red", "blue", "white", "green_dark"]


## Aparência do agente (jogador N): terno escuro, gravata e óculos escuros.
static func agent_look(player_index: int = 1) -> Dictionary:
	return {
		"kind": "agent", "skin": "skin_light", "hair": "brown_dark", "hair_style": "short",
		"shirt": "navy", "shirt2": "ink", "pants": "navy", "cap": "",
		"ring": "blue" if player_index == 1 else "orange",
	}


## Aparência de um civil, determinística pela seed.
static func civilian_look(p_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 7919 + 17
	var tone: String = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	return {
		"kind": "innocent",
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"hair": HAIRS[rng.randi_range(0, HAIRS.size() - 1)],
		"hair_style": HAIR_STYLES[rng.randi_range(0, HAIR_STYLES.size() - 1)],
		"shirt": Palette.TONES[tone][1], "shirt2": Palette.TONES[tone][0],
		"pants": PANTS[rng.randi_range(0, PANTS.size() - 1)],
		"cap": CAPS[rng.randi_range(0, CAPS.size() - 1)],
		"ring": "",
	}


## Aparência de um criminoso: gorro, máscara e camisa listrada.
static func criminal_look(p_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 7919 + 31
	return {
		"kind": "criminal",
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"hair": "ink", "hair_style": "cap",
		"shirt": "red", "shirt2": "ink", "pants": "shadow", "cap": "shadow", "ring": "",
	}


static func look_for(kind: String, p_seed: int) -> Dictionary:
	return criminal_look(p_seed) if kind == "criminal" else civilian_look(p_seed)


## Chave de cache: muda só quando a aparência muda.
static func look_key(look: Dictionary) -> String:
	return "%s/%s/%s/%s/%s/%s/%s/%s/%s" % [look.kind, look.skin, look.hair, look.hair_style,
		look.shirt, look.shirt2, look.pants, look.cap, look.ring]


## Fileiras (texto) do personagem na direção e no quadro pedidos, sem espelhar.
static func rows_for(look: Dictionary, direction: String, frame: int) -> Array:
	var rows: Array = []
	match direction:
		"up":
			rows = BACK.duplicate()
		"right", "left":
			rows = SIDE.duplicate()
		_:
			rows = FRONT.duplicate()
	var side := direction == "right" or direction == "left"
	_apply_head(rows, look, direction)
	_apply_body(rows, look, direction)
	if frame > 0:
		var legs: Array = SIDE_STEP_LEGS if side else STEP_LEGS
		if not side or frame == 1:
			for i in 4:
				rows[12 + i] = legs[i]
	return rows


static func _apply_head(rows: Array, look: Dictionary, direction: String) -> void:
	var style: String = look.hair_style
	if direction == "down":
		match style:
			"long":
				rows[4] = "..k4kffk4k.."
				rows[5] = "..k4ffff4k.."
				rows[6] = "...k4ff4k..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555k.."
				rows[3] = "..k555555k.."
			"bald":
				rows[1] = "...kffffk..."
				rows[2] = "..kffffffk.."
				rows[3] = "..kffffffk.."
		if look.kind == "agent":
			rows[4] = "..kkkkkkkk.."   # óculos escuros
		elif look.kind == "criminal":
			rows[3] = "..k555555k.."
			rows[4] = "..kkwkkwkk.."   # máscara
	elif direction == "up":
		match style:
			"long":
				rows[6] = "...k4444k..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555k.."
				rows[3] = "..k555555k.."
			"bald":
				for i in range(1, 6):
					rows[i] = (rows[i] as String).replace("4", "f")
	else:
		match style:
			"long":
				rows[5] = "..k44ffffk.."
				rows[6] = "...k4fffk..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555kk."
				rows[3] = "..k55ffffk.."
			"bald":
				for i in range(1, 6):
					rows[i] = (rows[i] as String).replace("4", "f")
		if look.kind == "agent":
			rows[4] = "..k44fkkkk.."
		elif look.kind == "criminal":
			rows[3] = "..k555555k.."
			rows[4] = "..k55kkwkk.."


static func _apply_body(rows: Array, look: Dictionary, direction: String) -> void:
	if look.kind == "agent" and direction == "down":
		rows[7] = "..k11ww11k.."     # colarinho
		rows[8] = ".k111rr111k."     # gravata
		rows[9] = "kf111rr111fk"
		rows[10] = "kf11111111fk"
	elif look.kind == "criminal":
		# listras horizontais
		if direction == "right" or direction == "left":
			rows[8] = "..k222222k.."
			rows[10] = "..k22f222k.."
		else:
			rows[8] = ".k22222222k."
			rows[10] = "kf22222222fk"


## Legenda (letra -> cor) da aparência.
static func legend_for(look: Dictionary) -> Dictionary:
	return Palette.legend({
		"1": look.shirt, "2": look.shirt2, "3": look.pants, "4": look.hair,
		"5": look.cap if look.cap != "" else look.hair, "f": look.skin,
	})


## Só o personagem (12x16), sem sombra nem anel.
static func body(look: Dictionary, direction: String, frame: int) -> RefCounted:
	var canvas: RefCounted = PixelCanvas.new(WIDTH, HEIGHT)
	canvas.stamp(rows_for(look, direction, frame), legend_for(look))
	if direction == "left" or (frame == 2 and direction != "right"):
		return canvas.flipped_h()
	return canvas


## Quadro completo (16x20): sombra no chão, anel do jogador e o personagem.
static func build(look: Dictionary, direction: String, frame: int) -> RefCounted:
	var canvas: RefCounted = PixelCanvas.new(CANVAS.x, CANVAS.y)
	if look.ring != "":
		canvas.ellipse(1, 13, 14, 6, Palette.get_color(look.ring))
		canvas.ellipse(3, 14, 10, 4, Color(0, 0, 0, 0))
	canvas.ellipse(3, 15, 10, 3, Palette.cast_shadow())
	canvas.blit(body(look, direction, frame), ORIGIN.x, ORIGIN.y)
	return canvas


## Direção de sprite mais próxima de um vetor.
static func direction_of(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "down"
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"
