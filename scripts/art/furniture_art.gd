extends RefCounted
## Móveis dos interiores, desenhados por código no tamanho pedido (em texels).
## Cada tipo tem material e detalhes próprios para ser reconhecido de cima: cama com
## travesseiro, fogão com bocas, mesa de sinuca com caçapas, grade de cela etc.
## Só cores da paleta, contorno tinta, luz do noroeste.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const FurnitureArt7 := preload("res://scripts/art/furniture_art_7.gd")

## Material base por tipo: nome de tom (Palette.TONES) ou de rampa, com prefixo "ramp:".
const MATERIALS := {
	"counter": "ramp:wood", "shelf": "ramp:wood", "crate": "sand", "crates": "sand", "plant": "green",
	"bed": "white", "nightstand": "ramp:wood", "rug": "wine", "sofa": "red", "table": "ramp:wood",
	"stove": "silver", "fridge": "snow", "bottle_shelf": "brown", "stool": "ramp:wood",
	"pool_table": "green", "jukebox": "purple", "dj_booth": "black", "speaker": "black", "vault": "silver",
	"rope": "red", "bench": "ramp:wood", "cell_bars": "silver", "bunk": "gray", "desk": "ramp:wood",
	"locker": "blue", "board": "sand", "hospital_bed": "snow", "screen_divider": "ice", "cabinet": "snow",
	"car_lift": "gray", "workbench": "ramp:wood", "tires": "black", "toolbox": "red", "oil_stain": "black",
	"movie_screen": "snow", "seats": "wine", "popcorn": "red", "poster": "yellow", "ring": "blue",
	"treadmill": "gray", "weights": "black", "water_cooler": "ice", "wardrobe": "brown", "tv": "black",
	"pallet": "sand", "forklift": "yellow", "washer": "snow", "washer_secret": "snow", "basket": "sand",
	"wall_screen": "navy", "briefing_table": "navy", "chest": "ramp:wood",
	# Fase 6 (interiores completos)
	"computer": "gray", "file_cabinet": "gray", "cart": "silver", "xray": "snow", "toilet": "snow",
	"bathtub": "snow", "bookshelf": "ramp:wood", "vending": "red", "sink": "silver", "monitor": "gray",
	"curtain": "ice", "trash": "gray", "coat_rack": "ramp:wood",
	# Fase 7 (interiores caprichados): móveis
	"armchair": "wine", "double_bed": "wine", "chair": "ramp:wood", "office_chair": "black",
	"floor_lamp": "yellow", "fireplace": "red", "record_player": "brown", "dresser": "ramp:wood",
	"round_table": "ramp:wood", "bar_stool": "wine", "beer_taps": "silver", "interrogation_table": "silver",
	"flag": "green", "coffee_machine": "gray", "kitchen_counter": "ramp:wood",
	# itens de parede
	"window": "ramp:wood", "painting": "yellow", "clock": "snow", "extinguisher": "red", "notice_board": "sand",
	"wall_tv": "black", "wall_shelf": "ramp:wood", "mirror": "ice", "exit_sign": "green", "wall_lamp": "yellow",
	"diploma": "cream", "wanted_board": "sand", "dartboard": "black", "bottle_wall": "brown", "case_wall": "sand",
	"safe_wall": "silver",
	# itens de cima de móvel
	"plate": "snow", "glass": "yellow", "bottle": "green", "papers": "snow", "phone": "black", "book": "red",
	"table_lamp": "yellow", "fruit_bowl": "brown", "coffee_pot": "gray", "mug": "snow", "ashtray": "silver",
	"flowers": "pink", "stethoscope_tray": "silver", "pool_cue": "brown", "cat": "orange",
	# Etapa 2: banco, hotel, restaurante, lanchonete, boate
	"teller": "ramp:wood", "column": "cream", "luggage_cart": "yellow", "dining_table": "snow", "booth": "red",
	"griddle": "silver", "milkshake": "pink", "dance_floor": "purple", "cleaning_cart": "silver",
	"neon": "pink", "key_rack": "ramp:wood", "elevator_door": "silver", "menu_board": "black",
	"candle": "yellow", "bell": "yellow", "cash_register": "gray",
}
## Itens presos na face da parede (sem colisão) e itens que ficam em cima de móveis.
const WALL_KINDS := ["window", "painting", "clock", "extinguisher", "poster", "notice_board", "wall_tv",
	"wall_shelf", "mirror", "exit_sign", "wall_lamp", "diploma", "wanted_board", "dartboard", "bottle_wall",
	"case_wall", "safe_wall", "neon", "key_rack", "elevator_door", "menu_board"]
