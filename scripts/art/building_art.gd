extends RefCounted
## Desenha um prédio inteiro em uma tela: telhado com detalhes, fachada sul com janelas,
## porta, toldo e letreiro. O resultado vira uma única textura por prédio.
## Tudo fica dentro do retângulo de colisão; só o degrau da porta sai para a calçada.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")

## Texels abaixo do prédio usados pelo degrau da porta (a porta do mundo tem 12 px).
const STEP_TEXELS := 6
const DOOR_SLOT := 28      # largura da porta do layout, em texels
const DOOR_W := 14
const WINDOW := 4
const WINDOW_STEP := 7


static func _c(color_name: String) -> Color:
	return Palette.get_color(color_name)


## [sombra, base, luz] da parede.
static func wall_tones(wall: String) -> Array[Color]:
	match wall:
		"wall/brick":
			return Palette.ramp("brick")
		"wall/wood":
			return Palette.ramp("wood")
	return Palette.tone(wall.trim_prefix("wall/"))


## [sombra, luz] da borda do telhado.
static func roof_edges(roof: String) -> Array[Color]:
	match roof:
		"roof/tile":
			return [_c("wine"), _c("amber")]
		"roof/tile_red":
			return [_c("wine"), _c("pink")]
		"roof/tile_brown":
			return [_c("brown_dark"), _c("sand")]
		"roof/tar":
			return [_c("ink"), _c("slate")]
		"roof/slab_light", "roof/zinc":
			return [_c("slate"), _c("white")]
	return [_c("shadow"), _c("light")]


## Tamanho da tela (texels) para um prédio de `size` px do mundo.
static func canvas_size(size: Vector2) -> Vector2i:
	return Vector2i(int(size.x / 2.0), int(size.y / 2.0) + STEP_TEXELS)


static func render(b: Dictionary, style: Dictionary) -> RefCounted:
	var rect: Rect2 = b.rect
	var w := int(rect.size.x / 2.0)
	var h := int(rect.size.y / 2.0)
	var canvas: RefCounted = PixelCanvas.new(w, h + STEP_TEXELS)
	var floors: int = style.floors
	var fh := BuildingStyle.facade_texels(floors)
	var rh := h - fh
	var is_shop: bool = style.get("front", style.shop != "")
	var wall: Array[Color] = wall_tones(style.wall)
	var edges: Array[Color] = roof_edges(style.roof)
	var rng := RandomNumberGenerator.new()
	rng.seed = b.id * 104729 + 7

	# Telhado.
	canvas.tile_fill(TileFactory.canvas(style.roof), 0, 0, w, rh)
	canvas.hline(1, 1, w - 2, edges[1])
	canvas.vline(1, 1, rh - 2, edges[1])
	canvas.hline(1, rh - 2, w - 2, edges[0])
	canvas.vline(w - 2, 1, rh - 2, edges[0])
	if (style.roof as String).begins_with("roof/tile"):
		canvas.hline(2, rh / 2, w - 4, edges[1])
		canvas.hline(2, rh / 2 + 1, w - 4, edges[0])
	_roof_details(canvas, b, style, rh, rng)

	# Fachada.
	canvas.tile_fill(TileFactory.canvas(style.wall), 0, rh, w, fh)
	canvas.hline(0, rh - 1, w, _c("ink"))
	canvas.hline(0, rh, w, wall[2])
	canvas.vline(w - 2, rh + 1, fh - 1, wall[0])

	var door_x := int(((b.door as Rect2).position.x - rect.position.x) / 2.0)
	var door_h := 8 if is_shop else 10
	var door_left := door_x + (DOOR_SLOT - DOOR_W) / 2

	for cell in window_cells(b, style):
		_window(canvas, cell.x, cell.y, wall, rng)

	if is_shop:
		_shop_front(canvas, w, h, door_left, style)
	_door(canvas, door_left, h - door_h, door_h, is_shop)

	# Degrau e capacho.
	canvas.rect(door_x, h, DOOR_SLOT, 2, _c("light"))
	canvas.rect(door_x, h + 2, DOOR_SLOT, 1, _c("gray"))
	if is_shop:
		canvas.rect(door_left, h + 3, DOOR_W, 2, _c("red"))
		canvas.rect(door_left, h + 5, DOOR_W, 1, _c("wine"))

	# Contorno do prédio.
	canvas.frame(0, 0, w, h, _c("ink"))

	var placement := sign_placement(b, style)
	if not placement.is_empty():
		_sign(canvas, style, placement.text, placement.rect.position.x, placement.rect.position.y)
	return canvas


