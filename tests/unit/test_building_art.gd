extends "res://tests/base_test.gd"
## Estilo e desenho dos prédios (telhado, fachada, porta, letreiro).

const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const BuildingArt := preload("res://scripts/art/building_art.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")

var city


func before_each() -> void:
	city = CityLayout.new()


func _first_shop() -> Dictionary:
	for b in city.buildings:
		if b.shop != "":
			return b
	return {}


func _first_plain() -> Dictionary:
	for b in city.buildings:
		if b.shop == "":
			return b
	return {}


# --- estilo ---

func test_style_is_deterministic() -> void:
	for b in city.buildings.slice(0, 30):
		assert_eq(BuildingStyle.for_building(b), BuildingStyle.for_building(b))


func test_style_uses_existing_tiles_and_palette_colors() -> void:
	for b in city.buildings:
		var style := BuildingStyle.for_building(b)
		assert_true(TileFactory.has_tile(style.wall), style.wall)
		assert_true(TileFactory.has_tile(style.roof), style.roof)
		assert_true(Palette.has_color(style.sign_fg))
		assert_true(Palette.has_color(style.sign_bg))
		if style.awning != "":
			assert_true(Palette.TONES.has(style.awning))


func test_buildings_vary_in_wall_roof_and_height() -> void:
	var walls := {}
	var roofs := {}
	var floors := {}
	for b in city.buildings:
		var style := BuildingStyle.for_building(b)
		walls[style.wall] = true
		roofs[style.roof] = true
		floors[style.floors] = true
	assert_gt(walls.size(), 6.0)
	assert_gt(roofs.size(), 4.0)
	assert_gt(floors.size(), 3.0)


func test_facade_never_takes_more_than_the_allowed_fraction() -> void:
	for b in city.buildings:
		var style := BuildingStyle.for_building(b)
		var height_texels: float = (b.rect as Rect2).size.y / 2.0
		assert_true(style.floors >= 1 and style.floors <= BuildingStyle.MAX_FLOORS)
		assert_true(BuildingStyle.facade_texels(style.floors) <= height_texels * BuildingStyle.MAX_FACADE_FRACTION + 0.01,
			"prédio %d" % b.id)
	assert_eq(BuildingStyle.clamp_floors(5, 60.0), 1, "prédio baixo fica com 1 andar")
	assert_eq(BuildingStyle.facade_texels(1), 12)
	assert_eq(BuildingStyle.facade_texels(3), 24)


func test_tile_roofs_only_on_low_buildings() -> void:
	for b in city.buildings:
		var style := BuildingStyle.for_building(b)
		if (style.roof as String).begins_with("roof/tile"):
			assert_true(style.floors <= BuildingStyle.TILE_ROOF_MAX_FLOORS, "prédio %d" % b.id)


func test_shops_get_sign_awning_and_their_own_colors() -> void:
	var found := {}
	for b in city.buildings:
		if b.shop == "":
			assert_eq(BuildingStyle.for_building(b).sign, "")
			continue
		var style := BuildingStyle.for_building(b)
		found[b.shop] = style
		assert_ne(style.sign, "")
		assert_ne(style.awning, "")
		assert_eq(style.wall, BuildingStyle.SHOP_STYLES[b.shop].wall)
	assert_eq(found.size(), CityLayout.SHOP_PLAN.size())
	assert_ne(found["armory"].sign_fg, found["pharmacy"].sign_fg)


func test_farms_are_wooden_with_tile_roof() -> void:
	var country := CountryLayout.new(Vector2(6720, 0))
	for b in country.buildings:
		var style := BuildingStyle.for_building(b)
		assert_eq(style.wall, "wall/wood")
		assert_eq(style.roof, "roof/tile")
		assert_eq(style.floors, 1)
	assert_ne(BuildingStyle.for_building(country.buildings[CountryLayout.FARM_SHOP_INDEX]).sign, "")


func test_cache_key_changes_with_the_building() -> void:
	var a: Dictionary = city.buildings[0]
	var b: Dictionary = city.buildings[1]
	assert_eq(BuildingStyle.cache_key(a, BuildingStyle.for_building(a)), BuildingStyle.cache_key(a, BuildingStyle.for_building(a)))
	assert_ne(BuildingStyle.cache_key(a, BuildingStyle.for_building(a)), BuildingStyle.cache_key(b, BuildingStyle.for_building(b)))


# --- desenho ---