const ON_KINDS := ["plate", "glass", "bottle", "papers", "phone", "book", "table_lamp", "fruit_bowl",
	"coffee_pot", "mug", "ashtray", "flowers", "stethoscope_tray", "pool_cue", "cat", "candle", "bell", "cash_register"]

static var _canvases := {}


static func kinds() -> Array:
	return MATERIALS.keys()


static func has_kind(kind: String) -> bool:
	return MATERIALS.has(kind)


static func cache_key(kind: String, w: int, h: int, tone := "") -> String:
	if tone != "":
		return "furniture/%s/%dx%d/%s" % [kind, w, h, tone]
	return "furniture/%s/%dx%d" % [kind, w, h]


## Tela do móvel (gerada uma vez por tipo, tamanho e tom). `tone` (opcional) troca o material
## por um tom da paleta (variantes de cor das plantas).
static func canvas(kind: String, w: int, h: int, tone := "") -> RefCounted:
	var key := cache_key(kind, w, h, tone)
	if not _canvases.has(key):
		_canvases[key] = _build(kind, maxi(w, 4), maxi(h, 4), tone)
	return _canvases[key]


static func _c(color_name: String) -> Color:
	return Palette.get_color(color_name)


## [sombra, base, luz] do material do tipo.
static func tones(kind: String, tone := "") -> Array[Color]:
	if tone != "" and Palette.TONES.has(tone):
		return Palette.tone(tone)
	var material: String = MATERIALS.get(kind, "ramp:wood")
	if material.begins_with("ramp:"):
		return Palette.ramp(material.trim_prefix("ramp:"))
	return Palette.tone(material)


## Bloco cheio com luz em cima, sombra embaixo e contorno.
static func _box(c: RefCounted, x: int, y: int, w: int, h: int, t: Array[Color]) -> void:
	c.rect(x, y, w, h, t[1])
	if w > 4 and h > 4:
		c.hline(x + 1, y + 1, w - 2, t[2])
		c.rect(x + 1, y + h - 3, w - 2, 2, t[0])
	c.frame(x, y, w, h, _c("ink"))


