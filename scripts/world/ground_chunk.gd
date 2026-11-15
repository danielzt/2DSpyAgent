extends Node2D
## Um pedaço de chão do mundo (560x560 px): calçadas, lote, parque, marcações da rua,
## sombras dos prédios e objetos de cena. Os comandos de desenho são montados uma vez;
## o motor descarta os pedaços fora da tela.
## Tudo é desenhado em texels (escala 2), com tiles repetidos da fábrica de arte.

const CityLayout := preload("res://scripts/world/city_layout.gd")
const SidewalkGraph := preload("res://scripts/world/sidewalk_graph.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")

const TEXEL := 2.0
const OVERLAY_Z := 5
const SHADOW_TEXELS_PER_FLOOR := 3
const CROSSWALK_HALF := 12.0
const DECOR_KINDS := ["tuft", "tuft", "tuft", "rock", "flowers", "bush"]

## Coordenada do pedaço na grade do mundo (não só da cidade).
var chunk := Vector2i.ZERO
## Layout do mundo e do mobiliário (o segundo pode ser null no campo).
var world_layout
var props_layout
## Índice do lote da cidade neste pedaço, ou -1 se for campo.
var lot_index := -1
## Troncos de árvores dentro deste pedaço (px do mundo).
var trees: Array = []

var _overlay: Node2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_overlay = Node2D.new()
	_overlay.z_index = OVERLAY_Z
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	queue_redraw()
	_overlay.queue_redraw()


func is_city() -> bool:
	return lot_index >= 0


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	if is_city():
		_draw_city()
	else:
		_draw_country()
	for p in trees:
		var point: Vector2 = p
		_sprite_centered(self, "tree_shadow", point + Vector2(14.0, 12.0))
		_sprite_centered(self, "trunk", point)


func _draw_overlay() -> void:
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	for p in trees:
		var point: Vector2 = p
		var variant := absi(int(point.x) * 31 + int(point.y) * 17) % PropSprites.TREE_VARIANTS
		_sprite_centered(_overlay, "tree/%d" % variant, point + Vector2(0.0, -6.0))
	if props_layout == null or not is_city():
		return
	for prop in props_layout.for_block(chunk):
		if prop.layer != "overlay":
			continue
		match prop.kind:
			"lamp", "traffic_light":
				_sprite_standing(_overlay, prop.kind, prop.position)
			_:
				_sprite_centered(_overlay, prop.kind, prop.position)


# --- cidade ---

func _draw_city() -> void:
	var city = world_layout.city
	var lot: Rect2 = city.lots[lot_index]
	var is_park: bool = city.parks.has(lot)
	var walk := lot.grow(CityLayout.SIDEWALK)

	# Calçada com meio-fio, depois o lote.
	_tile("sidewalk", walk)
	_frame(walk, Palette.get_color("gray"))
	_frame(walk.grow(2.0), Palette.cast_shadow())
	_tile("grass" if is_park else "concrete", lot)
	if is_park:
		_frame(lot, Palette.get_color("green_dark"))
		_draw_park(lot)
	for yard in city.yards:
		if lot.grow(0.5).encloses(yard):
			_tile("grass", yard)
			_frame(yard, Palette.get_color("green_dark"))

	_draw_road_marks(lot)

	# Sombras dos prédios deste lote (para sudeste), sem passar do meio-fio.
	for b in city.buildings:
		var rect: Rect2 = b.rect
		if not lot.grow(0.5).encloses(rect):
			continue
		var length: float = BuildingStyle.for_building(b).floors * SHADOW_TEXELS_PER_FLOOR * TEXEL
		_shadow(Rect2(rect.end.x, rect.position.y + length, length, rect.size.y), walk)
		_shadow(Rect2(rect.position.x + length, rect.end.y, rect.size.x - length, length), walk)

	for prop in props_layout.for_block(chunk):
		if prop.layer == "ground":
			_sprite_centered(self, prop.kind, prop.position)


func _draw_park(lot: Rect2) -> void:
	var park: Dictionary = props_layout.parks.get(lot_index, {})
	if park.is_empty():
		return
	for path in park.paths:
		_tile("dirt", path)
	if park.has_pond:
		var pond: Rect2 = park.pond
		_ellipse(pond.grow(6.0), "dirt")
		_ellipse(pond, "water")


