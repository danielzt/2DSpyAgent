extends RefCounted
## Móveis, itens de parede e itens de cima de móvel da Fase 7 (interiores caprichados).
## Desenhados no tamanho real da planta (personagem = 12x16 texels). Usado por `furniture_art.gd`.
## Só cores da paleta, contorno tinta, luz do noroeste.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")


static func _c(color_name: String) -> Color:
	return Palette.get_color(color_name)


## Bloco cheio com luz em cima, sombra embaixo e contorno.
static func _box(c: RefCounted, x: int, y: int, w: int, h: int, t: Array[Color]) -> void:
	c.rect(x, y, w, h, t[1])
	if w > 4 and h > 4:
		c.hline(x + 1, y + 1, w - 2, t[2])
		c.rect(x + 1, y + h - 3, w - 2, 2, t[0])
	c.frame(x, y, w, h, _c("ink"))


## Cama de solteiro, leito de hospital ou beliche vistos de cima: cabeceira, travesseiro,
## lençol dobrado e cobertor. Deitada (cabeceira à esquerda) se w > h.
static func bed(c: RefCounted, kind: String, w: int, h: int) -> void:
	var blanket: Array[Color] = Palette.tone("blue")
	if kind == "hospital_bed":
		blanket = Palette.tone("teal")
	elif kind == "bunk":
		blanket = Palette.tone("gray")
	var frame_color := _c("brown_dark") if kind == "bed" else _c("gray")
	var vertical := h >= w
	var bw := w if vertical else h
	var bh := h if vertical else w
	var b: RefCounted = PixelCanvas.new(bw, bh)
	b.fill(frame_color)
	b.rect(1, 3, bw - 2, bh - 4, _c("white"))
	var pillow := maxi(bh / 6, 3)
	b.rect(2, 4, bw - 4, pillow, _c("light"))
	b.hline(3, 4, bw - 6, _c("white"))
	var top := 4 + pillow + 2
	b.rect(1, top, bw - 2, bh - top - 1, blanket[1])
	b.hline(1, top, bw - 2, _c("white"))
	b.hline(1, top + 1, bw - 2, blanket[2])
	b.vline(1, top + 2, bh - top - 3, blanket[0])
	b.vline(bw - 2, top + 2, bh - top - 3, blanket[0])
	if kind == "hospital_bed":
		b.vline(0, top, bh - top, _c("slate"))
		b.vline(bw - 1, top, bh - top, _c("slate"))
	b.rect(0, 0, bw, 3, frame_color)
	b.hline(1, 1, bw - 2, _c("sand") if kind == "bed" else _c("light"))
	b.frame(0, 0, bw, bh, _c("ink"))
	if vertical:
		c.blit(b, 0, 0)
		return
	for y in b.height:
		for x in b.width:
			if not b.is_empty_at(x, y):
				c.px(y, b.width - 1 - x, b.get_px(x, y))


