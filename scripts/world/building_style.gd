extends RefCounted
## Estilo visual de um prédio (parede, telhado, andares, toldo, letreiro), derivado dos
## dados do layout. Lógica pura e determinística.
## Na Fase 2 o estilo passa a vir do bairro e do tipo do prédio; por ora vem do id.

const ShopDefs := preload("res://scripts/items/shop_defs.gd")

const WALLS := ["wall/brick", "wall/white", "wall/yellow", "wall/teal", "wall/blue",
	"wall/pink", "wall/purple", "wall/gray", "wall/orange", "wall/brown"]
const ROOFS := ["roof/slab", "roof/slab_light", "roof/tar", "roof/zinc"]
## Telhado de telha: só em prédios baixos, com esta chance.
const TILE_ROOFS := ["roof/tile", "roof/tile_red", "roof/tile_brown"]
const TILE_ROOF_MAX_FLOORS := 2
const TILE_ROOF_CHANCE := 0.5
const MAX_FLOORS := 5
## Altura da fachada em texels: 6 por andar + 6.
const FLOOR_TEXELS := 6
const FACADE_BASE_TEXELS := 6
## A fachada nunca ocupa mais que esta fração da altura do prédio.
const MAX_FACADE_FRACTION := 0.45
const FARM_ID_BASE := 1000

const SHOP_STYLES := {
	"armory": {"wall": "wall/brick", "roof": "roof/tar", "awning": "red", "sign_fg": "white", "sign_bg": "wine"},
	"pharmacy": {"wall": "wall/white", "roof": "roof/slab_light", "awning": "green", "sign_fg": "neon_green", "sign_bg": "green_dark"},
	"agent_store": {"wall": "wall/blue", "roof": "roof/slab", "awning": "teal", "sign_fg": "neon_cyan", "sign_bg": "navy"},
	"farm_store": {"wall": "wall/wood", "roof": "roof/tile", "awning": "yellow", "sign_fg": "cream", "sign_bg": "brown_dark"},
}


## {wall, roof, floors, awning, sign, sign_fg, sign_bg, shop}
static func for_building(b: Dictionary) -> Dictionary:
	var id: int = b.id
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 101
	var rect: Rect2 = b.rect
	var floors := clamp_floors(rng.randi_range(1, MAX_FLOORS), rect.size.y)
	var roof: String = ROOFS[rng.randi_range(0, ROOFS.size() - 1)]
	var tile_roll := rng.randf()
	var tile_pick := rng.randi_range(0, TILE_ROOFS.size() - 1)
	if floors <= TILE_ROOF_MAX_FLOORS and tile_roll < TILE_ROOF_CHANCE:
		roof = TILE_ROOFS[tile_pick]
	var style := {
		"wall": WALLS[rng.randi_range(0, WALLS.size() - 1)],
		"roof": roof,
		"floors": floors,
		"awning": "", "sign": "", "sign_fg": "white", "sign_bg": "ink",
		"shop": b.get("shop", ""),
	}
	if id >= FARM_ID_BASE:
		style.wall = "wall/wood"
		style.roof = "roof/tile"
		style.floors = 1
	if style.shop != "" and SHOP_STYLES.has(style.shop):
		var shop: Dictionary = SHOP_STYLES[style.shop]
		for key in shop:
			style[key] = shop[key]
		style.sign = ShopDefs.shop_name(style.shop)
		style.floors = mini(style.floors, 2)
	style.floors = clamp_floors(style.floors, rect.size.y)
	return style


## Limita os andares para a fachada caber na fração máxima da altura do prédio (px do mundo).
static func clamp_floors(floors: int, building_height: float) -> int:
	var max_texels := int(building_height / 2.0 * MAX_FACADE_FRACTION)
	var fit := (max_texels - FACADE_BASE_TEXELS) / FLOOR_TEXELS
	return clampi(floors, 1, maxi(fit, 1))


## Altura da fachada em texels.
static func facade_texels(floors: int) -> int:
	return floors * FLOOR_TEXELS + FACADE_BASE_TEXELS


## Chave de cache do visual do prédio.
static func cache_key(b: Dictionary, style: Dictionary) -> String:
	return "bld/%d/%d" % [b.id, hash([b.rect, b.door, b.roof, style])]
