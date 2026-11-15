extends RefCounted
## Fonte pixel própria (5x7 + acentos), desenhada por código. Só maiúsculas: o texto é
## convertido antes de desenhar. Usada nos letreiros do mundo e no HUD.

const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const GLYPH_W := 5
const GLYPH_H := 7
const ACCENT_ROWS := 2      # fileiras acima da letra, para acentos
const DESCENT_ROWS := 1     # fileira abaixo, para cedilha e vírgula
const CELL_H := ACCENT_ROWS + GLYPH_H + DESCENT_ROWS
const ADVANCE := GLYPH_W + 1
const LINE_GAP := 2

## Cada letra: 7 fileiras de 5 bits, de cima para baixo.
const GLYPHS := {
	"A": "01110 10001 10001 11111 10001 10001 10001",
	"B": "11110 10001 10001 11110 10001 10001 11110",
	"C": "01110 10001 10000 10000 10000 10001 01110",
	"D": "11110 10001 10001 10001 10001 10001 11110",
	"E": "11111 10000 10000 11110 10000 10000 11111",
	"F": "11111 10000 10000 11110 10000 10000 10000",
	"G": "01110 10001 10000 10111 10001 10001 01111",
	"H": "10001 10001 10001 11111 10001 10001 10001",
	"I": "01110 00100 00100 00100 00100 00100 01110",
	"J": "00111 00010 00010 00010 00010 10010 01100",
	"K": "10001 10010 10100 11000 10100 10010 10001",
	"L": "10000 10000 10000 10000 10000 10000 11111",
	"M": "10001 11011 10101 10101 10001 10001 10001",
	"N": "10001 11001 10101 10011 10001 10001 10001",
	"O": "01110 10001 10001 10001 10001 10001 01110",
	"P": "11110 10001 10001 11110 10000 10000 10000",
	"Q": "01110 10001 10001 10001 10101 10010 01101",
	"R": "11110 10001 10001 11110 10100 10010 10001",
	"S": "01111 10000 10000 01110 00001 00001 11110",
	"T": "11111 00100 00100 00100 00100 00100 00100",
	"U": "10001 10001 10001 10001 10001 10001 01110",
	"V": "10001 10001 10001 10001 10001 01010 00100",
	"W": "10001 10001 10001 10101 10101 11011 10001",
	"X": "10001 10001 01010 00100 01010 10001 10001",
	"Y": "10001 10001 01010 00100 00100 00100 00100",
	"Z": "11111 00001 00010 00100 01000 10000 11111",
	"0": "01110 10001 10011 10101 11001 10001 01110",
	"1": "00100 01100 00100 00100 00100 00100 01110",
	"2": "01110 10001 00001 00010 00100 01000 11111",
	"3": "11110 00001 00001 01110 00001 00001 11110",
	"4": "00010 00110 01010 10010 11111 00010 00010",
	"5": "11111 10000 11110 00001 00001 10001 01110",
	"6": "00110 01000 10000 11110 10001 10001 01110",
	"7": "11111 00001 00010 00100 01000 01000 01000",
	"8": "01110 10001 10001 01110 10001 10001 01110",
	"9": "01110 10001 10001 01111 00001 00010 01100",
	" ": "00000 00000 00000 00000 00000 00000 00000",
	".": "00000 00000 00000 00000 00000 01100 01100",
	",": "00000 00000 00000 00000 01100 00100 01000",
	":": "00000 01100 01100 00000 01100 01100 00000",
	";": "00000 01100 01100 00000 01100 00100 01000",
	"!": "00100 00100 00100 00100 00100 00000 00100",
	"?": "01110 10001 00001 00010 00100 00000 00100",
	"-": "00000 00000 00000 11111 00000 00000 00000",
	"—": "00000 00000 00000 11111 00000 00000 00000",
	"_": "00000 00000 00000 00000 00000 00000 11111",
	"+": "00000 00100 00100 11111 00100 00100 00000",
	"/": "00001 00001 00010 00100 01000 10000 10000",
	"$": "00100 01111 10100 01110 00101 11110 00100",
	"%": "11001 11001 00010 00100 01000 10011 10011",
	"(": "00010 00100 01000 01000 01000 00100 00010",
	")": "01000 00100 00010 00010 00010 00100 01000",
	"[": "01110 01000 01000 01000 01000 01000 01110",
	"]": "01110 00010 00010 00010 00010 00010 01110",
	"'": "00100 00100 01000 00000 00000 00000 00000",
	"\"": "01010 01010 00000 00000 00000 00000 00000",
	"•": "00000 00000 01110 01110 01110 00000 00000",
	"×": "00000 10001 01010 00100 01010 10001 00000",
	"=": "00000 00000 11111 00000 11111 00000 00000",
	"<": "00010 00100 01000 10000 01000 00100 00010",
	">": "01000 00100 00010 00001 00010 00100 01000",
	"#": "01010 01010 11111 01010 11111 01010 01010",
	"*": "00000 10101 01110 11111 01110 10101 00000",
	"…": "00000 00000 00000 00000 00000 00000 10101",
}

