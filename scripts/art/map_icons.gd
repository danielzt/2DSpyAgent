extends RefCounted
## Ícones do mapa (Fase 5): um glifo 7x7 por categoria de prédio sobre uma placa 9x9 de tinta.
## Vários tipos de prédio dividem o mesmo glifo (restaurante e lanchonete, casa e apartamento...).

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const SIDE := 9

## Tipo de prédio -> glifo.
const GLYPH_OF := {
	"hq": "hq", "police": "law", "hospital": "cross", "bank": "coin", "hotel": "bed",
	"restaurant": "fork", "diner": "fork", "bar": "glass", "club": "glass",
	"agent_store": "bag", "armory": "gun", "pharmacy": "pill", "market": "bag",
	"workshop": "tool", "gas_station": "tool", "cinema": "film", "gym": "weight",
	"newspaper": "paper", "office": "case", "apartment": "home", "house": "home",
	"warehouse": "box", "farm": "barn", "farm_store": "bag",
}

## Nome de cada glifo na legenda do mapa.
const LABELS := {
	"hq": "QG", "law": "Delegacia", "cross": "Hospital", "coin": "Banco", "bed": "Hotel",
	"fork": "Comida", "glass": "Bar e boate", "bag": "Lojas", "gun": "Armaria", "pill": "Farmácia",
	"tool": "Oficina e posto", "film": "Cinema", "weight": "Academia", "paper": "Jornal",
	"case": "Escritório", "home": "Moradia", "box": "Galpão", "barn": "Fazenda",
}

## Marcadores que não são prédios.
const MARKERS := ["you", "alert", "pin", "pin_on"]

const GLYPHS := {
	"hq": [
		"...y...",
		"..yyy..",
		"yyyyyyy",
		".yyyyy.",
		"..yyy..",
		".yy.yy.",
		".y...y.",
	],
	"law": [
		".uuuuu.",
		"uuwwwuu",
		"uuwwwuu",
		"uuwwwuu",
		".uuwuu.",
		"..uuu..",
		"...u...",
	],
	"cross": [
		"..rrr..",
		"..rwr..",
		"rrrwrrr",
		"rwwwwwr",
		"rrrwrrr",
		"..rwr..",
		"..rrr..",
	],
	"pill": [
		"..eee..",
		".eweee.",
		".eweee.",
		".wwwww.",
		".wEEEw.",
		".wEEEw.",
		"..www..",
	],
	"coin": [
		"..yyy..",
		".yyyyy.",
		"yyyoyyy",
		"yyoooyy",
		"yyyoyyy",
		".yyyyy.",
		"..yyy..",
	],
	"bed": [
		".......",
		".b.....",
		".bwwwwb",
		".bwpppb",
		".bbbbbb",
		".b....b",
		".......",
	],
	"home": [
		"...r...",
		"..rrr..",
		".rrrrr.",
		"rrrrrrr",
		".nnnnn.",
		".nnDnn.",
		".nnDnn.",
	],
	"fork": [
		".w.w.w.",
		".w.w.w.",
		".wwwww.",
		"..www..",
		"...w...",
		"...w...",
		"..www..",
	],
	"glass": [
		"mmmmmmm",
		".mmmmm.",
		"..mmm..",
		"...m...",
		"...m...",
		"...m...",
		"..mmm..",
	],
	"bag": [
		"..nnn..",
		".n...n.",
		"nnnnnnn",
		"nbbbbbn",
		"nbbbbbn",
		"nbbbbbn",
		"nnnnnnn",
	],
	"gun": [
		".......",
		"gggggg.",
		"gllllg.",
		"ggggggg",
		"..gg...",
		"..gg...",
		".......",
	],
	"tool": [
		".gg.gg.",
		".ggggg.",
		"..ggg..",
		"..ggg..",
		"..ggg..",
		"..ggg..",
		"...g...",
	],
	"film": [
		"sssssss",
		"sCsCsCs",
		"sssssss",
		"sCsCsCs",
		"sssssss",
		"sCsCsCs",
		"sssssss",
	],
	"weight": [
		".......",
		"l.....l",
		"llgggll",
		"llgggll",
		"llgggll",
		"l.....l",
		".......",
	],
	"paper": [
		"wwwwwww",
		"wkkwkkw",
		"wwwwwww",
		"wkkkkkw",
		"wwwwwww",
		"wkkkkkw",
		"wwwwwww",
	],
	"case": [
		"..bbb..",
		".b...b.",
		"bbbbbbb",
		"bnnynnb",
		"bnnnnnb",
		"bbbbbbb",
		".......",
	],
	"box": [
		".......",
		"nnnnnnn",
		"nbbnbbn",
		"nbbnbbn",
		"nnnnnnn",
		"nbbnbbn",
		"nnnnnnn",
	],
	"barn": [
		"...r...",
		"..rrr..",
		".rrrrr.",
		"rrrwwrr",
		"rrwDDwr",
		"rrwDDwr",
		"rrrDDrr",
	],
	# o jogador: seta ciano
	"you": [
		"...C...",
		"..CCC..",
		".CCwCC.",
		"CCCwCCC",
		"..CCC..",
		"..CCC..",
		".......",
	],
	# ponto marcado pelo jogador: bandeira (magenta) e a ativa (âmbar)
	"pin": [
		"mmm....",
		"mmmm...",
		"mmm....",
		"m......",
		"m......",
		"m......",
		"m......",
	],
	"pin_on": [
		"yyy....",
		"yyyy...",
		"yyy....",
		"y......",
		"y......",
		"y......",
		"y......",
	],
	# alvo de crime: losango vermelho
	"alert": [
		"...r...",
		"..rwr..",
		".rwwwr.",
		"..rwr..",
		"...r...",
		".......",
		".......",
	],
}


static func glyphs() -> Array:
	return GLYPHS.keys()


## Glifo do tipo de prédio ("" se o tipo não tem).
static func glyph_of(type: String) -> String:
	return GLYPH_OF.get(type, "")


static func label_of(glyph: String) -> String:
	return LABELS.get(glyph, "")


## Placa 9x9 (fundo tinta) com o glifo no meio.
static func canvas(glyph: String) -> RefCounted:
	var c := PixelCanvas.new(SIDE, SIDE)
	c.rect(1, 0, SIDE - 2, SIDE, Palette.get_color("ink"))
	c.rect(0, 1, SIDE, SIDE - 2, Palette.get_color("ink"))
	var rows: Array = GLYPHS.get(glyph, GLYPHS["bag"])
	c.stamp(rows, Palette.legend(), 1, 1)
	return c
