extends RefCounted
## Sprites de objetos de cena: mobiliário urbano, vegetação, detalhes de telhado, itens
## no chão e projéteis. Os pequenos são escritos como texto; os maiores, montados por código.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const TEXT_SPRITES := {
	"target_arrow": [
		"....k....",
		"....kk...",
		"kkkkkCk..",
		"kCCCCCCk.",
		"kCCCCCCCk",
		"kCCCCCCk.",
		"kkkkkCk..",
		"....kk...",
		"....k....",
	],
	"lamp": [
		".kkk.",
		"kyyyk",
		"kcyyk",
		".kkk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		"kgggk",
		"kkkkk",
	],
	"traffic_light": [
		"kkkkk",
		"ksrsk",
		"ksssk",
		"ksysk",
		"ksssk",
		"ksEsk",
		"kkkkk",
		".kgk.",
		".kgk.",
		".kgk.",
		".kgk.",
		".kkk.",
	],
	"hydrant": [
		"..k..",
		".krk.",
		"krrrk",
		"kvrvk",
		".krk.",
		".kkk.",
	],
	"bin": [
		".kkkk.",
		"kggggk",
		"kkkkkk",
		"keeeek",
		"keGeek",
		"keeeek",
		".kkkk.",
	],
	"bench": [
		"kkkkkkkkkkkk",
		"knnnnnnnnnnk",
		"kbbbbbbbbbbk",
		"knnnnnnnnnnk",
		"kkkkkkkkkkkk",
		".k........k.",
	],
	"manhole": [
		".kkkk.",
		"kssssk",
		"ksAAsk",
		"ksAAsk",
		"kssssk",
		".kkkk.",
	],
	"rock": [
		".kkkk.",
		"klggsk",
		"kggssk",
		".kkkk.",
	],
	"tuft": [
		"L.L.L",
		".LeL.",
		"..e..",
	],
	"flowers": [
		".P..y...",
		"PwP.yy.r",
		".P.e..rr",
		".e.e.y.e",
		"e..P.e.e",
		".ePwP..e",
		"..eP.e..",
	],
	"roof_ac": [
		"kkkkkkkkkk",
		"kllllllllk",
		"klsssslggk",
		"klskkslggk",
		"klskkslggk",
		"klsssslggk",
		"kggggggggk",
		"kkkkkkkkkk",
	],
	"roof_chimney": [
		"kkkkkk",
		"krrrrk",
		"rkkkkv",
		"rkkkkv",
		"kvvvvk",
		"kkkkkk",
	],
	"roof_antenna": [
		"k.....k",
		".k...k.",
		"..k.k..",
		"kkkkkkk",
		"..k.k..",
		".k...k.",
		"k.....k",
	],
	"roof_skylight": [
		"kkkkkkkkkkkk",
		"kwwwwwwwwwwk",
		"kwiSSSSSSSwk",
		"kwSiSSSSSSwk",
		"kwSSSSSSSNwk",
		"kwSSSSSSNNwk",
		"kwwwwwwwwwwk",
		"kkkkkkkkkkkk",
	],
	"cash": [
		".kkkkkkkk.",
		"keeeeeeeek",
		"keLeyyeLek",
		"keeeyyeeek",
		"keLeeeeLek",
		".kkkkkkkk.",
	],
	"medkit": [
		".kkkkkkk.",
		"kwwwwwwwk",
		"kwwwrwwwk",
		"kwwwrwwwk",
		"kwrrrrrwk",
		"kwwwrwwwk",
		"kwwwrwwwk",
		"klllllllk",
		".kkkkkkk.",
	],
	"pistol": [
		"kkkkkkkk.",
		"kggggggk.",
		"kssskkkk.",
		"kbbk.....",
		"kbbk.....",
		"kkkk.....",
	],
	"shotgun": [
		"kkkkkkkkkkkkk",
		"kbbbgggggggsk",
		"kbbbkkkkkkkkk",
		"kkkk.........",
	],
	"taser": [
		".kkkkkk.",
		"kyyyyyCk",
		"kyyykkCk",
		"kyyk....",
		"kkkk....",
	],
	"shield": [
		"kkkkkkkkk",
		"kSSSiSSSk",
		"kSSSSSSSk",
		"kSNNNNNSk",
		"kSSSSSSSk",
		"kuSSSSSuk",
		".kuSSSuk.",
		"..kuuuk..",
		"...kkk...",
	],
	"item": [
		".kkkkkk.",
		"knnnnnnk",
		"knbbbbnk",
		"knnnnnnk",
		"kbbbbbbk",
		".kkkkkk.",
	],
	"bullet": [
		".y.",
		"ycy",
		".y.",
	],
	"bullet_stun": [
		".C.",
		"CwC",
		".C.",
	],
	"gun_hand": [
		"kkkkkk",
		"kggggk",
		"kkkkk.",
	],
	"aim": [
		"C.C",
		"...",
		"C.C",
	],
	"fence_h": [
		"nn......",
		"bbnnnnnn",
		"bbDDDDDD",
		"DD......",
	],
	"fence_v": [
		"nnD",
		"nb.",
		"nb.",
		"nb.",
		"nb.",
		"nb.",
		"nb.",
		"nb.",
	],
}

