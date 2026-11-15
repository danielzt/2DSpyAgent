extends RefCounted
## Cena da tela de título (Fase 5): a cidade à noite em pixel art por código, com céu em
## degraus, estrelas, lua, duas camadas de prédios com janelas acesas, letreiros de néon e a
## avenida. Determinística (seed fixa). 1 texel = 2 px da tela, como o resto do jogo.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const WIDTH := 640
const HEIGHT := 360
const GROUND_Y := 308
## Faixas do céu, de cima para baixo: cor e altura em texels (com pontilhado entre faixas).
const SKY_BANDS := [["ink", 50], ["navy", 50], ["purple", 60], ["wine", 50], ["magenta", 40]]
const WINDOW_COLORS := ["amber", "amber", "cream", "cream", "neon_cyan", "orange"]


static func canvas(p_seed := 1984) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var c := PixelCanvas.new(WIDTH, HEIGHT)
	_sky(c)
	_stars(c, rng)
	_moon(c)
	_skyline(c, rng, "navy", 70, 140, false, 0)
	_skyline(c, rng, "ink", 100, 220, true, 1)
	_signs(c)
	_street(c)
	return c


static func _sky(c: RefCounted) -> void:
	var y := 0
	for i in SKY_BANDS.size():
		var band: Array = SKY_BANDS[i]
		var color := Palette.get_color(band[0])
		for row in band[1]:
			c.hline(0, y + row, WIDTH, color)
		# pontilhado com a cor da faixa de baixo (transição em degrau)
		if i + 1 < SKY_BANDS.size():
			var next := Palette.get_color((SKY_BANDS[i + 1] as Array)[0])
			var edge: int = y + int(band[1])
			for dy in 4:
				for x in range(dy % 2, WIDTH, 2):
					if dy < 2:
						c.px(x, edge - 1 - dy, next)
		y += int(band[1])
	c.rect(0, y, WIDTH, HEIGHT - y, Palette.get_color("magenta"))


static func _stars(c: RefCounted, rng: RandomNumberGenerator) -> void:
	var colors := ["white", "cream", "ice"]
	for i in 90:
		var x := rng.randi_range(0, WIDTH - 1)
		var y := rng.randi_range(0, 190)
		c.px(x, y, Palette.get_color(colors[rng.randi_range(0, 2)]))
	for i in 6:  # estrelas maiores, em cruz
		var x := rng.randi_range(8, WIDTH - 9)
		var y := rng.randi_range(6, 120)
		var color := Palette.get_color("white")
		c.px(x, y, color)
		c.px(x - 1, y, Palette.get_color("ice"))
		c.px(x + 1, y, Palette.get_color("ice"))
		c.px(x, y - 1, Palette.get_color("ice"))
		c.px(x, y + 1, Palette.get_color("ice"))


static func _moon(c: RefCounted) -> void:
	var cx := 500
	var cy := 82
	c.ellipse(cx - 20, cy - 20, 40, 40, Palette.get_color("ice"))
	c.ellipse(cx - 18, cy - 18, 34, 34, Palette.get_color("cream"))
	c.ellipse(cx - 8, cy - 6, 8, 8, Palette.get_color("light"))
	c.ellipse(cx + 4, cy + 4, 6, 6, Palette.get_color("light"))
	c.ellipse(cx - 12, cy + 6, 4, 4, Palette.get_color("light"))


## Uma camada de prédios. `lit`: com janelas acesas. `tone`: cor da silhueta.
static func _skyline(c: RefCounted, rng: RandomNumberGenerator, tone: String, min_h: int, max_h: int, lit: bool, layer: int) -> void:
	var x := -10 + layer * 14
	var body := Palette.get_color(tone)
	var edge := Palette.get_color("shadow" if tone == "ink" else "purple")
	while x < WIDTH:
		var w := rng.randi_range(26, 58)
		var h := rng.randi_range(min_h, max_h)
		var top := GROUND_Y - h
		c.rect(x, top, w, h + 2, body)
		c.hline(x, top, w, edge)  # luz de cima
		if rng.randf() < 0.35:   # caixa-d'água ou antena
			var ax := x + rng.randi_range(4, w - 6)
			c.rect(ax, top - 8, 2, 8, body)
			c.px(ax, top - 9, Palette.get_color("red"))
		if lit:
			_windows(c, rng, x, top, w, h)
		x += w + rng.randi_range(0, 3)


static func _windows(c: RefCounted, rng: RandomNumberGenerator, x: int, top: int, w: int, h: int) -> void:
	var dark := Palette.get_color("shadow")
	for wy in range(top + 6, top + h - 8, 7):
		for wx in range(x + 4, x + w - 5, 6):
			if rng.randf() < 0.42:
				var color := Palette.get_color(WINDOW_COLORS[rng.randi_range(0, WINDOW_COLORS.size() - 1)])
				c.rect(wx, wy, 3, 4, color)
			elif rng.randf() < 0.6:
				c.rect(wx, wy, 3, 4, dark)


## Dois letreiros de néon grandes sobre prédios da frente.
static func _signs(c: RefCounted) -> void:
	var specs := [[70, 150, 54, 14, "magenta", "pink"], [388, 128, 62, 14, "neon_cyan", "ice"]]
	for s in specs:
		var plate := Palette.get_color("ink")
		c.rect(s[0] - 2, s[1] - 2, s[2] + 4, s[3] + 4, plate)
		c.rect(s[0], s[1], s[2], s[3], Palette.get_color(s[4]))
		c.hline(s[0], s[1], s[2], Palette.get_color(s[5]))
		c.hline(s[0], s[1] + s[3] - 1, s[2], Palette.get_color(s[5]))
		for i in range(4, s[2] - 4, 6):  # traços que sugerem letras
			c.rect(s[0] + i, s[1] + 4, 3, s[3] - 8, Palette.get_color("white"))


static func _street(c: RefCounted) -> void:
	c.rect(0, GROUND_Y, WIDTH, 10, Palette.get_color("slate"))
	c.hline(0, GROUND_Y, WIDTH, Palette.get_color("gray"))
	c.rect(0, GROUND_Y + 10, WIDTH, HEIGHT - GROUND_Y - 10, Palette.get_color("asphalt"))
	c.hline(0, GROUND_Y + 10, WIDTH, Palette.get_color("ink"))
	for x in range(6, WIDTH, 40):  # faixa central tracejada
		c.rect(x, GROUND_Y + 30, 20, 2, Palette.get_color("amber"))
	# reflexo de néon no asfalto
	for x in range(0, WIDTH, 3):
		if (x / 3) % 4 == 0:
			c.px(x, GROUND_Y + 14, Palette.get_color("magenta"))
			c.px(x + 1, GROUND_Y + 18, Palette.get_color("neon_cyan"))