## Canto superior esquerdo (em texels, na tela do prédio) de cada janela da fachada.
static func window_cells(b: Dictionary, style: Dictionary) -> Array[Vector2i]:
	var rect: Rect2 = b.rect
	var w := int(rect.size.x / 2.0)
	var h := int(rect.size.y / 2.0)
	var floors: int = style.floors
	var rh := h - BuildingStyle.facade_texels(floors)
	var is_shop: bool = style.get("front", style.shop != "")
	var door_x := int(((b.door as Rect2).position.x - rect.position.x) / 2.0)
	var door_left := door_x + (DOOR_SLOT - DOOR_W) / 2
	var cells: Array[Vector2i] = []
	for f in floors:
		var wy := rh + 3 + f * BuildingStyle.FLOOR_TEXELS
		var ground := f == floors - 1
		if ground and is_shop:
			continue
		var x := 3
		while x + WINDOW <= w - 3:
			var blocked := ground and x + WINDOW > door_left - 2 and x < door_left + DOOR_W + 2
			if not blocked:
				cells.append(Vector2i(x, wy))
			x += WINDOW_STEP
	return cells


## Fração das janelas que ficam acesas à noite neste prédio (40% a 70%, pela seed).
static func lit_fraction(b: Dictionary) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = b.id * 2749 + 31
	return rng.randf_range(0.4, 0.7)


## Janelas acesas do prédio: quais células de `window_cells` acendem (padrão pela seed).
static func lit_window_cells(b: Dictionary, style: Dictionary) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = b.id * 2749 + 32
	var fraction := lit_fraction(b)
	var lit: Array[Vector2i] = []
	for cell in window_cells(b, style):
		if rng.randf() < fraction:
			lit.append(cell)
	return lit


## Linha (em texels, na tela do prédio) onde a fachada começa.
static func facade_top(b: Dictionary, style: Dictionary) -> int:
	return int((b.rect as Rect2).size.y / 2.0) - BuildingStyle.facade_texels(style.floors)


## Tela só com as janelas acesas, para a camada de luz. Cobre apenas a faixa da fachada
## (largura do prédio x altura da fachada), para gastar pouca memória.
static func window_lights(b: Dictionary, style: Dictionary) -> RefCounted:
	var top := facade_top(b, style)
	var canvas: RefCounted = PixelCanvas.new(int((b.rect as Rect2).size.x / 2.0), BuildingStyle.facade_texels(style.floors))
	var rng := RandomNumberGenerator.new()
	rng.seed = b.id * 2749 + 33
	for cell in lit_window_cells(b, style):
		canvas.rect(cell.x, cell.y - top + 1, WINDOW, WINDOW - 1, _c("amber") if rng.randf() < 0.6 else _c("cream"))
		canvas.px(cell.x, cell.y - top + 1, _c("white"))
	return canvas


## Onde fica o letreiro na tela do prédio: {text:String, rect:Rect2i} ou {} se não há letreiro.
static func sign_placement(b: Dictionary, style: Dictionary) -> Dictionary:
	var rect: Rect2 = b.rect
	var w := int(rect.size.x / 2.0)
	var h := int(rect.size.y / 2.0)
	var text := sign_text_for(style, w)
	if text == "":
		return {}
	var rh := h - BuildingStyle.facade_texels(style.floors)
	var door_x := int(((b.door as Rect2).position.x - rect.position.x) / 2.0)
	var center_x := door_x + (DOOR_SLOT - DOOR_W) / 2 + DOOR_W / 2
	var size := PixelFont.measure(text)
	var bw := size.x + 6
	var bh := size.y + 4
	var x := clampi(center_x - bw / 2, 2, maxi(w - bw - 2, 2))
	var y := maxi(rh - bh - 1, 1)
	return {"text": text, "rect": Rect2i(x, y, bw, bh)}


## Tela só com o letreiro (do tamanho dele), para acender à noite na camada de luz.
static func sign_canvas(b: Dictionary, style: Dictionary) -> RefCounted:
	var placement := sign_placement(b, style)
	if placement.is_empty():
		return null
	var rect: Rect2i = placement.rect
	var canvas: RefCounted = PixelCanvas.new(rect.size.x, rect.size.y)
	_sign(canvas, style, placement.text, 0, 0)
	return canvas


## Texto do letreiro que cabe em um prédio de `w` texels: o nome (em até duas linhas), ou o
## letreiro reserva (`sign_short`), ou nada.
static func sign_text_for(style: Dictionary, w: int) -> String:
	for candidate in [style.get("sign", ""), style.get("sign_short", "")]:
		if candidate == "":
			continue
		var text := wrap_sign(candidate, w - 8)
		if PixelFont.measure(text).x + 6 <= w - 4:
			return text
	return ""


