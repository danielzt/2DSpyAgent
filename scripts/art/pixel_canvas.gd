extends RefCounted
## Tela de pixel art: um envelope de Image com as operações usadas pelas fábricas de
## sprites e tiles. Coordenadas em texels (1 texel = 2 px do mundo).

const Palette := preload("res://scripts/art/palette.gd")

var image: Image
var width: int
var height: int


func _init(p_width: int = 1, p_height: int = 1) -> void:
	width = maxi(p_width, 1)
	height = maxi(p_height, 1)
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func px(x: int, y: int, color: Color) -> void:
	if inside(x, y):
		image.set_pixel(x, y, color)


func get_px(x: int, y: int) -> Color:
	return image.get_pixel(x, y) if inside(x, y) else Color(0, 0, 0, 0)


func is_empty_at(x: int, y: int) -> bool:
	return get_px(x, y).a < 0.01


func fill(color: Color) -> void:
	image.fill(color)


func rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, width, height))
	if r.size.x > 0 and r.size.y > 0:
		image.fill_rect(r, color)


## Retângulo com mistura (para sombras translúcidas sobre o que já foi desenhado).
func blend_rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, height)):
		for xx in range(maxi(x, 0), mini(x + w, width)):
			image.set_pixel(xx, yy, image.get_pixel(xx, yy).blend(color))


## Moldura de 1 texel.
func frame(x: int, y: int, w: int, h: int, color: Color) -> void:
	rect(x, y, w, 1, color)
	rect(x, y + h - 1, w, 1, color)
	rect(x, y, 1, h, color)
	rect(x + w - 1, y, 1, h, color)


func hline(x: int, y: int, length: int, color: Color) -> void:
	rect(x, y, length, 1, color)


func vline(x: int, y: int, length: int, color: Color) -> void:
	rect(x, y, 1, length, color)


## Elipse cheia dentro do retângulo dado.
func ellipse(x: int, y: int, w: int, h: int, color: Color) -> void:
	var rx := w / 2.0
	var ry := h / 2.0
	for yy in h:
		for xx in w:
			var dx := (xx + 0.5 - rx) / rx
			var dy := (yy + 0.5 - ry) / ry
			if dx * dx + dy * dy <= 1.0:
				px(x + xx, y + yy, color)


## Desenha um sprite escrito como texto: uma linha por fileira, uma letra por texel.
## "." (ou letra fora da legenda) fica transparente.
func stamp(rows: Array, legend: Dictionary, ox: int = 0, oy: int = 0) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var letter := row[x]
			if legend.has(letter):
				px(ox + x, oy + y, legend[letter])


## Copia outra tela por cima desta, respeitando a transparência.
func blit(other: RefCounted, x: int, y: int) -> void:
	image.blend_rect(other.image, Rect2i(0, 0, other.width, other.height), Vector2i(x, y))


## Preenche o retângulo repetindo um tile.
func tile_fill(tile: RefCounted, x: int, y: int, w: int, h: int) -> void:
	var ty := 0
	while ty < h:
		var th := mini(tile.height, h - ty)
		var tx := 0
		while tx < w:
			var tw := mini(tile.width, w - tx)
			image.blit_rect(tile.image, Rect2i(0, 0, tw, th), Vector2i(x + tx, y + ty))
			tx += tile.width
		ty += tile.height


## Contorno de 1 texel em volta de tudo que é opaco (vizinhança de 4).
func outline(color: Color) -> void:
	var marks: Array[Vector2i] = []
	for y in height:
		for x in width:
			if not is_empty_at(x, y):
				continue
			if not is_empty_at(x - 1, y) or not is_empty_at(x + 1, y) \
					or not is_empty_at(x, y - 1) or not is_empty_at(x, y + 1):
				marks.append(Vector2i(x, y))
	for m in marks:
		image.set_pixel(m.x, m.y, color)


## Salpica `color` sobre os texels opacos, com a densidade dada (0 a 1). Determinístico.
func speckle(color: Color, density: float, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for y in height:
		for x in width:
			if rng.randf() < density and not is_empty_at(x, y):
				image.set_pixel(x, y, color)


## Cópia espelhada na horizontal.
func flipped_h() -> RefCounted:
	var result: RefCounted = get_script().new(width, height)
	result.image.copy_from(image)
	result.image.flip_x()
	return result


func duplicate_canvas() -> RefCounted:
	var result: RefCounted = get_script().new(width, height)
	result.image.copy_from(image)
	return result


## Cópia girada (rad, sentido horário na tela) dentro de uma tela quadrada de lado `side`,
## amostrando o texel mais próximo. Usada para pré-gerar as direções dos carros.
func rotated(angle: float, side: int) -> RefCounted:
	var result: RefCounted = get_script().new(side, side)
	var c := cos(angle)
	var s := sin(angle)
	var half := side / 2.0
	for y in side:
		for x in side:
			var dx := x + 0.5 - half
			var dy := y + 0.5 - half
			# rotação inversa para achar o texel de origem
			var sx := int(floor(dx * c + dy * s + width / 2.0))
			var sy := int(floor(-dx * s + dy * c + height / 2.0))
			if inside(sx, sy):
				result.image.set_pixel(x, y, image.get_pixel(sx, sy))
	return result


## Silhueta: todos os texels opacos pintados de uma cor só.
func silhouette(color: Color) -> RefCounted:
	var result: RefCounted = get_script().new(width, height)
	for y in height:
		for x in width:
			if not is_empty_at(x, y):
				result.image.set_pixel(x, y, color)
	return result


## Cópia ampliada por um fator inteiro (texel mais próximo).
func scaled(factor: int) -> RefCounted:
	var result: RefCounted = get_script().new(width * factor, height * factor)
	result.image.copy_from(image)
	result.image.resize(width * factor, height * factor, Image.INTERPOLATE_NEAREST)
	return result


## Cores opacas usadas (sem a opacidade), para testes.
func used_colors() -> Array[Color]:
	var seen := {}
	for y in height:
		for x in width:
			var c := image.get_pixel(x, y)
			if c.a >= 0.01:
				seen[Color(c.r, c.g, c.b).to_html(false)] = true
	var result: Array[Color] = []
	for key in seen:
		result.append(Color(key))
	return result


## True se todos os texels opacos usam cores da paleta.
func only_palette_colors() -> bool:
	for c in used_colors():
		if not Palette.contains(c):
			return false
	return true


func opaque_count() -> int:
	var count := 0
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a >= 0.01:
				count += 1
	return count


func to_texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)
