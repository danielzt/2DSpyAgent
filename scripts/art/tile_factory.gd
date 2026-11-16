extends RefCounted
## Tiles de chão, telhado e parede, repetíveis, gerados por código e guardados em cache.
## Cada tile tem 32x32 texels (64 px do mundo), salvo os de marcação de rua.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const SIZE := 32
const IDS := [
	"asphalt", "sidewalk", "concrete", "grass", "dirt", "field", "field_green", "water",
	"roof/slab", "roof/slab_light", "roof/tar", "roof/tile", "roof/tile_red", "roof/tile_brown", "roof/zinc",
	"wall/brick", "wall/wood", "floor/wood", "floor/tile",
	"floor/carpet", "floor/checker", "floor/concrete", "floor/dance", "floor/marble",
	"floor/herringbone", "floor/wood_dark", "floor/laminate", "floor/carpet_navy", "floor/carpet_cream",
	"floor/linoleum_mint", "floor/linoleum_gray", "floor/linoleum_white", "floor/bath_tile",
	"dash_v", "dash_h", "dash_lane_v", "dash_lane_h", "cross_h", "cross_v",
]

## Faces de parede dos interiores (16x12 texels, repetidas na horizontal): estilo -> desenho.
const FACE_SIZE := Vector2i(16, 12)
const FACE_STYLES := ["stripes_wine", "wood_panel", "tile_blue", "tile_white_green", "navy_half", "brick",
	"floral", "plaster_cream", "plaster_gray"]

static var _canvases := {}
static var _textures := {}
static var _faces := {}


static func has_tile(id: String) -> bool:
	return IDS.has(id) or (id.begins_with("wall/") and Palette.TONES.has(id.trim_prefix("wall/")))


## Tela do tile (gerada uma vez).
static func canvas(id: String) -> RefCounted:
	if not _canvases.has(id):
		_canvases[id] = _build(id)
	return _canvases[id]


## Textura do tile (gerada uma vez).
static func texture(id: String) -> ImageTexture:
	if not _textures.has(id):
		_textures[id] = canvas(id).to_texture()
	return _textures[id]


static func cached_count() -> int:
	return _textures.size()


static func _c(color_name: String) -> Color:
	return Palette.get_color(color_name)


static func _build(id: String) -> RefCounted:
	var seed_value := hash(id)
	match id:
		"asphalt":
			var t := _filled("asphalt")
			t.speckle(_c("asphalt_light"), 0.022, seed_value)
			t.speckle(_c("ink"), 0.005, seed_value + 1)
			return t
		"sidewalk":
			var t := _filled("light")
			t.speckle(_c("white"), 0.03, seed_value)
			for i in range(0, SIZE, 8):
				t.hline(0, i, SIZE, _c("gray"))
				t.vline(i, 0, SIZE, _c("gray"))
			return t
		"concrete":
			var t := _filled("concrete")
			t.speckle(_c("cream"), 0.02, seed_value)
			t.speckle(_c("gray"), 0.008, seed_value + 1)
			for i in range(0, SIZE, 16):
				t.hline(0, i, SIZE, _c("gray"))
				t.vline(i, 0, SIZE, _c("gray"))
			return t
		"grass":
			var t := _filled("green")
			t.speckle(_c("green_dark"), 0.015, seed_value)
			_tufts(t, _c("lime"), 9, seed_value + 1)
			return t
		"dirt":
			var t := _filled("sand")
			t.speckle(_c("brown"), 0.05, seed_value)
			t.speckle(_c("cream"), 0.04, seed_value + 1)
			return t
		"field":
			var t := _filled("amber")
			t.speckle(_c("cream"), 0.08, seed_value)
			for y in range(3, SIZE, 4):
				t.hline(0, y, SIZE, _c("sand"))
			return t
		"field_green":
			var t := _filled("brown")
			for y in range(0, SIZE, 4):
				t.hline(0, y, SIZE, _c("green"))
				for x in range((y / 4) % 2, SIZE, 2):
					t.px(x, y + 1, _c("lime"))
			return t
		"water":
			var t := _filled("blue")
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			for i in 16:
				t.hline(rng.randi_range(0, SIZE - 4), rng.randi_range(0, SIZE - 1), 3, _c("sky"))
			for i in 6:
				t.hline(rng.randi_range(0, SIZE - 3), rng.randi_range(0, SIZE - 1), 2, _c("navy"))
			return t
		"roof/slab":
			var t := _filled("slate")
			t.speckle(_c("gray"), 0.015, seed_value)
			t.speckle(_c("shadow"), 0.015, seed_value + 1)
			return t
		"roof/slab_light":
			var t := _filled("gray")
			t.speckle(_c("light"), 0.02, seed_value)
			t.speckle(_c("slate"), 0.012, seed_value + 1)
			return t
		"roof/tar":
			var t := _filled("shadow")
			t.speckle(_c("slate"), 0.02, seed_value)
			t.speckle(_c("ink"), 0.012, seed_value + 1)
			return t
		"roof/tile":
			return _roof_tiles("orange", "wine", "amber")
		"roof/tile_red":
			return _roof_tiles("red", "wine", "pink")
		"roof/tile_brown":
			return _roof_tiles("brown", "brown_dark", "sand")
		"roof/zinc":
			var t := _filled("gray")
			for x in range(0, SIZE, 4):
				t.vline(x, 0, SIZE, _c("light"))
			return t
		"wall/brick":
			var t := _filled("red")
			for y in range(0, SIZE, 4):
				t.hline(0, y + 3, SIZE, _c("wine"))
				for x in range(((y / 4) % 2) * 4, SIZE, 8):
					t.vline(x, y, 3, _c("wine"))
			t.speckle(_c("skin_dark"), 0.03, seed_value)
			return t
		"wall/wood":
			var t := _filled("brown")
			for x in range(5, SIZE, 6):
				t.vline(x, 0, SIZE, _c("brown_dark"))
			t.speckle(_c("sand"), 0.03, seed_value)
			return t
		"floor/wood":
			var t := _filled("sand")
			for y in range(7, SIZE, 8):
				t.hline(0, y, SIZE, _c("brown"))
			for y in range(0, SIZE, 8):
				for x in range(((y / 8) % 2) * 8 + 3, SIZE, 16):
					t.vline(x, y, 7, _c("brown"))
			t.speckle(_c("cream"), 0.03, seed_value)
			return t
		"floor/tile":
			var t := _filled("cream")
			for i in range(0, SIZE, 8):
				t.hline(0, i, SIZE, _c("concrete"))
				t.vline(i, 0, SIZE, _c("concrete"))
			return t
		"floor/carpet":
			var t := _filled("wine")
			for y in range(0, SIZE, 8):
				for x in range(((y / 8) % 2) * 4, SIZE, 8):
					t.px(x, y, _c("red"))
					t.px(x + 1, y + 1, _c("red"))
			return t
		"floor/checker":
			var t := _filled("cream")
			for y in range(0, SIZE, 8):
				for x in range(((y / 8) % 2) * 8, SIZE, 16):
					t.rect(x, y, 8, 8, _c("red"))
			return t
		"floor/concrete":
			var t := _filled("gray")
			t.speckle(_c("slate"), 0.03, seed_value)
			t.speckle(_c("light"), 0.02, seed_value + 1)
			t.hline(0, 0, SIZE, _c("slate"))
			t.vline(0, 0, SIZE, _c("slate"))
			return t
		"floor/dance":
			var t := _filled("shadow")
			var lights := ["magenta", "purple", "neon_cyan", "blue"]
			for y in range(0, SIZE, 8):
				for x in range(0, SIZE, 8):
					t.rect(x + 1, y + 1, 6, 6, _c(lights[((x / 8) * 3 + (y / 8) * 5) % lights.size()]))
			return t
		"floor/marble":
			var t := _filled("light")
			t.speckle(_c("white"), 0.06, seed_value)
			t.speckle(_c("gray"), 0.012, seed_value + 1)
			for i in range(0, SIZE, 16):
				t.hline(0, i, SIZE, _c("gray"))
				t.vline(i, 0, SIZE, _c("gray"))
			return t
		"floor/herringbone":
			# tacos em blocos de 8 texels, alternando tábuas deitadas e em pé
			var t := _filled("sand")
			for by in range(0, SIZE, 8):
				for bx in range(0, SIZE, 8):
					if ((bx + by) / 8) % 2 == 0:
						t.hline(bx, by + 3, 8, _c("brown"))
						t.hline(bx, by + 7, 8, _c("brown"))
					else:
						t.vline(bx + 3, by, 8, _c("brown"))
						t.vline(bx + 7, by, 8, _c("brown"))
			t.speckle(_c("cream"), 0.03, seed_value)
			return t
		"floor/wood_dark":
			# tábuas compridas (8 texels) com emendas espaçadas e veios discretos
			var t := _filled("brown")
			for y in range(7, SIZE, 8):
				t.hline(0, y, SIZE, _c("brown_dark"))
			for y in range(0, SIZE, 8):
				t.vline(((y / 8) * 13 + 5) % SIZE, y, 7, _c("brown_dark"))
				t.hline(((y / 8) * 7 + 3) % SIZE, y + 3, 6, _c("skin_dark"))
			return t
		"floor/laminate":
			var t := _filled("cream")
			for y in range(7, SIZE, 8):
				t.hline(0, y, SIZE, _c("sand"))
			for y in range(0, SIZE, 8):
				t.vline(((y / 8) * 11) % SIZE, y, 7, _c("sand"))
			t.speckle(_c("white"), 0.02, seed_value)
			return t
		"floor/carpet_navy":
			var t := _filled("navy")
			for y in range(0, SIZE, 8):
				for x in range(((y / 8) % 2) * 4, SIZE, 8):
					t.px(x + 2, y + 1, _c("blue"))
					t.px(x + 1, y + 2, _c("blue"))
					t.px(x + 3, y + 2, _c("blue"))
					t.px(x + 2, y + 3, _c("blue"))
			t.speckle(_c("shadow"), 0.04, seed_value)
			return t
		"floor/carpet_cream":
			var t := _filled("cream")
			for y in range(0, SIZE, 4):
				for x in range(((y / 4) % 2) * 2, SIZE, 4):
					t.px(x, y, _c("white"))
			t.speckle(_c("sand"), 0.015, seed_value)
			return t
		"floor/linoleum_mint":
			var t := _filled("ice")
			t.speckle(_c("teal"), 0.02, seed_value)
			t.speckle(_c("white"), 0.04, seed_value + 1)
			for i in range(0, SIZE, 16):
				t.hline(0, i, SIZE, _c("sky"))
				t.vline(i, 0, SIZE, _c("sky"))
			return t
		"floor/linoleum_gray":
			var t := _filled("light")
			t.speckle(_c("gray"), 0.05, seed_value)
			t.speckle(_c("white"), 0.03, seed_value + 1)
			for i in range(0, SIZE, 16):
				t.hline(0, i, SIZE, _c("gray"))
				t.vline(i, 0, SIZE, _c("gray"))
			return t
		"floor/linoleum_white":
			var t := _filled("white")
			t.speckle(_c("light"), 0.06, seed_value)
			t.speckle(_c("ice"), 0.02, seed_value + 1)
			for i in range(0, SIZE, 16):
				t.hline(0, i, SIZE, _c("light"))
				t.vline(i, 0, SIZE, _c("light"))
			return t
		"floor/bath_tile":
			var t := _filled("white")
			for i in range(0, SIZE, 8):
				t.hline(0, i, SIZE, _c("ice"))
				t.vline(i, 0, SIZE, _c("ice"))
			for y in range(0, SIZE, 16):
				for x in range(0, SIZE, 16):
					t.rect(x + 9, y + 9, 6, 6, _c("sky"))
			return t
		"dash_v":
			var t: RefCounted = PixelCanvas.new(2, 24)
			t.rect(0, 0, 2, 12, _c("amber"))
			return t
		"dash_h":
			var t: RefCounted = PixelCanvas.new(24, 2)
			t.rect(0, 0, 12, 2, _c("amber"))
			return t
		"dash_lane_v":
			# divisória entre as duas faixas de um sentido da avenida
			var t: RefCounted = PixelCanvas.new(1, 16)
			t.rect(0, 0, 1, 8, _c("light"))
			return t
		"dash_lane_h":
			var t: RefCounted = PixelCanvas.new(16, 1)
			t.rect(0, 0, 8, 1, _c("light"))
			return t
		"cross_h":
			var t: RefCounted = PixelCanvas.new(9, 1)
			t.rect(0, 0, 5, 1, _c("white"))
			return t
		"cross_v":
			var t: RefCounted = PixelCanvas.new(1, 9)
			t.rect(0, 0, 1, 5, _c("white"))
			return t
	if id.begins_with("wall/"):
		# Parede pintada em um tom: base com frisos horizontais na cor de sombra.
		var tone: Array[Color] = Palette.tone(id.trim_prefix("wall/"))
		var t: RefCounted = PixelCanvas.new(SIZE, SIZE)
		t.fill(tone[1])
		for y in range(5, SIZE, 6):
			t.hline(0, y, SIZE, tone[0])
		return t
	push_warning("Tile desconhecido: %s" % id)
	return _filled("magenta")