func test_render_fits_the_collision_rect_plus_the_door_step() -> void:
	for b in city.buildings.slice(0, 12):
		var canvas: RefCounted = BuildingArt.render(b, BuildingStyle.for_building(b))
		var expected := BuildingArt.canvas_size((b.rect as Rect2).size)
		assert_eq(Vector2i(canvas.width, canvas.height), expected)
		assert_eq(expected.x * 2, int((b.rect as Rect2).size.x))
		assert_eq((expected.y - BuildingArt.STEP_TEXELS) * 2, int((b.rect as Rect2).size.y))


func test_render_uses_only_palette_colors() -> void:
	var samples: Array = city.buildings.slice(0, 10)
	samples.append(_first_shop())
	for b in samples:
		assert_true(BuildingArt.render(b, BuildingStyle.for_building(b)).only_palette_colors(), "prédio %d" % b.id)


func test_building_is_fully_painted_and_outlined() -> void:
	var b := _first_plain()
	var canvas: RefCounted = BuildingArt.render(b, BuildingStyle.for_building(b))
	var w: int = canvas.width
	var h: int = canvas.height - BuildingArt.STEP_TEXELS
	var ink := Palette.get_color("ink")
	for x in w:
		assert_eq(canvas.get_px(x, 0), ink)
		for y in h:
			if canvas.is_empty_at(x, y):
				assert_true(false, "buraco em %d,%d" % [x, y])
				return
	assert_eq(canvas.get_px(0, h / 2), ink)
	assert_eq(canvas.get_px(w - 1, h / 2), ink)


func test_door_step_sits_under_the_layout_door() -> void:
	var b := _first_plain()
	var canvas: RefCounted = BuildingArt.render(b, BuildingStyle.for_building(b))
	var h: int = canvas.height - BuildingArt.STEP_TEXELS
	var door_x := int(((b.door as Rect2).position.x - (b.rect as Rect2).position.x) / 2.0)
	assert_false(canvas.is_empty_at(door_x + BuildingArt.DOOR_SLOT / 2, h), "degrau em frente à porta")
	assert_false(canvas.is_empty_at(door_x, h))
	assert_false(canvas.is_empty_at(door_x + BuildingArt.DOOR_SLOT - 1, h))
	if door_x > 0:
		assert_true(canvas.is_empty_at(door_x - 1, h + 1), "fora da porta não há degrau")
	# a porta desenhada fica dentro do vão da porta do layout
	assert_eq(BuildingArt.DOOR_SLOT * 2, int(CityLayout.DOOR_WIDTH))
	assert_true(BuildingArt.DOOR_W <= BuildingArt.DOOR_SLOT)


func test_shop_sign_changes_the_picture() -> void:
	var b := _first_shop()
	var style := BuildingStyle.for_building(b)
	var with_sign: RefCounted = BuildingArt.render(b, style)
	var plain_style := style.duplicate()
	plain_style.sign = ""
	var without: RefCounted = BuildingArt.render(b, plain_style)
	assert_ne(with_sign.image.get_data(), without.image.get_data())
	assert_true(with_sign.used_colors().has(Color(Palette.get_color(style.sign_fg).to_html(false))))


func test_render_is_deterministic() -> void:
	var b: Dictionary = city.buildings[4]
	var style := BuildingStyle.for_building(b)
	assert_eq(BuildingArt.render(b, style).image.get_data(), BuildingArt.render(b, style).image.get_data())


func test_wrap_sign_breaks_long_names_at_a_space() -> void:
	assert_eq(BuildingArt.wrap_sign("Armaria", 200), "Armaria")
	assert_eq(BuildingArt.wrap_sign("Armaria", 10), "Armaria", "sem espaço não quebra")
	var wrapped := BuildingArt.wrap_sign("Loja do Agente", 60)
	assert_true(wrapped.contains("\n"))
	assert_eq(wrapped.replace("\n", " "), "Loja do Agente")
	assert_true(PixelFont.measure(wrapped).x < PixelFont.measure("Loja do Agente").x)


func test_every_shop_sign_fits_its_building() -> void:
	for b in city.buildings:
		if b.shop == "":
			continue
		var style := BuildingStyle.for_building(b)
		var width_texels := int((b.rect as Rect2).size.x / 2.0)
		var text := BuildingArt.wrap_sign(style.sign, width_texels - 8)
		assert_true(PixelFont.measure(text).x + 6 <= width_texels - 2, "letreiro de %s não cabe" % b.shop)


func test_wall_and_roof_tones_cover_every_style() -> void:
	for wall in BuildingStyle.WALLS + ["wall/wood"]:
		assert_eq(BuildingArt.wall_tones(wall).size(), 3, wall)
	for roof in BuildingStyle.ROOFS + BuildingStyle.TILE_ROOFS:
		assert_eq(BuildingArt.roof_edges(roof).size(), 2, roof)