## Desenha `kind` se for um tipo da Fase 7. Devolve false para os demais.
static func build(c: RefCounted, kind: String, w: int, h: int, t: Array[Color]) -> bool:
	var ink := _c("ink")
	match kind:
		# --- móveis ---
		"armchair":
			# poltrona de cima: encosto alto, braços arredondados e almofada clara no assento
			var arm := maxi(w / 6, 2)
			var back := maxi(h / 3, 3)
			c.rect(0, 0, w, back, t[0])
			c.hline(1, 1, w - 2, t[1])
			c.rect(0, back, arm, h - back, t[0])
			c.rect(w - arm, back, arm, h - back, t[0])
			c.vline(1, back, h - back - 1, t[1])
			c.vline(w - 2, back, h - back - 1, t[1])
			c.rect(arm, back, w - arm * 2, h - back, t[1])
			c.rect(arm + 1, back + 1, w - arm * 2 - 2, maxi(h / 4, 2), t[2])
			c.px(0, 0, Color(0, 0, 0, 0))
			c.px(w - 1, 0, Color(0, 0, 0, 0))
			c.outline(ink)
		"double_bed":
			c.fill(_c("brown_dark"))
			c.rect(1, 3, w - 2, h - 4, _c("white"))
			var pw := (w - 6) / 2
			var pillow := maxi(h / 6, 3)
			c.rect(2, 4, pw, pillow, _c("light"))
			c.rect(w - 2 - pw, 4, pw, pillow, _c("light"))
			c.hline(3, 4, pw - 2, _c("white"))
			c.hline(w - 1 - pw, 4, pw - 2, _c("white"))
			var top := 4 + pillow + 2
			c.rect(1, top, w - 2, h - top - 1, t[1])
			c.hline(1, top, w - 2, _c("white"))
			c.hline(1, top + 1, w - 2, t[2])
			for y in range(top + 4, h - 2, 4):
				for x in range(3 + ((y / 4) % 2) * 2, w - 3, 4):
					c.px(x, y, t[0])
			c.rect(0, 0, w, 3, _c("brown"))
			c.hline(1, 1, w - 2, _c("sand"))
			c.frame(0, 0, w, h, ink)
		"chair":
			c.rect(1, 1, w - 2, h - 2, t[1])
			c.rect(1, 1, w - 2, 3, t[0])
			c.hline(2, 5, w - 4, t[2])
			c.outline(ink)
		"office_chair":
			c.ellipse(1, 2, w - 2, h - 3, t[1])
			c.ellipse(3, 4, w - 6, h - 7, t[2])
			c.rect(2, 0, w - 4, 3, t[0])
			c.outline(ink)
		"floor_lamp":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(w / 4, h / 4, w / 2, h / 2, _c("cream"))
			c.px(w / 2, h / 2, _c("white"))
			c.outline(ink)
		"fireplace":
			c.fill(t[1])
			for y in range(2, h, 3):
				c.hline(0, y, w, t[0])
			c.rect(0, 0, w, 2, _c("sand"))
			c.rect(w / 4, h / 3, w / 2, h - h / 3, ink)
			c.rect(w / 4 + 2, h - 4, w / 2 - 4, 3, _c("orange"))
			c.rect(w / 2 - 2, h - 6, 4, 3, _c("amber"))
			c.px(w / 2, h - 7, _c("cream"))
			c.frame(0, 0, w, h, ink)
		"record_player":
			_box(c, 0, 0, w, h, t)
			var d := mini(w - 6, h - 4)
			c.ellipse(2, 2, d, d, ink)
			c.px(2 + d / 2, 2 + d / 2, _c("red"))
			c.vline(w - 3, 2, h / 2, _c("light"))
		"dresser":
			_box(c, 0, 0, w, h, t)
			var third := maxi(w / 3, 2)
			for x in range(third, w - 2, third):
				c.vline(x, 2, h - 4, t[0])
			for x in range(third / 2, w, third):
				c.px(x, h / 2, _c("amber"))
		"round_table":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 3, t[1])
			c.ellipse(3, 2, w - 8, maxi(h / 3, 2), t[2])
			c.outline(ink)
		"bar_stool":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.px(w / 2 - 1, h / 2 - 1, t[2])
			c.outline(ink)
		"beer_taps":
			c.rect(0, h / 2, w, h - h / 2, _c("slate"))
			for x in range(3, w - 2, maxi(w / 4, 4)):
				c.rect(x, 1, 3, h / 2 + 1, t[2])
				c.rect(x, 0, 3, 2, _c("amber"))
			c.outline(ink)
		"interrogation_table":
			_box(c, 0, 0, w, h, t)
			c.rect(w / 2 - 6, h / 2 - 4, 10, 7, _c("white"))
			c.hline(w / 2 - 5, h / 2 - 2, 8, _c("gray"))
			c.rect(w - 9, 3, 5, 5, _c("amber"))
		"flag":
			c.rect(0, 0, 2, h, _c("slate"))
			c.rect(2, 1, w - 2, h * 2 / 3, t[1])
			c.rect(w / 2 - 1, h / 4, 4, maxi(h / 4, 2), _c("amber"))
			c.frame(2, 1, w - 2, h * 2 / 3, ink)
			c.rect(0, h - 2, 6, 2, _c("slate"))
		"kitchen_counter":
			# bancada de cozinha: armário de madeira com tampo claro e puxadores
			c.rect(0, 0, w, h, t[1])
			c.rect(0, 0, w, maxi(h / 3, 2), _c("light"))
			c.hline(0, maxi(h / 3, 2), w, _c("gray"))
			for x in range(maxi(w / 4, 4), w - 1, maxi(w / 4, 4)):
				c.vline(x, h / 3 + 1, h - h / 3 - 2, t[0])
				c.px(x - 2, h * 2 / 3, _c("amber"))
			c.frame(0, 0, w, h, _c("ink"))
		"teller":
			# guichê: balcão de madeira com vidro em cima e divisórias
			_box(c, 0, h / 3, w, h - h / 3, t)
			c.rect(1, 0, w - 2, h / 3, _c("ice"))
			c.hline(1, 0, w - 2, _c("white"))
			for x in range(w / 3, w - 1, w / 3):
				c.vline(x, 0, h, _c("slate"))
			c.frame(0, 0, w, h, _c("ink"))
		"column":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(2, 2, w / 2, h / 2, t[2])
			c.outline(ink)
		"luggage_cart":
			c.rect(1, h - 3, w - 2, 2, t[0])
			c.rect(1, 1, 2, h - 2, t[1])
			c.rect(w - 3, 1, 2, h - 2, t[1])
			c.rect(4, 3, w / 2 - 3, h - 7, _c("brown"))
			c.rect(w / 2 + 1, 5, w / 2 - 5, h - 9, _c("wine"))
			c.outline(ink)
		"dining_table":
			# mesa com toalha branca e barra
			c.rect(0, 0, w, h, _c("light"))
			c.rect(1, 1, w - 2, h - 2, _c("white"))
			c.frame(2, 2, w - 4, h - 4, _c("wine"))
			c.outline(ink)
		"booth":
			# cabine de lanchonete: banco estofado em U visto de cima
			c.rect(0, 0, w, h, t[1])
			c.rect(0, 0, w, 3, t[0])
			c.rect(3, 4, w - 6, h - 5, _c("cream"))
			c.rect(4, 5, w - 8, h - 7, _c("white"))
			c.frame(0, 0, w, h, ink)
		"griddle":
			_box(c, 0, 0, w, h, t)
			c.rect(2, 2, w - 4, h - 5, _c("shadow"))
			c.rect(4, 4, 4, 3, _c("brown"))
			c.rect(w / 2, 4, 4, 3, _c("brown"))
			c.px(w - 4, h - 3, _c("orange"))
		"milkshake":
			_box(c, 0, 0, w, h, t)
			c.rect(w / 2 - 2, 2, 4, h / 2, _c("silver") if Palette.has_color("silver") else _c("light"))
			c.ellipse(w / 2 - 3, h - 7, 6, 5, _c("cream"))
		"dance_floor":
			var lights := ["magenta", "purple", "neon_cyan", "blue", "neon_green"]
			c.fill(_c("shadow"))
			for y in range(0, h, 8):
				for x in range(0, w, 8):
					c.rect(x + 1, y + 1, 6, 6, _c(lights[((x / 8) * 3 + (y / 8) * 5) % lights.size()]))
			c.frame(0, 0, w, h, ink)
		"cleaning_cart":
			_box(c, 0, 0, w, h, t)
			c.rect(2, 2, w / 2 - 2, h - 5, _c("white"))
			c.rect(w / 2 + 1, 2, w / 2 - 3, h / 2 - 1, _c("sky"))
			c.px(w - 4, h - 4, _c("amber"))
		"neon":
			c.fill(_c("shadow"))
			c.frame(0, 0, w, h, ink)
			for x in range(2, w - 2):
				c.px(x, h / 2 + (1 if (x / 3) % 2 == 0 else -1), t[1])
			c.hline(2, h - 3, w - 4, _c("neon_cyan"))
		"key_rack":
			c.fill(t[1])
			c.frame(0, 0, w, h, ink)
			for x in range(2, w - 2, 3):
				for y in range(2, h - 2, 4):
					c.px(x, y, _c("amber"))
		"elevator_door":
			c.fill(t[1])
			c.vline(w / 2, 1, h - 1, _c("slate"))
			c.rect(w / 2 - 2, 1, 4, 2, _c("amber"))
			c.frame(0, 0, w, h, ink)
		"menu_board":
			c.fill(t[1])
			c.frame(0, 0, w, h, _c("brown"))
			for y in range(2, h - 2, 3):
				c.hline(2, y, w / 2, _c("white"))
				c.hline(w - 6, y, 3, _c("amber"))
		"candle":
			c.ellipse(0, 0, w, h, _c("cream"))
			c.ellipse(w / 3, h / 3, maxi(w / 3, 2), maxi(h / 3, 2), t[1])
			c.px(w / 2, h / 2, _c("orange"))
		"bell":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.px(w / 2 - 1, h / 2 - 1, _c("cream"))
		"cash_register":
			c.rect(0, 0, w, h, t[1])
			c.rect(1, 1, w - 2, h / 3, _c("ink"))
			c.px(2, 2, _c("neon_green"))
			for y in range(h / 2, h - 1, 2):
				c.hline(1, y, w - 2, _c("light"))
			c.frame(0, 0, w, h, ink)
		"target":
			# alvo de papel no suporte
			c.rect(w / 2 - 1, h - 3, 2, 3, _c("slate"))
			c.rect(1, 0, w - 2, h - 3, _c("white"))
			c.ellipse(2, 1, w - 4, h - 5, _c("ink"))
			c.ellipse(4, 3, w - 8, h - 9, _c("white"))
			c.px(w / 2, (h - 3) / 2, _c("red"))
			c.frame(1, 0, w - 2, h - 3, _c("slate"))
		"display_case":
			# vitrine de vidro com produtos dentro
			_box(c, 0, 0, w, h, Palette.tone("brown"))
			c.rect(2, 2, w - 4, h - 4, t[1])
			var colors := ["slate", "amber", "red", "navy", "light"]
			for x in range(3, w - 4, 5):
				c.rect(x, h / 2 - 1, 3, 2, _c(colors[(x / 5) % colors.size()]))
			c.hline(2, 2, w - 4, _c("white"))
		"freezer":
			_box(c, 0, 0, w, h, t)
			c.rect(2, 2, w - 4, h - 5, _c("ice"))
			for x in range(4, w - 4, 6):
				c.rect(x, 4, 4, h / 3, _c("sky"))
				c.rect(x, h / 2, 4, h / 4, _c("light"))
			c.hline(2, 2, w - 4, _c("white"))
		"checkout":
			_box(c, 0, 0, w, h, t)
			c.rect(2, 2, w / 2, h - 5, _c("ink"))
			c.rect(w - 9, 2, 7, 5, _c("slate"))
			c.px(w - 7, 3, _c("neon_green"))
		"shopping_cart":
			c.rect(1, 1, w - 2, h - 4, t[1])
			for x in range(2, w - 2, 2):
				c.vline(x, 2, h - 6, t[0])
			c.px(2, h - 2, _c("ink"))
			c.px(w - 3, h - 2, _c("ink"))
			c.outline(_c("ink"))
		"feed_sacks":
			for i in 3:
				var sx := (i % 2) * (w / 2) + 1
				var sy := (i / 2) * (h / 2) + 1
				c.rect(sx, sy, w / 2 - 2, h / 2 - 2, t[1])
				c.hline(sx + 1, sy + 1, w / 2 - 4, t[2])
				c.hline(sx + 2, sy + h / 4, w / 2 - 6, _c("green"))
			c.rect(w / 2 + 1, h / 2 + 1, w / 2 - 2, h / 2 - 2, t[0])
			c.outline(_c("ink"))
		"barrel":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(3, 3, w - 6, h - 6, t[2])
			c.ellipse(w / 2 - 1, h / 2 - 1, 2, 2, t[0])
			c.outline(_c("ink"))
		"mannequin":
			c.ellipse(1, 2, w - 2, h - 3, t[1])
			c.ellipse(w / 2 - 3, 0, 6, 6, _c("light"))
			c.rect(w / 2 - 1, 6, 2, 4, _c("white"))
			c.px(w / 2, 7, _c("red"))
			c.outline(_c("ink"))
		"scale":
			c.rect(1, h / 2, w - 2, h / 2 - 1, t[1])
			c.ellipse(2, 0, w - 4, h / 2 + 2, t[2])
			c.vline(w / 2, 2, h / 3, _c("red"))
			c.outline(_c("ink"))
		"drink_fridge":
			_box(c, 0, 0, w, h, t)
			c.rect(2, 2, w - 4, h - 5, _c("ink"))
			var drinks := ["red", "amber", "lime", "sky", "orange"]
			for x in range(3, w - 3, 3):
				c.rect(x, 3, 2, h / 2 - 3, _c(drinks[x % drinks.size()]))
				c.rect(x, h / 2 + 1, 2, h / 2 - 5, _c(drinks[(x + 2) % drinks.size()]))
		"gun_rack":
			c.fill(t[1])
			c.frame(0, 0, w, h, _c("ink"))
			for x in range(2, w - 2, 3):
				c.vline(x, 2, h - 4, _c("ink"))
				c.px(x, 2, _c("slate"))
		"tool_rack":
			c.fill(_c("sand"))
			c.frame(0, 0, w, h, _c("brown_dark"))
			for x in range(2, w - 2, 4):
				c.vline(x, 2, h - 5, _c("brown"))
				c.rect(x - 1, h - 4, 3, 2, _c("slate"))
		"cross_sign":
			c.fill(_c("white"))
			c.frame(0, 0, w, h, _c("ink"))
			c.rect(w / 2 - 1, 2, 3, h - 4, t[1])
			c.rect(w / 2 - 4, h / 2 - 1, 9, 3, t[1])
		"coffee_machine":
			_box(c, 0, 0, w, h, t)
			c.rect(3, 3, w - 6, h / 3, ink)
			c.px(w - 4, 2, _c("red"))
			c.ellipse(w / 2 - 3, h - 7, 6, 5, _c("white"))
		# --- itens de parede ---
		"window":
			c.frame(0, 0, w, h, ink)
			c.frame(1, 1, w - 2, h - 2, t[1])
			c.vline(w / 2, 1, h - 2, t[1])
			c.hline(1, h / 2, w - 2, t[1])
			c.hline(0, h - 1, w, t[2])
		"painting":
			c.fill(t[0])
			c.rect(2, 2, w - 4, h / 2 - 1, _c("sky"))
			c.rect(2, h / 2 + 1, w - 4, h - h / 2 - 3, _c("green"))
			c.ellipse(w - 7, 3, 3, 3, _c("amber"))
			c.frame(0, 0, w, h, ink)
		"diploma":
			c.fill(_c("brown"))
			c.rect(2, 2, w - 4, h - 4, _c("cream"))
			c.hline(4, 4, w - 8, _c("gray"))
			c.hline(4, 6, w - 10, _c("gray"))
			c.px(w - 5, h - 4, _c("red"))
			c.frame(0, 0, w, h, ink)
		"clock":
			var d := mini(w, h)
			c.ellipse((w - d) / 2, (h - d) / 2, d, d, ink)
			c.ellipse((w - d) / 2 + 1, (h - d) / 2 + 1, d - 2, d - 2, t[2])
			c.vline(w / 2, h / 2 - d / 3, d / 3, ink)
			c.hline(w / 2, h / 2, maxi(d / 4, 1), ink)
		"extinguisher":
			c.rect(1, 1, w - 2, h - 2, _c("white"))
			c.frame(0, 0, w, h, ink)
			c.rect(w / 2 - 2, 2, 4, h - 4, t[1])
			c.px(w / 2 - 1, 3, t[2])
			c.rect(w / 2 + 2, 2, 2, 2, ink)
		"notice_board", "wanted_board", "case_wall":
			c.fill(t[1])
			var step := maxi(w / 4, 4)
			for x in range(2, w - 3, step):
				c.rect(x, 2, step - 1, h / 2 - 1, _c("white"))
				if kind == "wanted_board":
					c.rect(x + step / 2 - 1, 3, 2, 2, _c("skin_light"))
				else:
					c.px(x + 1, 2, _c("red"))
			if kind == "case_wall":
				for x in range(2, w - 2):
					c.px(x, h / 2 + 1 + absi((x % 6) - 3) / 2, _c("red"))
				c.rect(w / 3, h - 4, maxi(w / 4, 2), 2, _c("white"))
			c.frame(0, 0, w, h, _c("brown_dark"))
		"wall_tv":
			c.fill(ink)
			c.rect(1, 1, w - 2, h - 3, _c("sky"))
			c.hline(2, 2, w / 2, _c("ice"))
			c.rect(w / 2 - 1, h - 2, 2, 2, _c("slate"))
		"wall_shelf":
			c.rect(0, h - 3, w, 3, t[1])
			c.hline(0, h - 3, w, t[2])
			var colors := ["red", "teal", "amber", "blue", "green"]
			for x in range(1, w - 2, 3):
				c.rect(x, 2 + (x % 3), 2, h - 5 - (x % 3), _c(colors[x % colors.size()]))
			c.outline(ink)
		"mirror":
			c.fill(_c("light"))
			c.rect(1, 1, w - 2, h - 2, t[1])
			c.px(3, 2, _c("white"))
			c.px(4, 3, _c("white"))
			c.frame(0, 0, w, h, ink)
		"exit_sign":
			c.fill(t[1])
			c.rect(w / 2 - 1, 2, 2, 2, _c("white"))
			c.rect(w / 2 - 2, 4, 3, maxi(h - 7, 1), _c("white"))
			c.px(w / 2 + 2, 5, _c("white"))
			c.frame(0, 0, w, h, ink)
		"wall_lamp":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(w / 3, h / 3, maxi(w / 3, 2), maxi(h / 3, 2), _c("cream"))
		"dartboard":
			var d := mini(w, h)
			var x0 := (w - d) / 2
			var y0 := (h - d) / 2
			c.ellipse(x0, y0, d, d, ink)
			c.ellipse(x0 + 1, y0 + 1, d - 2, d - 2, _c("red"))
			c.ellipse(x0 + 3, y0 + 3, d - 6, d - 6, _c("cream"))
			c.ellipse(x0 + d / 2 - 1, y0 + d / 2 - 1, 3, 3, _c("green"))
			c.rect(0, 0, 2, h, _c("brown_dark"))
			c.rect(w - 2, 0, 2, h, _c("brown_dark"))
		"bottle_wall":
			c.fill(_c("amber"))
			c.hline(0, h / 2, w, t[0])
			var bottles := ["green", "brown", "wine", "teal", "cream"]
			for x in range(1, w - 1, 2):
				c.rect(x, 1 + (x % 2), 1, h / 2 - 1 - (x % 2), _c(bottles[x % bottles.size()]))
				c.rect(x, h / 2 + 1, 1, h - h / 2 - 2, _c(bottles[(x + 2) % bottles.size()]))
			c.frame(0, 0, w, h, ink)
		"safe_wall":
			_box(c, 0, 0, w, h, t)
			var d := maxi(mini(w, h) / 2, 2)
			c.ellipse(w / 2 - d / 2, h / 2 - d / 2, d, d, _c("slate"))
			c.px(w / 2, h / 2, _c("amber"))
		# --- itens de cima de móvel ---
		"plate":
			c.ellipse(0, 0, w, h, _c("light"))
			c.ellipse(1, 1, w - 2, h - 2, _c("white"))
			c.ellipse(w / 4, h / 4, maxi(w / 2, 2), maxi(h / 2, 2), _c("orange"))
			c.px(w / 2, h / 2, _c("green"))
		"glass":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(1, 1, w - 2, maxi(h / 3, 2), _c("white"))
		"mug":
			c.ellipse(0, 0, w - 1, h, t[1])
			c.ellipse(1, 1, w - 3, h - 2, _c("brown"))
			c.px(w - 1, h / 2, t[1])
		"ashtray":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.px(w / 2, h / 2, ink)
		"bottle":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(w / 2 - 1, h / 2 - 1, 2, 2, t[2])
		"papers":
			c.rect(0, 0, w, h, _c("light"))
			c.rect(1, 0, w - 1, h - 1, _c("white"))
			for y in range(2, h - 1, 2):
				c.hline(2, y, w - 4, _c("gray"))
		"phone":
			c.rect(0, 0, w, h, t[1])
			c.rect(1, 1, w - 2, maxi(h / 3, 1), t[0])
			for y in range(h / 2, h - 1, 2):
				for x in range(1, w - 1, 2):
					c.px(x, y, _c("light"))
		"book":
			c.rect(0, 0, w, h, t[1])
			c.vline(w - 2, 1, h - 2, _c("white"))
			c.hline(1, 1, w - 3, t[2])
			c.frame(0, 0, w, h, ink)
		"table_lamp":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.ellipse(w / 3, h / 3, maxi(w / 3, 2), maxi(h / 3, 2), _c("cream"))
		"fruit_bowl":
			c.ellipse(0, 0, w, h, t[0])
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.px(w / 3, h / 3, _c("red"))
			c.px(w * 2 / 3, h / 3, _c("amber"))
			c.px(w / 2, h * 2 / 3, _c("lime"))
			c.px(w / 3, h * 2 / 3, _c("red"))
		"coffee_pot":
			c.ellipse(0, 1, w - 2, h - 2, t[1])
			c.ellipse(1, 2, w - 4, h - 4, _c("brown_dark"))
			c.rect(w - 2, h / 2 - 1, 2, 2, t[0])
		"flowers":
			c.ellipse(0, 0, w, h, _c("green"))
			c.px(w / 3, h / 3, t[1])
			c.px(w * 2 / 3, h / 2, _c("red"))
			c.px(w / 2, h * 2 / 3, _c("amber"))
			c.px(w / 4, h * 2 / 3, t[1])
		"stethoscope_tray":
			c.rect(0, 0, w, h, t[1])
			c.frame(0, 0, w, h, t[0])
			c.ellipse(1, 1, maxi(w / 2, 3), maxi(h / 2, 3), ink)
			c.px(w - 3, h - 3, _c("slate"))
		"pool_cue":
			var n := maxi(w, h)
			for i in n:
				var x := i * (w - 1) / maxi(n - 1, 1)
				var y := i * (h - 1) / maxi(n - 1, 1)
				c.px(x, y, t[1])
				c.px(mini(x + 1, w - 1), y, t[0])
			c.px(w - 1, h - 1, _c("sky"))
		"cat":
			c.ellipse(0, h / 4, w, h - h / 4, t[0])
			c.ellipse(1, h / 4 + 1, w - 2, h - h / 4 - 2, t[1])
			c.ellipse(1, 0, maxi(w / 2, 2), h / 2 + 1, t[1])
			c.px(1, 0, t[0])
			c.px(w / 2 - 1, 0, t[0])
			c.hline(w / 2, h - 2, w / 2 - 1, t[0])
			c.px(w / 4, h / 4, ink)
			c.outline(ink)
		_:
			return false
	return true