## Faixa central tracejada nas ruas à esquerda e acima do lote (e nas bordas do mapa),
## e as faixas de pedestres dos cruzamentos internos.
func _draw_road_marks(lot: Rect2) -> void:
	var block := CityLayout.BLOCK
	var left := chunk.x * block
	var top := chunk.y * block
	var dash_v := SpriteFactory.tile("dash_v")
	var dash_h := SpriteFactory.tile("dash_h")
	draw_texture_rect(dash_v, _t(Rect2(left - 2.0, lot.position.y, 4.0, lot.size.y)), true)
	draw_texture_rect(dash_h, _t(Rect2(lot.position.x, top - 2.0, lot.size.x, 4.0)), true)
	if chunk.x == CityLayout.CELLS - 1:
		draw_texture_rect(dash_v, _t(Rect2(left + block - 2.0, lot.position.y, 4.0, lot.size.y)), true)
	if chunk.y == CityLayout.CELLS - 1:
		draw_texture_rect(dash_h, _t(Rect2(lot.position.x, top + block - 2.0, lot.size.x, 4.0)), true)

	var half := SidewalkGraph.half()
	var reach := CityLayout.ASPHALT / 2.0
	var cross_h := SpriteFactory.tile("cross_h")
	var cross_v := SpriteFactory.tile("cross_v")
	# Rua da esquerda: faixas junto aos cruzamentos de cima e de baixo.
	for node_y in [chunk.y, chunk.y + 1]:
		if _is_inner_node(Vector2i(chunk.x, node_y)):
			var y: float = node_y * block + (half if node_y == chunk.y else -half)
			draw_texture_rect(cross_h, _t(Rect2(left - reach, y - CROSSWALK_HALF, reach * 2.0, CROSSWALK_HALF * 2.0)), true)
	# Rua de cima: faixas junto aos cruzamentos da esquerda e da direita.
	for node_x in [chunk.x, chunk.x + 1]:
		if _is_inner_node(Vector2i(node_x, chunk.y)):
			var x: float = node_x * block + (half if node_x == chunk.x else -half)
			draw_texture_rect(cross_v, _t(Rect2(x - CROSSWALK_HALF, top - reach, CROSSWALK_HALF * 2.0, reach * 2.0)), true)


static func _is_inner_node(node: Vector2i) -> bool:
	return node.x >= 1 and node.x <= CityLayout.CELLS - 1 and node.y >= 1 and node.y <= CityLayout.CELLS - 1


# --- campo ---

## Tufos, pedras e flores espalhados, fora da estrada, das plantações e das fazendas.
func _draw_country() -> void:
	var country = world_layout.country
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk.x * 92821 + chunk.y * 68917 + 3
	var origin := Vector2(chunk) * CityLayout.BLOCK
	for i in 16:
		var p := origin + Vector2(rng.randf_range(8.0, CityLayout.BLOCK - 8.0), rng.randf_range(8.0, CityLayout.BLOCK - 8.0))
		var kind: String = DECOR_KINDS[rng.randi_range(0, DECOR_KINDS.size() - 1)]
		if (country.road as Rect2).grow(16.0).has_point(p):
			continue
		var blocked := false
		for f in country.fields:
			if (f as Rect2).grow(14.0).has_point(p):
				blocked = true
		for b in country.buildings:
			if (b.rect as Rect2).grow(40.0).has_point(p):
				blocked = true
		if not blocked:
			_sprite_centered(self, kind, p)


# --- ajudantes de desenho (entrada em px do mundo, desenho em texels) ---

static func _t(rect: Rect2) -> Rect2:
	return Rect2(rect.position / TEXEL, rect.size / TEXEL)


func _tile(id: String, rect: Rect2) -> void:
	draw_texture_rect(SpriteFactory.tile(id), _t(rect), true)


## Moldura de 1 texel por dentro do retângulo.
func _frame(rect: Rect2, color: Color) -> void:
	var r := _t(rect)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), color)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), color)
	draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), color)
	draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), color)


func _shadow(rect: Rect2, limit: Rect2) -> void:
	var clipped := rect.intersection(limit)
	if clipped.size.x > 0.0 and clipped.size.y > 0.0:
		draw_rect(_t(clipped), Palette.cast_shadow())


## Elipse preenchida com um tile repetido.
func _ellipse(rect: Rect2, tile_id: String) -> void:
	var r := _t(rect)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var texture := SpriteFactory.tile(tile_id)
	for i in 20:
		var a := TAU * i / 20.0
		var p := (r.get_center() + Vector2(cos(a) * r.size.x / 2.0, sin(a) * r.size.y / 2.0)).round()
		points.append(p)
		uvs.append(p / Vector2(texture.get_size()))
	draw_colored_polygon(points, Color.WHITE, uvs, texture)


## Sprite centrado no ponto (px do mundo).
func _sprite_centered(target: CanvasItem, id: String, point: Vector2) -> void:
	var texture := SpriteFactory.prop(id)
	target.draw_texture(texture, (point / TEXEL - Vector2(texture.get_size()) / 2.0).round())


## Sprite em pé: a base fica no ponto.
func _sprite_standing(target: CanvasItem, id: String, point: Vector2) -> void:
	var texture := SpriteFactory.prop(id)
	var size := Vector2(texture.get_size())
	target.draw_texture(texture, (point / TEXEL - Vector2(size.x / 2.0, size.y)).round())