const TREE_VARIANTS := 3

static var _canvases := {}


static func ids() -> Array:
	var result: Array = TEXT_SPRITES.keys()
	result.append_array(["bus_stop", "newsstand", "roof_tank", "bush", "trunk", "tree_shadow", "small_tree"])
	for i in TREE_VARIANTS:
		result.append("tree/%d" % i)
	return result


static func has_sprite(id: String) -> bool:
	return ids().has(id)


## Tela do sprite (gerada uma vez).
static func canvas(id: String) -> RefCounted:
	if not _canvases.has(id):
		_canvases[id] = _build(id)
	return _canvases[id]


static func _c(color_name: String) -> Color:
	return Palette.get_color(color_name)


static func _build(id: String) -> RefCounted:
	if TEXT_SPRITES.has(id):
		var rows: Array = TEXT_SPRITES[id]
		var canvas: RefCounted = PixelCanvas.new((rows[0] as String).length(), rows.size())
		canvas.stamp(rows, Palette.legend())
		return canvas
	if id.begins_with("tree/"):
		return _tree(30, int(id.trim_prefix("tree/")))
	match id:
		"small_tree":
			return _tree(16, 7)
		"bush":
			return _tree(10, 11)
		"tree_shadow":
			var s: RefCounted = PixelCanvas.new(30, 22)
			s.ellipse(0, 0, 30, 22, Palette.cast_shadow())
			return s
		"trunk":
			var t: RefCounted = PixelCanvas.new(8, 8)
			t.ellipse(1, 1, 6, 6, _c("brown"))
			t.px(3, 2, _c("sand"))
			t.px(2, 3, _c("sand"))
			t.outline(_c("ink"))
			return t
		"roof_tank":
			var t: RefCounted = PixelCanvas.new(12, 12)
			t.ellipse(1, 1, 10, 10, _c("gray"))
			t.ellipse(3, 3, 6, 6, _c("slate"))
			t.ellipse(4, 4, 4, 4, _c("blue"))
			t.px(3, 2, _c("white"))
			t.px(2, 3, _c("white"))
			t.px(4, 4, _c("sky"))
			t.outline(_c("ink"))
			return t
		"bus_stop":
			return _bus_stop()
		"newsstand":
			return _newsstand()
	push_warning("Sprite desconhecido: %s" % id)
	var missing: RefCounted = PixelCanvas.new(4, 4)
	missing.fill(_c("magenta"))
	return missing


## Copa de árvore: bolhas de folhagem com luz a noroeste e sombra a sudeste.
static func _tree(size: int, p_seed: int) -> RefCounted:
	var t: RefCounted = PixelCanvas.new(size + 2, size + 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + p_seed * 131 + size
	var blobs := 5 if size >= 24 else 3
	var blob := int(size * 0.62)
	# sombra da folhagem (deslocada para sudeste), depois a base, depois a luz
	var centers: Array[Vector2i] = [Vector2i((size - blob) / 2, (size - blob) / 2)]
	for i in blobs:
		centers.append(Vector2i(rng.randi_range(0, size - blob), rng.randi_range(0, size - blob)))
	for p in centers:
		t.ellipse(1 + p.x, 1 + p.y, blob, blob, _c("green_dark"))
	for p in centers:
		t.ellipse(1 + p.x, 1 + p.y, blob - 2, blob - 2, _c("green"))
	for p in centers:
		t.ellipse(1 + p.x + 1, 1 + p.y + 1, int(blob * 0.4), int(blob * 0.4), _c("lime"))
	t.outline(_c("ink"))
	return t


## Ponto de ônibus visto de cima: cobertura de vidro, banco e placa.
static func _bus_stop() -> RefCounted:
	var t: RefCounted = PixelCanvas.new(24, 10)
	t.rect(0, 0, 24, 6, _c("teal"))
	t.rect(1, 1, 22, 1, _c("ice"))
	t.rect(0, 5, 24, 1, _c("navy"))
	for x in [0, 23]:
		t.rect(x, 6, 1, 4, _c("gray"))
	t.rect(3, 7, 15, 2, _c("sand"))
	t.rect(3, 8, 15, 1, _c("brown"))
	t.rect(20, 6, 3, 3, _c("blue"))
	t.px(21, 7, _c("white"))
	t.outline(_c("ink"))
	return t


## Banca de jornal vista de cima: toldo listrado e revistas na frente.
static func _newsstand() -> RefCounted:
	var t: RefCounted = PixelCanvas.new(18, 12)
	t.rect(1, 1, 16, 6, _c("green"))
	for x in range(1, 17, 4):
		t.rect(x, 1, 2, 6, _c("white"))
	t.rect(1, 6, 16, 1, _c("green_dark"))
	t.rect(1, 7, 16, 4, _c("brown"))
	var covers := ["red", "amber", "sky", "pink", "lime"]
	for i in 5:
		t.rect(2 + i * 3, 8, 2, 2, _c(covers[i]))
	t.outline(_c("ink"))
	return t