static func _window(canvas: RefCounted, x: int, y: int, wall: Array[Color], rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	canvas.rect(x, y, WINDOW, WINDOW, _c("navy"))
	if roll < 0.15:
		canvas.rect(x, y + 1, WINDOW, WINDOW - 1, _c("cream"))   # cortina fechada
	else:
		canvas.rect(x, y + 1, WINDOW, WINDOW - 1, _c("sky"))
		canvas.px(x, y + 1, _c("ice"))
		canvas.px(x + 1, y + 2, _c("ice"))
	canvas.hline(x, y + WINDOW, WINDOW, wall[2])


static func _door(canvas: RefCounted, x: int, y: int, h: int, glass: bool) -> void:
	canvas.rect(x, y, DOOR_W, h, _c("ink"))
	if glass:
		canvas.rect(x + 1, y + 1, DOOR_W - 2, h - 1, _c("sky"))
		canvas.vline(x + DOOR_W / 2 - 1, y + 1, h - 1, _c("ink"))
		canvas.vline(x + DOOR_W / 2, y + 1, h - 1, _c("ink"))
		canvas.px(x + 2, y + 2, _c("ice"))
		canvas.px(x + 3, y + 3, _c("ice"))
		canvas.px(x + DOOR_W / 2 + 2, y + 2, _c("ice"))
		canvas.px(x + DOOR_W / 2 - 3, y + h / 2, _c("white"))
		canvas.px(x + DOOR_W / 2 + 2, y + h / 2, _c("white"))
	else:
		canvas.rect(x + 1, y + 1, DOOR_W - 2, h - 1, _c("brown"))
		canvas.rect(x + 1, y + 1, DOOR_W - 2, 2, _c("sky"))
		canvas.px(x + 2, y + 1, _c("ice"))
		canvas.hline(x + 1, y + 3, DOOR_W - 2, _c("brown_dark"))
		canvas.vline(x + DOOR_W / 2 - 1, y + 1, h - 1, _c("brown_dark"))
		canvas.vline(x + DOOR_W / 2, y + 1, h - 1, _c("sand"))
		canvas.px(x + DOOR_W / 2 - 3, y + h / 2 + 1, _c("amber"))
		canvas.px(x + DOOR_W / 2 + 2, y + h / 2 + 1, _c("amber"))


## Vitrines dos dois lados da porta e toldo listrado.
static func _shop_front(canvas: RefCounted, w: int, h: int, door_left: int, style: Dictionary) -> void:
	for span in [[3, door_left - 2], [door_left + DOOR_W + 2, w - 3]]:
		var x0: int = span[0]
		var x1: int = span[1]
		if x1 - x0 < 5:
			continue
		canvas.rect(x0, h - 8, x1 - x0, 6, _c("ink"))
		canvas.rect(x0 + 1, h - 7, x1 - x0 - 2, 4, _c("sky"))
		for i in range(2, x1 - x0 - 3, 6):
			canvas.px(x0 + i, h - 5, _c("ice"))
			canvas.px(x0 + i + 1, h - 6, _c("ice"))
			canvas.px(x0 + i + 2, h - 7, _c("ice"))
	if style.awning != "":
		var tone: Array[Color] = Palette.tone(style.awning)
		for x in range(2, w - 2):
			var stripe := tone[1] if (x / 2) % 2 == 0 else _c("white")
			canvas.px(x, h - 11, stripe)
			canvas.px(x, h - 10, stripe)
			canvas.px(x, h - 9, tone[0] if (x / 2) % 2 == 0 else _c("light"))


## Letreiro sobre o telhado, logo acima da fachada, centrado na porta quando cabe
## (a posição vem de `sign_placement`).
static func _sign(canvas: RefCounted, style: Dictionary, text: String, x: int, y: int) -> void:
	var size := PixelFont.measure(text)
	var bw := size.x + 6
	var bh := size.y + 4
	canvas.rect(x, y, bw, bh, _c(style.sign_bg))
	canvas.frame(x, y, bw, bh, _c("ink"))
	canvas.frame(x + 1, y + 1, bw - 2, bh - 2, _c(style.sign_fg))
	PixelFont.draw_text(canvas, text, x + 3, y + 2, _c(style.sign_fg), 1)


## Quebra o texto do letreiro em duas linhas quando não cabe em `max_width` texels.
static func wrap_sign(text: String, max_width: int) -> String:
	if PixelFont.measure(text).x <= max_width or not text.contains(" "):
		return text
	var words := text.split(" ")
	var best := text
	var best_width := 1 << 30
	for i in range(1, words.size()):
		var candidate := " ".join(words.slice(0, i)) + "\n" + " ".join(words.slice(i))
		var width := PixelFont.measure(candidate).x
		if width < best_width:
			best_width = width
			best = candidate
	return best


## Caixa d'água, ar condicionado, claraboia etc. nos pontos sorteados pelo layout.
static func _roof_details(canvas: RefCounted, b: Dictionary, style: Dictionary, rh: int, rng: RandomNumberGenerator) -> void:
	var rect: Rect2 = b.rect
	var big := ["roof_tank", "roof_skylight", "roof_ac"]
	var small := ["roof_ac", "roof_chimney", "roof_antenna"]
	if (style.roof as String).begins_with("roof/tile"):
		big = ["roof_chimney", "roof_skylight"]
		small = ["roof_chimney"]
	for d in b.roof:
		var spot: Rect2 = d
		var options: Array = big if spot.size.x >= 30.0 and spot.size.y >= 30.0 else small
		var prop: RefCounted = PropSprites.canvas(options[rng.randi_range(0, options.size() - 1)])
		var x := int((spot.position.x - rect.position.x) / 2.0)
		var y := int((spot.position.y - rect.position.y) / 2.0)
		if x < 3 or y < 3 or x + prop.width > canvas.width - 3 or y + prop.height > rh - 3:
			continue
		# sombra do objeto no telhado
		canvas.blit(prop.silhouette(_c("ink")), x + 1, y + 1)
		canvas.blit(prop, x, y)
