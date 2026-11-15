extends RefCounted
## Estilo visual de um prédio (parede, telhado, andares, toldo, vitrine, letreiro), derivado
## dos dados do layout. Lógica pura e determinística.
## A parede, o telhado e os andares vêm do bairro (campos `wall`, `roof_kind`, `floors` do
## prédio); o toldo, a vitrine e as cores do letreiro vêm do tipo (BuildingDefs); o letreiro
## mostra o nome próprio do prédio. Prédio sem esses campos (avulso, de teste) usa o id.

const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const Palette := preload("res://scripts/art/palette.gd")

const WALLS := ["wall/brick", "wall/white", "wall/yellow", "wall/teal", "wall/blue",
	"wall/pink", "wall/purple", "wall/gray", "wall/orange", "wall/brown"]
const ROOFS := ["roof/slab", "roof/slab_light", "roof/tar", "roof/zinc"]
## Telhado de telha: só em prédios baixos, com esta chance.
const TILE_ROOFS := ["roof/tile", "roof/tile_red", "roof/tile_brown"]
const TILE_ROOF_MAX_FLOORS := 2
const TILE_ROOF_CHANCE := 0.5
const MAX_FLOORS := 6
## Altura da fachada em texels: 6 por andar + 6.
const FLOOR_TEXELS := 6
const FACADE_BASE_TEXELS := 6
## A fachada nunca ocupa mais que esta fração da altura do prédio.
const MAX_FACADE_FRACTION := 0.45
const FARM_ID_BASE := 1000

## Aparência das lojas (a mesma da tabela de tipos; mantida para prédios sem `type`).
const SHOP_STYLES := {
	"armory": {"wall": "wall/brick", "roof": "roof/tar", "awning": "red", "sign_fg": "white", "sign_bg": "wine"},
	"pharmacy": {"wall": "wall/white", "roof": "roof/slab_light", "awning": "green", "sign_fg": "neon_green", "sign_bg": "green_dark"},
	"agent_store": {"wall": "wall/blue", "roof": "roof/slab", "awning": "teal", "sign_fg": "neon_cyan", "sign_bg": "navy"},
	"farm_store": {"wall": "wall/wood", "roof": "roof/tile", "awning": "yellow", "sign_fg": "cream", "sign_bg": "brown_dark"},
}


## {wall, roof, floors, awning, front, sign, sign_short, sign_fg, sign_bg, shop, type}
## `front`: térreo com vitrine e porta de vidro. `sign_short`: letreiro reserva, para quando
## o nome não cabe na largura do prédio.
static func for_building(b: Dictionary) -> Dictionary:
	var id: int = b.id
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 101
	var rect: Rect2 = b.rect
	var floors := clamp_floors(rng.randi_range(1, MAX_FLOORS - 1), rect.size.y)
	var roof: String = ROOFS[rng.randi_range(0, ROOFS.size() - 1)]
	var tile_roll := rng.randf()
	var tile_pick := rng.randi_range(0, TILE_ROOFS.size() - 1)
	if floors <= TILE_ROOF_MAX_FLOORS and tile_roll < TILE_ROOF_CHANCE:
		roof = TILE_ROOFS[tile_pick]
	var style := {
		"wall": WALLS[rng.randi_range(0, WALLS.size() - 1)],
		"roof": roof,
		"floors": floors,
		"awning": "", "front": false, "sign": "", "sign_short": "", "sign_fg": "white", "sign_bg": "ink",
		"shop": b.get("shop", ""),
		"type": b.get("type", ""),
	}
	if id >= FARM_ID_BASE:
		style.wall = "wall/wood"
		style.roof = "roof/tile"
		style.floors = 1
	# Aparência do bairro, quando o layout a definiu.
	if b.get("wall", "") != "":
		style.wall = b.wall
	if b.get("roof_kind", "") != "":
		style.roof = b.roof_kind
	if b.has("floors"):
		style.floors = b.floors

	var def: Dictionary = BuildingDefs.def(style.type)
	if not def.is_empty():
		style.awning = def.get("awning", "")
		style.front = def.get("front", false)
		style.sign_fg = def.get("sign_fg", "white")
		style.sign_bg = def.get("sign_bg", "ink")
		if not def.get("no_sign", false):
			style.sign = b.get("name", "")
			style.sign_short = def.get("short", "")
	elif style.shop != "" and SHOP_STYLES.has(style.shop):
		var shop: Dictionary = SHOP_STYLES[style.shop]
		for key in shop:
			style[key] = shop[key]
		style.front = true
		style.sign = ShopDefs.shop_name(style.shop)
		style.floors = mini(style.floors, 2)
	style.floors = clamp_floors(style.floors, rect.size.y)
	if (style.roof as String).begins_with("roof/tile") and style.floors > TILE_ROOF_MAX_FLOORS:
		style.roof = "roof/slab_light"
	return style


## Limita os andares para a fachada caber na fração máxima da altura do prédio (px do mundo).
static func clamp_floors(floors: int, building_height: float) -> int:
	var max_texels := int(building_height / 2.0 * MAX_FACADE_FRACTION)
	var fit := (max_texels - FACADE_BASE_TEXELS) / FLOOR_TEXELS
	return clampi(floors, 1, maxi(fit, 1))


## Altura da fachada em texels.
static func facade_texels(floors: int) -> int:
	return floors * FLOOR_TEXELS + FACADE_BASE_TEXELS


## Cor base (da paleta) de uma parede, para o campo `color` dos prédios.
static func wall_color(wall: String) -> Color:
	match wall:
		"wall/brick":
			return Palette.ramp("brick")[1]
		"wall/wood":
			return Palette.ramp("wood")[1]
	var tone := wall.trim_prefix("wall/")
	return Palette.tone(tone)[1] if Palette.TONES.has(tone) else Palette.get_color("concrete")


## Chave de cache do visual do prédio.
static func cache_key(b: Dictionary, style: Dictionary) -> String:
	return "bld/%d/%d" % [b.id, hash([b.rect, b.door, b.roof, style])]
