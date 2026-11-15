extends RefCounted
## Paleta fixa do jogo (32 cores) e rampas por material.
## Regra de arte: toda cor desenhada sai daqui. Ver docs/redesign-visual.md.

const COLORS := {
	"ink": Color("1a1423"),            # tinta: contorno e sombra projetada
	"shadow": Color("3a2e4d"),
	"slate": Color("5a5770"),
	"gray": Color("8f8fa3"),
	"light": Color("c9c9d6"),
	"white": Color("f6f3e8"),
	"asphalt": Color("3d4352"),
	"asphalt_light": Color("555d6e"),
	"wine": Color("6e2338"),
	"red": Color("d1344a"),
	"orange": Color("f0803c"),
	"amber": Color("f7c548"),
	"cream": Color("f9e6a8"),
	"brown_dark": Color("4f2f2a"),
	"brown": Color("8a5638"),
	"sand": Color("c99a66"),
	"skin_light": Color("e8b796"),
	"skin_dark": Color("a8684a"),
	"green_dark": Color("1f4d3a"),
	"green": Color("3f8f4a"),
	"lime": Color("8fce5a"),
	"teal": Color("26a69a"),
	"navy": Color("232b5c"),
	"blue": Color("3465c4"),
	"sky": Color("5fb4f0"),
	"ice": Color("bfe6f5"),
	"purple": Color("6b3fa0"),
	"magenta": Color("d13fa6"),
	"pink": Color("f58fb8"),
	"neon_cyan": Color("3ff0e0"),
	"neon_green": Color("7dff6a"),
	"concrete": Color("b8b0a0"),
}

## Letra -> cor, usada nos sprites escritos como texto. "." é transparente.
## Os dígitos 1 a 6 são reservados para cores trocáveis (roupa, cabelo, lataria).
const LEGEND := {
	"k": "ink", "h": "shadow", "s": "slate", "g": "gray", "l": "light", "w": "white",
	"a": "asphalt", "A": "asphalt_light", "v": "wine", "r": "red", "o": "orange", "y": "amber",
	"c": "cream", "D": "brown_dark", "b": "brown", "n": "sand", "f": "skin_light", "F": "skin_dark",
	"G": "green_dark", "e": "green", "L": "lime", "t": "teal", "N": "navy", "u": "blue",
	"S": "sky", "i": "ice", "p": "purple", "m": "magenta", "P": "pink", "C": "neon_cyan",
	"E": "neon_green", "x": "concrete",
}

## Rampas [sombra, base, luz] por material.
const RAMPS := {
	"asphalt": ["ink", "asphalt", "asphalt_light"],
	"sidewalk": ["slate", "gray", "light"],
	"brick": ["wine", "red", "skin_dark"],
	"plaster": ["gray", "concrete", "cream"],
	"wood": ["brown_dark", "brown", "sand"],
	"tile_roof": ["wine", "orange", "amber"],
	"slab_roof": ["shadow", "slate", "gray"],
	"plant": ["green_dark", "green", "lime"],
	"water": ["navy", "blue", "sky"],
	"glass": ["navy", "sky", "ice"],
	"metal": ["slate", "gray", "white"],
	"dirt": ["brown", "sand", "cream"],
}

## Cores de lataria, roupa etc.: [sombra, base, luz].
const TONES := {
	"red": ["wine", "red", "pink"],
	"blue": ["navy", "blue", "sky"],
	"green": ["green_dark", "green", "lime"],
	"yellow": ["orange", "amber", "cream"],
	"white": ["gray", "light", "white"],
	"black": ["ink", "shadow", "slate"],
	"teal": ["navy", "teal", "ice"],
	"purple": ["shadow", "purple", "magenta"],
	"orange": ["wine", "orange", "amber"],
	"brown": ["brown_dark", "brown", "sand"],
	"pink": ["purple", "pink", "white"],
	"gray": ["shadow", "slate", "gray"],
	# Tons de parede dos bairros (Fase 2).
	"concrete": ["gray", "concrete", "cream"],
	"silver": ["slate", "gray", "light"],
	"snow": ["light", "white", "white"],
	"cream": ["sand", "cream", "white"],
	"clay": ["brown", "skin_dark", "skin_light"],
	"sand": ["brown", "sand", "cream"],
	"ice": ["sky", "ice", "white"],
	"wine": ["ink", "wine", "red"],
	"navy": ["ink", "navy", "blue"],
}

## Opacidade da sombra projetada (cor tinta).
const SHADOW_ALPHA := 0.35


static func get_color(color_name: String) -> Color:
	return COLORS[color_name]


static func has_color(color_name: String) -> bool:
	return COLORS.has(color_name)


static func names() -> Array:
	return COLORS.keys()


## [sombra, base, luz] de um tom, já como cores.
static func tone(tone_name: String) -> Array[Color]:
	var result: Array[Color] = []
	for n in TONES[tone_name]:
		result.append(COLORS[n])
	return result


static func ramp(material: String) -> Array[Color]:
	var result: Array[Color] = []
	for n in RAMPS[material]:
		result.append(COLORS[n])
	return result


## Cor tinta com a opacidade de sombra projetada.
static func cast_shadow() -> Color:
	var c: Color = COLORS["ink"]
	return Color(c.r, c.g, c.b, SHADOW_ALPHA)


## True se a cor (ignorando a opacidade) pertence à paleta.
static func contains(color: Color) -> bool:
	for n in COLORS:
		var c: Color = COLORS[n]
		if absf(c.r - color.r) < 0.004 and absf(c.g - color.g) < 0.004 and absf(c.b - color.b) < 0.004:
			return true
	return false


## Legenda padrão (letra -> cor) com substituições, ex.: {"1": "red", "2": "wine"}.
static func legend(overrides := {}) -> Dictionary:
	var result := {}
	for letter in LEGEND:
		result[letter] = COLORS[LEGEND[letter]]
	for letter in overrides:
		var value: Variant = overrides[letter]
		result[letter] = COLORS[value] if value is String else value
	return result