static func has_face(style: String) -> bool:
	return FACE_STYLES.has(style)


## Face de parede (16x12 texels): friso de sombra em cima, padrão do estilo e rodapé embaixo.
static func face(style: String) -> RefCounted:
	if not _faces.has(style):
		_faces[style] = _build_face(style)
	return _faces[style]


static func _build_face(style: String) -> RefCounted:
	var w := FACE_SIZE.x
	var h := FACE_SIZE.y
	var t: RefCounted = PixelCanvas.new(w, h)
	var skirting := "brown_dark"
	match style:
		"stripes_wine":
			t.fill(_c("cream"))
			for x in range(0, w, 4):
				t.rect(x, 1, 2, 9, _c("wine"))
		"wood_panel":
			t.fill(_c("brown"))
			for x in range(0, w, 4):
				t.vline(x, 1, 9, _c("brown_dark"))
			t.hline(0, 1, w, _c("sand"))
			t.hline(0, 5, w, _c("brown_dark"))
		"tile_blue":
			t.fill(_c("ice"))
			for x in range(0, w, 4):
				t.vline(x, 1, 9, _c("sky"))
			for y in [1, 5, 9]:
				t.hline(0, y, w, _c("sky"))
			skirting = "blue"
		"tile_white_green":
			t.fill(_c("white"))
			for x in range(0, w, 4):
				t.vline(x, 1, 9, _c("light"))
			t.rect(0, 6, w, 2, _c("green"))
			skirting = "green_dark"
		"navy_half":
			t.fill(_c("cream"))
			t.rect(0, 5, w, 5, _c("navy"))
			t.hline(0, 5, w, _c("blue"))
			for x in range(0, w, 8):
				t.vline(x, 6, 4, _c("ink"))
			skirting = "ink"
		"brick":
			t.fill(_c("red"))
			for y in range(1, 10, 3):
				t.hline(0, y + 2, w, _c("wine"))
				for x in range(((y / 3) % 2) * 3, w, 6):
					t.vline(x, y, 2, _c("wine"))
		"floral":
			t.fill(_c("cream"))
			for y in range(2, 10, 4):
				for x in range(((y / 4) % 2) * 4 + 1, w, 8):
					t.px(x + 1, y, _c("pink"))
					t.px(x, y + 1, _c("pink"))
					t.px(x + 2, y + 1, _c("pink"))
					t.px(x + 1, y + 1, _c("amber"))
					t.px(x + 1, y + 2, _c("green"))
		"plaster_cream":
			t.fill(_c("cream"))
			t.speckle(_c("sand"), 0.06, hash(style))
		"plaster_gray":
			t.fill(_c("light"))
			t.speckle(_c("gray"), 0.06, hash(style))
			skirting = "slate"
		_:
			push_warning("Face de parede desconhecida: %s" % style)
			t.fill(_c("magenta"))
	t.hline(0, 0, w, _c("shadow"))
	t.hline(0, h - 2, w, _c(skirting))
	t.hline(0, h - 1, w, _c("ink"))
	return t


## Telhado de telhas: fiadas de 4 texels com juntas alternadas e brilho.
static func _roof_tiles(base: String, dark: String, lit: String) -> RefCounted:
	var t := _filled(base)
	for y in range(0, SIZE, 4):
		t.hline(0, y + 3, SIZE, _c(dark))
		for x in range(((y / 4) % 2) * 4, SIZE, 8):
			t.px(x, y + 2, _c(dark))
			t.px(x + 2, y, _c(lit))
	return t


static func _filled(color_name: String) -> RefCounted:
	var t: RefCounted = PixelCanvas.new(SIZE, SIZE)
	t.fill(_c(color_name))
	return t


## Tufos de grama: pares de texels claros em "v".
static func _tufts(t: RefCounted, color: Color, count: int, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for i in count:
		var x := rng.randi_range(1, SIZE - 3)
		var y := rng.randi_range(1, SIZE - 2)
		t.px(x, y, color)
		t.px(x + 1, y - 1, color)
