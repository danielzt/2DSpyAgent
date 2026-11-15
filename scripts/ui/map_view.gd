extends RefCounted
## Desenho e matemática do mapa (Fase 5): usado pelo minimapa do HUD, pelo mapa de tela
## cheia (tecla M) e pela tela de pausa. Mostra bairros coloridos (as ruas são os vãos entre
## os lotes), prédios, o campo e um ícone por tipo para os prédios conhecidos.
## "Conhecido" = já visitado ou visto de perto (PlayerProfile.known_buildings).

const CityLayout := preload("res://scripts/world/city_layout.gd")
const MapIcons := preload("res://scripts/art/map_icons.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")

## Raio do minimapa: 1 quarteirão e meio.
const MINIMAP_RADIUS := CityLayout.BLOCK * 1.5
## Cores por bairro: [lote, prédio]. Todas da paleta.
const DISTRICT_TONES := {
	"center": ["slate", "gray"],
	"residential": ["green_dark", "sand"],
	"nightlife": ["purple", "pink"],
	"industrial": ["brown_dark", "concrete"],
	"upscale": ["wine", "skin_dark"],
	"civic": ["blue", "ice"],
	"country": ["green_dark", "brown"],
}


static func lot_color_name(district: String) -> String:
	return (DISTRICT_TONES.get(district, ["shadow", "slate"]) as Array)[0]


static func building_color_name(district: String) -> String:
	return (DISTRICT_TONES.get(district, ["shadow", "slate"]) as Array)[1]


## Retângulo do mundo inteiro (cidade e campo).
static func world_rect(layout) -> Rect2:
	var cs := CityLayout.city_size()
	var country_rect: Rect2 = layout.country.region_rect()
	return Rect2(Vector2.ZERO, Vector2(cs, cs)).merge(country_rect)


## Área do mundo vista pelo minimapa em torno de `center`.
static func view_around(center: Vector2, radius := MINIMAP_RADIUS) -> Rect2:
	return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


## Retângulo `dest` (tela) onde cabe `view` (mundo) inteiro, centralizado, sem distorcer.
static func fit(view: Rect2, area: Rect2) -> Rect2:
	var k := minf(area.size.x / view.size.x, area.size.y / view.size.y)
	var size := view.size * k
	return Rect2(area.position + (area.size - size) / 2.0, size)


static func to_screen(point: Vector2, view: Rect2, dest: Rect2) -> Vector2:
	return dest.position + (point - view.position) * (dest.size.x / view.size.x)


static func to_world(screen_point: Vector2, view: Rect2, dest: Rect2) -> Vector2:
	return view.position + (screen_point - dest.position) / (dest.size.x / view.size.x)


## Prédios conhecidos (do mundo todo): [{id, pos, glyph, type, name}].
static func known_icons(layout, known: Dictionary) -> Array[Dictionary]:
	var icons: Array[Dictionary] = []
	for b in layout.buildings():
		if not known.has(b.id):
			continue
		var glyph := MapIcons.glyph_of(b.get("type", ""))
		if glyph == "":
			continue
		icons.append({"id": b.id, "pos": (b.rect as Rect2).get_center(), "glyph": glyph,
				"type": b.type, "name": b.get("name", "")})
	return icons


## Ícones conhecidos dentro de `view`.
static func icons_in(layout, known: Dictionary, view: Rect2) -> Array[Dictionary]:
	var inside: Array[Dictionary] = []
	for icon in known_icons(layout, known):
		if view.has_point(icon.pos):
			inside.append(icon)
	return inside


static func _fill(canvas: CanvasItem, world_r: Rect2, view: Rect2, dest: Rect2, color_name: String) -> void:
	var r := world_r.intersection(view)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var k := dest.size.x / view.size.x
	canvas.draw_rect(Rect2(dest.position + (r.position - view.position) * k, r.size * k), Palette.get_color(color_name))


## Desenha o mapa de `view` (mundo) dentro de `dest` (tela). `icon_scale`: px por texel dos
## ícones. Ícones fora do retângulo são pulados. O chamador deve recortar (clip_contents).
static func draw(canvas: CanvasItem, layout, known: Dictionary, view: Rect2, dest: Rect2, icon_scale := 2.0) -> void:
	_fill(canvas, view, view, dest, "asphalt")
	var city = layout.city
	if view.intersects(Rect2(0, 0, CityLayout.city_size(), CityLayout.city_size())):
		for i in city.lots.size():
			var lot: Rect2 = city.lots[i]
			if not lot.intersects(view):
				continue
			var district: String = city.districts.district_of_cell(Vector2i(i / CityLayout.CELLS, i % CityLayout.CELLS))
			_fill(canvas, lot, view, dest, lot_color_name(district))
		for park in city.parks:
			_fill(canvas, park, view, dest, "green")
		for b in city.buildings:
			_fill(canvas, b.rect, view, dest, building_color_name(b.district))
	var country_rect: Rect2 = layout.country.region_rect()
	if view.intersects(country_rect):
		_fill(canvas, country_rect, view, dest, "green_dark")
		for field in layout.country.fields:
			_fill(canvas, field, view, dest, "green")
		_fill(canvas, layout.country.road, view, dest, "asphalt")
		for b in layout.country.buildings:
			_fill(canvas, b.rect, view, dest, "brown")
	for icon in icons_in(layout, known, view):
		draw_glyph(canvas, icon.glyph, to_screen(icon.pos, view, dest), icon_scale, dest)


## Ícone centrado em `center`, só se couber em `bounds`.
static func draw_glyph(canvas: CanvasItem, glyph: String, center: Vector2, icon_scale: float, bounds: Rect2) -> void:
	var texture := SpriteFactory.map_icon(glyph)
	var size := Vector2(texture.get_size()) * icon_scale
	var rect := Rect2((center - size / 2.0).round(), size)
	if bounds.encloses(rect):
		canvas.draw_texture_rect(texture, rect, false)