static func _build(kind: String, w: int, h: int, tone := "") -> RefCounted:
	var c: RefCounted = PixelCanvas.new(w, h)
	var t := tones(kind, tone)
	var ink := _c("ink")
	if FurnitureArt7.build(c, kind, w, h, t):
		return c
	match kind:
		"rug":
			c.rect(0, 0, w, h, t[1])
			c.frame(1, 1, w - 2, h - 2, _c("amber"))
			c.frame(0, 0, w, h, t[0])
			return c
		"oil_stain":
			c.ellipse(0, 0, w, h, Palette.cast_shadow())
			return c
		"plant":
			c.ellipse(1, 1, w - 2, h - 2, _c("green_dark"))
			c.ellipse(2, 2, w - 6, h - 6, _c("green"))
			c.px(w / 2 - 2, h / 2 - 3, _c("lime"))
			c.px(w / 2, h / 2 - 1, _c("lime"))
			c.ellipse(w / 2 - 3, h / 2 + 2, 6, 5, _c("brown"))
			c.outline(ink)
			return c
		"stool":
			c.ellipse(1, 1, w - 2, h - 2, t[1])
			c.px(w / 2 - 2, h / 2 - 2, t[2])
			c.outline(ink)
			return c
		"tires":
			for ix in 2:
				for iy in 2:
					var tw := w / 2
					var th := h / 2
					c.ellipse(ix * tw + 1, iy * th + 1, tw - 2, th - 2, _c("shadow"))
					c.ellipse(ix * tw + tw / 2 - 3, iy * th + th / 2 - 3, 6, 6, _c("slate"))
			c.outline(ink)
			return c
		"rope":
			c.rect(w / 2 - 1, 0, 2, h, t[1])
			c.rect(0, 0, w, 4, _c("amber"))
			c.rect(0, h - 4, w, 4, _c("amber"))
			c.outline(ink)
			return c
		"cell_bars":
			c.rect(0, 0, w, h, _c("ink"))
			for x in range(2, w - 1, 6):
				c.rect(x, 1, 2, h - 2, t[2])
			return c
	_box(c, 0, 0, w, h, t)
	match kind:
		"counter", "workbench":
			c.hline(2, 3, w - 4, t[0])
			if kind == "workbench":
				for y in range(8, h - 6, 14):
					c.rect(w / 2 - 3, y, 6, 3, _c("gray"))
			else:
				c.rect(w - 14, 3, 8, 5, _c("slate"))    # caixa registradora
				c.px(w - 11, 4, _c("neon_green"))
		"shelf", "bottle_shelf":
			var colors := ["red", "teal", "amber", "blue", "green", "pink"]
			var vertical := h > w
			var length := h if vertical else w
			for i in range(3, length - 4, 5):
				var color := _c(colors[(i / 5) % colors.size()])
				if vertical:
					c.rect(3, i, w - 6, 3, color)
				else:
					c.rect(i, 3, 3, h - 6, color)
		"crate", "crates", "pallet":
			var step := 12 if kind != "pallet" else 6
			for x in range(step, w - 2, step):
				c.vline(x, 1, h - 2, t[0])
			if kind != "pallet":
				for y in range(step, h - 2, step):
					c.hline(1, y, w - 2, t[0])
				c.hline(1, 2, w - 2, _c("cream"))
		"bed", "hospital_bed", "bunk":
			FurnitureArt7.bed(c, kind, w, h)
		"nightstand", "cabinet", "wardrobe", "locker":
			var vertical := h > w * 2
			if vertical:
				for y in range(h / 5, h - 2, maxi(h / 5, 6)):
					c.hline(1, y, w - 2, ink)
					c.px(w / 2, y - 3, _c("amber"))
			else:
				c.vline(w / 2, 1, h - 2, t[0])
				c.px(w / 2 - 2, h / 2, _c("amber"))
				c.px(w / 2 + 2, h / 2, _c("amber"))
			if kind == "cabinet":
				c.rect(w / 2 - 2, 3, 4, 2, _c("red"))
				c.rect(w / 2 - 1, 2, 2, 4, _c("red"))
		"sofa", "seats", "bench":
			if kind == "bench":
				var along := w >= h
				for i in range(3, (h if along else w) - 2, 4):
					if along:
						c.hline(1, i, w - 2, t[0])
					else:
						c.vline(i, 1, h - 2, t[0])
			else:
				c.rect(1, 1, w - 2, 3, t[0])               # encosto
				for x in range(8 if kind == "seats" else w / 3, w - 2, 8 if kind == "seats" else maxi(w / 3, 4)):
					c.vline(x, 4, h - 5, t[0])
		"table", "desk", "briefing_table":
			c.frame(2, 2, w - 4, h - 4, t[2])
			if kind == "desk":
				c.rect(w / 2 - 6, 4, 12, 7, _c("slate"))    # computador
				c.rect(w / 2 - 5, 5, 10, 4, _c("neon_cyan"))
				c.rect(4, h - 8, 8, 5, _c("white"))         # papéis
			elif kind == "briefing_table":
				c.rect(w / 2 - 14, h / 2 - 8, 28, 16, _c("blue"))
				c.px(w / 2 - 6, h / 2 - 2, _c("neon_cyan"))
				c.px(w / 2 + 5, h / 2 + 3, _c("red"))
			else:
				c.rect(w / 2 - 3, h / 2 - 2, 6, 4, _c("white"))  # prato
		"stove":
			for ix in 2:
				for iy in 2:
					c.ellipse(4 + ix * (w / 2 - 2), 4 + iy * (h / 2 - 3), 9, 9, _c("shadow"))
					c.px(8 + ix * (w / 2 - 2), 8 + iy * (h / 2 - 3), _c("orange"))
		"fridge", "water_cooler":
			c.hline(1, h / 3, w - 2, t[0])
			c.vline(w - 4, 3, h / 3 - 4, _c("slate"))
			if kind == "water_cooler":
				c.rect(3, 2, w - 6, h / 3 - 3, _c("sky"))
		"pool_table":
			c.frame(0, 0, w, h, ink)
			c.frame(1, 1, w - 2, h - 2, _c("brown"))
			c.frame(2, 2, w - 4, h - 4, _c("brown"))
			for p in [Vector2i(3, 3), Vector2i(w / 2, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4), Vector2i(w / 2, h - 4), Vector2i(w - 4, h - 4)]:
				c.rect(p.x - 1, p.y - 1, 3, 3, ink)
			c.px(w / 3, h / 2, _c("white"))
			c.px(w * 2 / 3, h / 2 - 3, _c("red"))
			c.px(w * 2 / 3 + 3, h / 2 + 2, _c("amber"))
		"jukebox", "popcorn":
			c.rect(3, 3, w - 6, h / 2 - 2, _c("amber") if kind == "jukebox" else _c("cream"))
			c.hline(3, h / 2 + 3, w - 6, _c("neon_cyan") if kind == "jukebox" else _c("white"))
			c.hline(3, h / 2 + 6, w - 6, _c("magenta") if kind == "jukebox" else _c("amber"))
		"dj_booth":
			c.ellipse(6, h / 2 - 9, 18, 18, _c("slate"))
			c.ellipse(w - 24, h / 2 - 9, 18, 18, _c("slate"))
			c.px(14, h / 2, _c("white"))
			c.px(w - 16, h / 2, _c("white"))
			for x in range(w / 2 - 12, w / 2 + 12, 4):
				c.rect(x, h / 2 - 4, 2, 8, _c("neon_cyan") if (x / 4) % 2 == 0 else _c("magenta"))
		"speaker":
			c.ellipse(4, 4, w - 8, w - 8, _c("slate"))
			c.ellipse(w / 2 - 4, h - w + 6, 8, 8, _c("slate"))
			c.px(w / 2, w / 2, _c("gray"))
		"vault":
			c.ellipse(w / 2 - h / 3, h / 6, h * 2 / 3, h * 2 / 3, _c("slate"))
			c.ellipse(w / 2 - h / 6, h / 3, h / 3, h / 3, _c("light"))
			c.hline(w / 2 - h / 3, h / 2, h * 2 / 3, ink)
			c.vline(w / 2, h / 6, h * 2 / 3, ink)
		"board", "poster":
			for x in range(4, w - 8, 14):
				c.rect(x, 3, 9, h - 6, _c("white") if kind == "board" else _c("red"))
				c.px(x + 4, 5, ink)
		"screen_divider":
			c.vline(w / 2, 1, h - 2, _c("white"))
		"car_lift":
			c.rect(4, 4, 6, h - 8, _c("amber"))
			c.rect(w - 10, 4, 6, h - 8, _c("amber"))
			var car := Palette.tone("teal")
			c.rect(14, 16, w - 28, h - 32, car[1])
			c.rect(18, 30, w - 36, 16, _c("navy"))
			c.rect(18, h - 52, w - 36, 12, _c("navy"))
			c.frame(14, 16, w - 28, h - 32, ink)
		"toolbox", "chest", "basket":
			c.hline(1, h / 3, w - 2, ink)
			c.rect(w / 2 - 3, h / 3 - 2, 6, 4, _c("amber"))
		"movie_screen", "wall_screen":
			c.rect(2, 2, w - 4, h - 4, _c("ice") if kind == "movie_screen" else _c("navy"))
			if kind == "wall_screen":
				for x in range(8, w - 12, 22):
					c.rect(x, 4, 14, h - 8, _c("neon_cyan") if (x / 22) % 2 == 0 else _c("neon_green"))
		"ring":
			c.rect(4, 4, w - 8, h - 8, _c("light"))
			for inset in [4, 8]:
				c.frame(inset, inset, w - inset * 2, h - inset * 2, _c("red") if inset == 4 else _c("white"))
			for p in [Vector2i(2, 2), Vector2i(w - 7, 2), Vector2i(2, h - 7), Vector2i(w - 7, h - 7)]:
				c.rect(p.x, p.y, 5, 5, _c("slate"))
		"treadmill":
			c.rect(4, h / 4, w - 8, h * 3 / 4 - 4, _c("ink"))
			for y in range(h / 4 + 3, h - 5, 5):
				c.hline(5, y, w - 10, _c("slate"))
			c.rect(4, 3, w - 8, h / 4 - 5, _c("neon_cyan"))
		"weights":
			for x in range(6, w - 10, 16):
				c.rect(x, 3, 3, h - 6, _c("slate"))
				c.rect(x + 3, h / 2 - 1, 6, 2, _c("gray"))
				c.rect(x + 9, 3, 3, h - 6, _c("slate"))
		"tv":
			c.rect(3, 3, w - 6, h - 6, _c("sky"))
			c.px(5, 5, _c("ice"))
		"forklift":
			c.rect(4, h / 3, w - 8, h * 2 / 3 - 4, _c("orange"))
			c.rect(8, h / 3 + 6, w - 16, h / 4, _c("navy"))
			c.rect(6, 2, 4, h / 3, _c("slate"))
			c.rect(w - 10, 2, 4, h / 3, _c("slate"))
			c.frame(4, h / 3, w - 8, h * 2 / 3 - 4, ink)
		"computer", "monitor":
			c.rect(3, 3, w - 6, maxi(h / 2, 4), _c("navy"))
			c.rect(5, 5, w - 10, maxi(h / 2 - 4, 2), _c("neon_green") if kind == "monitor" else _c("sky"))
			c.rect(3, h - 6, w - 6, 3, _c("slate"))
		"file_cabinet":
			for y in range(4, h - 4, 10):
				c.rect(3, y, w - 6, 8, t[2])
				c.rect(w / 2 - 3, y + 3, 6, 2, _c("slate"))
		"cart":
			c.rect(3, 3, w - 6, h / 2 - 2, _c("white"))
			c.rect(w / 2 - 2, 5, 4, 3, _c("red"))
			c.rect(3, h / 2 + 2, w - 6, h / 2 - 5, _c("slate"))
		"xray":
			c.ellipse(w / 2 - 14, h / 2 - 14, 28, 28, _c("slate"))
			c.ellipse(w / 2 - 9, h / 2 - 9, 18, 18, _c("navy"))
			c.rect(3, 3, 6, 3, _c("neon_green"))
		"toilet":
			c.ellipse(w / 2 - 6, h / 2 - 3, 12, 14, _c("white"))
			c.rect(w / 2 - 7, 3, 14, 6, _c("light"))
		"bathtub":
			c.ellipse(4, 4, w - 8, h - 8, _c("ice"))
			c.ellipse(7, 7, w - 14, h - 14, _c("sky"))
		"bookshelf":
			var tones := ["red", "teal", "amber", "blue", "green", "purple"]
			for x in range(3, w - 4, 4):
				c.rect(x, 3, 3, h / 2 - 3, _c(tones[(x / 4) % tones.size()]))
				c.rect(x, h / 2 + 2, 3, h / 2 - 5, _c(tones[(x / 4 + 3) % tones.size()]))
		"vending":
			c.rect(3, 3, w - 6, h - 12, _c("ink"))
			for y in range(5, h - 16, 8):
				c.rect(5, y, w - 10, 3, _c("amber") if y % 16 == 5 else _c("teal"))
			c.rect(w / 2 - 4, h - 8, 8, 3, _c("slate"))
		"sink":
			c.ellipse(w / 2 - 8, h / 2 - 5, 16, 10, _c("light"))
			c.rect(w / 2 - 1, 3, 2, 6, _c("gray"))
		"curtain":
			for x in range(2, w - 2, 5):
				c.vline(x, 1, h - 2, t[2])
		"trash":
			c.ellipse(2, 2, w - 4, h - 4, _c("slate"))
			c.ellipse(5, 5, w - 10, h - 10, _c("shadow"))
		"washer", "washer_secret":
			var d := mini(w, h) - 14
			c.ellipse(w / 2 - d / 2, h / 2 - d / 2 + 2, d, d, _c("slate"))
			c.ellipse(w / 2 - d / 2 + 3, h / 2 - d / 2 + 5, d - 6, d - 6, _c("sky") if kind == "washer" else _c("neon_cyan"))
			c.rect(4, 3, 6, 3, _c("neon_green"))
	return c
