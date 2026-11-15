extends RefCounted
## Sprites de carros vistos de cima (26x13 texels, frente para a direita), montados por
## partes (porta-malas, vidros, teto, capô) e pré-girados em 32 direções.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const LENGTH := 26
const WIDTH := 13
const DIRECTIONS := 32
## Lado da tela quadrada de cada direção (cabe o carro em qualquer ângulo, mais sombra).
const FRAME_SIDE := 34
const SHADOW_OFFSET := Vector2i(2, 2)

const MODELS := ["sedan", "hatch", "pickup", "van", "taxi", "police", "agent"]
## Cores de lataria para o trânsito e carros estacionados.
const TONES := ["red", "blue", "green", "yellow", "white", "teal", "purple", "orange", "brown", "gray"]

## Faixas ao longo do comprimento: [início, fim] em texels a partir da traseira.
const PARTS := {
	"sedan": {"rear_glass": [6, 8], "roof": [9, 14], "windshield": [15, 18]},
	"hatch": {"rear_glass": [2, 4], "roof": [5, 13], "windshield": [14, 17]},
	"pickup": {"bed": [2, 9], "rear_glass": [10, 10], "roof": [11, 14], "windshield": [15, 17]},
	"van": {"rear_glass": [1, 2], "roof": [3, 17], "windshield": [18, 21]},
	"taxi": {"rear_glass": [6, 8], "roof": [9, 14], "windshield": [15, 18]},
	"police": {"rear_glass": [6, 8], "roof": [9, 14], "windshield": [15, 18]},
	"agent": {"rear_glass": [4, 6], "roof": [7, 11], "windshield": [12, 15]},
}


## Modelo e cor determinísticos para o carro de índice `index`.
static func variant_for(index: int) -> Dictionary:
	var models := ["sedan", "hatch", "pickup", "van", "sedan", "hatch", "taxi"]
	return {"model": models[index % models.size()], "tone": TONES[(index * 3 + 1) % TONES.size()]}


## Tom efetivo: táxi, viatura e carro da agência têm cor fixa.
static func tone_of(model: String, tone: String) -> String:
	match model:
		"taxi":
			return "yellow"
		"police":
			return "white"
		"agent":
			return "black"
	return tone


## Carro apontando para a direita, sem contorno nem sombra (26x13).
static func base(model: String, tone: String) -> RefCounted:
	var colors: Array[Color] = Palette.tone(tone_of(model, tone))
	var dark := colors[0]
	var mid := colors[1]
	var lit := colors[2]
	var glass := Palette.get_color("navy")
	var shine := Palette.get_color("ice")
	var parts: Dictionary = PARTS[model]
	var c: RefCounted = PixelCanvas.new(LENGTH, WIDTH)

	# Lataria: corpo com cantos chanfrados, luz em cima (noroeste) e sombra embaixo.
	c.rect(1, 1, LENGTH - 2, WIDTH - 2, mid)
	c.rect(1, 1, LENGTH - 2, 2, lit)
	c.rect(1, WIDTH - 3, LENGTH - 2, 2, dark)
	for corner in [Vector2i(1, 1), Vector2i(LENGTH - 2, 1), Vector2i(1, WIDTH - 2), Vector2i(LENGTH - 2, WIDTH - 2)]:
		c.px(corner.x, corner.y, Color(0, 0, 0, 0))

	# Caçamba da picape.
	if parts.has("bed"):
		var bed: Array = parts.bed
		c.rect(bed[0], 3, bed[1] - bed[0] + 1, WIDTH - 6, Palette.get_color("shadow"))
		c.rect(bed[0], 3, bed[1] - bed[0] + 1, 1, Palette.get_color("ink"))

	# Vidros traseiro e dianteiro, e janelas laterais ao longo do teto.
	var roof: Array = parts.roof
	for key in ["rear_glass", "windshield"]:
		var span: Array = parts[key]
		c.rect(span[0], 3, span[1] - span[0] + 1, WIDTH - 6, glass)
	var wind: Array = parts.windshield
	c.px(wind[1], 3, shine)
	c.px(wind[1], 4, shine)
	c.px(wind[1] - 1, 3, shine)
	c.rect(roof[0], 2, roof[1] - roof[0] + 1, 1, glass)
	c.rect(roof[0], WIDTH - 3, roof[1] - roof[0] + 1, 1, glass)
	# Teto.
	c.rect(roof[0], 3, roof[1] - roof[0] + 1, WIDTH - 6, mid)
	c.rect(roof[0], 3, roof[1] - roof[0] + 1, 1, lit)

	# Faróis (frente) e lanternas (traseira).
	for y in [2, 3, WIDTH - 4, WIDTH - 3]:
		c.px(LENGTH - 2, y, Palette.get_color("cream"))
		c.px(1, y, Palette.get_color("red"))
	# Retrovisores.
	c.px(wind[0], 0, mid)
	c.px(wind[0], WIDTH - 1, mid)

	match model:
		"taxi":
			for x in range(2, LENGTH - 2, 2):
				c.px(x, 6, Palette.get_color("ink"))
			c.rect((roof[0] + roof[1]) / 2 - 1, 5, 3, 3, Palette.get_color("white"))
		"police":
			c.rect(wind[1] + 1, 1, LENGTH - 3 - wind[1], WIDTH - 2, Palette.get_color("navy"))
			c.rect(1, 1, parts.rear_glass[0] - 1, WIDTH - 2, Palette.get_color("navy"))
			for y in [2, 3, WIDTH - 4, WIDTH - 3]:
				c.px(LENGTH - 2, y, Palette.get_color("cream"))
				c.px(1, y, Palette.get_color("red"))
			var mid_x: int = (roof[0] + roof[1]) / 2
			c.rect(mid_x, 3, 2, 3, Palette.get_color("red"))
			c.rect(mid_x, 7, 2, 3, Palette.get_color("blue"))
		"agent":
			c.rect(2, 6, LENGTH - 4, 1, Palette.get_color("neon_cyan"))
		"van":
			c.rect(roof[0] + 2, 5, roof[1] - roof[0] - 3, 3, lit)
	return c


## Quadro de uma direção (0 = direita, crescendo no sentido horário): sombra, contorno e carro.
static func frame(model: String, tone: String, direction: int) -> RefCounted:
	var angle := TAU * float(direction) / float(DIRECTIONS)
	var body: RefCounted = base(model, tone).rotated(angle, FRAME_SIDE)
	body.outline(Palette.get_color("ink"))
	var result: RefCounted = PixelCanvas.new(FRAME_SIDE, FRAME_SIDE)
	result.blit(body.silhouette(Palette.cast_shadow()), SHADOW_OFFSET.x, SHADOW_OFFSET.y)
	result.blit(body, 0, 0)
	return result


## Índice da direção pré-gerada mais próxima de um ângulo (rad).
static func direction_index(angle: float) -> int:
	return posmod(roundi(angle / (TAU / DIRECTIONS)), DIRECTIONS)
