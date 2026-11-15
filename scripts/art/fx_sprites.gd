extends RefCounted
## Sprites dos efeitos (Fase 5): clarão e cápsula do tiro, faíscas, poeira e marca de pneu.
## Tudo pixel art por código, só com cores da paleta; o brilho/transparência de cada
## partícula vem do `modulate` em tempo de execução.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const TEXT_SPRITES := {
	# clarão da boca da arma: um grande e um menor (2 quadros); aponta para a direita
	"muzzle/0": [
		"..o.o..",
		".oyyyo.",
		"oycwcyo",
		".oyyyo.",
		"..o.o..",
	],
	"muzzle/1": [
		".oyo.",
		"oycyo",
		".oyo.",
	],
	"casing": ["yo"],
	"spark/0": ["c"],
	"spark/1": ["y"],
	"spark/2": ["o"],
}

const DUST_SIZES := [3, 5, 7]
const DUST_VARIANTS := 3


static func ids() -> Array:
	var result: Array = TEXT_SPRITES.keys()
	for i in DUST_VARIANTS:
		result.append("dust/%d" % i)
	result.append("tire")
	return result


static func has_sprite(id: String) -> bool:
	return ids().has(id)


static func canvas(id: String) -> RefCounted:
	if TEXT_SPRITES.has(id):
		var rows: Array = TEXT_SPRITES[id]
		var c := PixelCanvas.new((rows[0] as String).length(), rows.size())
		c.stamp(rows, Palette.legend())
		return c
	if id.begins_with("dust/"):
		var size: int = DUST_SIZES[clampi(int(id.trim_prefix("dust/")), 0, DUST_VARIANTS - 1)]
		var c := PixelCanvas.new(size, size)
		c.ellipse(0, 0, size, size, Palette.get_color("light"))
		if size > 3:
			c.ellipse(1, 1, size - 2, size - 2, Palette.get_color("white"))
		return c
	if id == "tire":
		var c := PixelCanvas.new(6, 2)
		c.fill(Palette.get_color("ink"))
		return c
	push_error("sprite de efeito desconhecido: %s" % id)
	return PixelCanvas.new(1, 1)