## Letra acentuada -> [letra base, acento].
const ACCENTED := {
	"Á": ["A", "acute"], "À": ["A", "grave"], "Â": ["A", "circumflex"], "Ã": ["A", "tilde"],
	"É": ["E", "acute"], "Ê": ["E", "circumflex"],
	"Í": ["I", "acute"],
	"Ó": ["O", "acute"], "Ô": ["O", "circumflex"], "Õ": ["O", "tilde"],
	"Ú": ["U", "acute"], "Ü": ["U", "acute"],
	"Ç": ["C", "cedilla"],
}

## Acentos: 2 fileiras acima da letra (a cedilha fica na fileira de baixo).
const ACCENT_BITS := {
	"acute": ["00010", "00100"],
	"grave": ["01000", "00100"],
	"circumflex": ["00100", "01010"],
	"tilde": ["01001", "10110"],
}
const CEDILLA_BITS := "00100"
const UNKNOWN := "11111 10001 10001 10001 10001 10001 11111"


## Texto como será desenhado (maiúsculas; o resto fica igual).
static func normalize(text: String) -> String:
	return text.to_upper()


static func has_glyph(letter: String) -> bool:
	return GLYPHS.has(letter) or ACCENTED.has(letter)


## Tamanho em texels de um texto (pode ter várias linhas).
static func measure(text: String) -> Vector2i:
	var lines := normalize(text).split("\n")
	var widest := 0
	for line in lines:
		widest = maxi(widest, line.length() * ADVANCE - 1)
	return Vector2i(maxi(widest, 1), lines.size() * CELL_H + (lines.size() - 1) * LINE_GAP)


## Desenha o texto na tela, com o canto superior esquerdo em (x, y).
## `align`: 0 = esquerda, 1 = centro, 2 = direita (dentro da largura do texto mais largo).
static func draw_text(canvas: RefCounted, text: String, x: int, y: int, color: Color, align := 0) -> void:
	var lines := normalize(text).split("\n")
	var total := measure(text)
	for i in lines.size():
		var line: String = lines[i]
		var line_w := line.length() * ADVANCE - 1
		var lx := x
		if align == 1:
			lx += (total.x - line_w) / 2
		elif align == 2:
			lx += total.x - line_w
		var ly := y + i * (CELL_H + LINE_GAP)
		for j in line.length():
			_draw_glyph(canvas, line[j], lx + j * ADVANCE, ly, color)


static func _draw_glyph(canvas: RefCounted, letter: String, x: int, y: int, color: Color) -> void:
	var base := letter
	var accent := ""
	if ACCENTED.has(letter):
		base = ACCENTED[letter][0]
		accent = ACCENTED[letter][1]
	var bits: String = GLYPHS.get(base, UNKNOWN)
	var rows := bits.split(" ")
	for r in rows.size():
		_draw_bits(canvas, rows[r], x, y + ACCENT_ROWS + r, color)
	if accent == "cedilla":
		_draw_bits(canvas, CEDILLA_BITS, x, y + ACCENT_ROWS + GLYPH_H, color)
	elif accent != "":
		var marks: Array = ACCENT_BITS[accent]
		for r in marks.size():
			_draw_bits(canvas, marks[r], x, y + r, color)


static func _draw_bits(canvas: RefCounted, bits: String, x: int, y: int, color: Color) -> void:
	for i in bits.length():
		if bits[i] == "1":
			canvas.px(x + i, y, color)


## Tela nova com o texto, com `pad` texels de margem e contorno opcional.
static func render(text: String, color: Color, outline_color := Color(0, 0, 0, 0), pad := 1, align := 0) -> RefCounted:
	var size := measure(text)
	var canvas: RefCounted = PixelCanvas.new(size.x + pad * 2, size.y + pad * 2)
	draw_text(canvas, text, pad, pad, color, align)
	if outline_color.a > 0.0:
		canvas.outline(outline_color)
	return canvas
