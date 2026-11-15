extends RefCounted
## Fábrica de texturas: monta cada sprite uma única vez e guarda em cache por chave.
## As cenas pedem texturas daqui em vez de desenhar com _draw.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")
const FxSprites := preload("res://scripts/art/fx_sprites.gd")
const MapIcons := preload("res://scripts/art/map_icons.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")

## Tamanho de um texel em px do mundo.
const TEXEL := 2

static var _textures := {}
static var _builds := 0


## Quantas texturas já foram montadas (não cresce em pedidos repetidos).
static func build_count() -> int:
	return _builds


static func clear_cache() -> void:
	_textures.clear()


static func _cached(key: String, builder: Callable) -> ImageTexture:
	if not _textures.has(key):
		var canvas: RefCounted = builder.call()
		_textures[key] = canvas.to_texture()
		_builds += 1
	return _textures[key]


static func tile(id: String) -> ImageTexture:
	return TileFactory.texture(id)


static func prop(id: String) -> ImageTexture:
	return _cached("prop/" + id, func() -> RefCounted: return PropSprites.canvas(id))


## Ícone do mapa (placa 9x9 com o glifo da categoria, ou "you"/"alert").
static func map_icon(glyph: String) -> ImageTexture:
	return _cached("map/" + glyph, func() -> RefCounted: return MapIcons.canvas(glyph))


## Sprite de efeito (clarão, faísca, poeira, marca de pneu).
static func fx(id: String) -> ImageTexture:
	return _cached("fx/" + id, func() -> RefCounted: return FxSprites.canvas(id))


## Quadro de personagem (16x20 texels). `frame`: 0 parado, 1 e 2 passos.
static func character(look: Dictionary, direction: String, frame: int) -> ImageTexture:
	var key := "char/%s/%s/%d" % [CharacterSprites.look_key(look), direction, frame]
	return _cached(key, func() -> RefCounted: return CharacterSprites.build(look, direction, frame))


## Quadro de carro na direção pré-gerada `direction` (0 a 31).
static func car(model: String, tone: String, direction: int) -> ImageTexture:
	var key := "car/%s/%s/%d" % [model, CarSprites.tone_of(model, tone), direction]
	return _cached(key, func() -> RefCounted: return CarSprites.frame(model, tone, direction))


## Texto na fonte pixel, com contorno opcional.
static func text(content: String, color_name: String, outline_name := "ink", align := 0) -> ImageTexture:
	var key := "text/%s/%s/%d/%s" % [color_name, outline_name, align, content]
	return _cached(key, func() -> RefCounted:
		var outline := Palette.get_color(outline_name) if outline_name != "" else Color(0, 0, 0, 0)
		return PixelFont.render(content, Palette.get_color(color_name), outline, 1, align))


## Textura qualquer montada sob demanda (prédios, molduras), guardada pela chave.
static func custom(key: String, builder: Callable) -> ImageTexture:
	return _cached(key, builder)


## Sprite2D pronto: textura ampliada pelo tamanho do texel, com o `pivot` (em texels) na origem.
static func make_sprite(texture: Texture2D, pivot: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(TEXEL, TEXEL)
	sprite.offset = -pivot
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite
