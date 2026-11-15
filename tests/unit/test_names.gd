extends "res://tests/base_test.gd"
## Nomes próprios: prédios, ruas, avenidas e o texto de lugar do HUD.

const NameGenerator := preload("res://scripts/world/name_generator.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")


func _drawable(text: String) -> bool:
	var normalized := PixelFont.normalize(text)
	for i in normalized.length():
		if not PixelFont.has_glyph(normalized[i]):
			return false
	return true


# --- prédios ---

func test_every_type_can_be_named() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for type in BuildingDefs.ORDER:
		var used := {}
		var building_name := NameGenerator.building_name(type, rng, used)
		assert_ne(building_name, "", type)
		assert_false(building_name.begins_with("Prédio"), "%s sem lista de nomes" % type)
		assert_true(used.has(building_name))


func test_name_lists_cover_the_maximum_of_each_type() -> void:
	for type in NameGenerator.BUILDING_NAMES:
		var needed: int = maxi(BuildingDefs.max_count(type), 1)
		assert_true((NameGenerator.BUILDING_NAMES[type] as Array).size() >= needed, type)


func test_names_never_repeat_even_when_the_list_runs_out() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var used := {}
	var names := {}
	for i in 80:
		names[NameGenerator.building_name("apartment", rng, used)] = true
	assert_eq(names.size(), 80)
	for i in 40:
		names[NameGenerator.building_name("house", rng, used)] = true
		names[NameGenerator.building_name("bar", rng, used)] = true
	assert_eq(names.size(), 160)


func test_every_name_can_be_drawn_by_the_pixel_font() -> void:
	var all: Array = []
	for type in NameGenerator.BUILDING_NAMES:
		all.append_array(NameGenerator.BUILDING_NAMES[type])
	for type in NameGenerator.FILL_WORDS:
		all.append(NameGenerator.FILL_PREFIX[type])
		all.append_array(NameGenerator.FILL_WORDS[type])
	all.append_array(NameGenerator.AVENUES)
	all.append_array(NameGenerator.STREETS)
	all.append_array(NameGenerator.ROMAN)
	all.append(NameGenerator.COUNTRY_ROAD)
	for text in all:
		assert_true(_drawable(text), "a fonte não desenha: %s" % text)


func test_city_building_names_are_unique_and_deterministic() -> void:
	var a := CityLayout.new(5)
	var b := CityLayout.new(5)
	var names := {}
	for i in a.buildings.size():
		names[a.buildings[i].name] = true
		assert_eq(a.buildings[i].name, b.buildings[i].name)
	assert_eq(names.size(), a.buildings.size(), "nomes de prédio repetidos")


func test_names_start_with_the_kind_of_place() -> void:
	var city := CityLayout.new()
	for b in city.buildings:
		match b.type:
			"house":
				assert_true(b.name.begins_with("Casa "), b.name)
			"apartment":
				assert_true(b.name.begins_with("Edifício "), b.name)
			"office":
				assert_true(b.name.begins_with("Escritório "), b.name)
			"warehouse":
				assert_true(b.name.begins_with("Armazém "), b.name)
			"bank":
				assert_true(b.name.begins_with("Banco "), b.name)
			"hq":
				assert_true(b.name.begins_with("Lavanderia "), "o QG é disfarçado de lavanderia")


func test_prepositions() -> void:
	assert_eq(NameGenerator.preposition("Hotel Álibi"), "no")
	assert_eq(NameGenerator.preposition("Cantina Bela Máfia"), "na")
	assert_eq(NameGenerator.at_place("Bar Saideira"), "no Bar Saideira")
	assert_eq(NameGenerator.at_place("Farmácia Placebo"), "na Farmácia Placebo")
	assert_eq(NameGenerator.at_place("Vila Sossego"), "na Vila Sossego")
	assert_eq(NameGenerator.at_place("Campo"), "no Campo")


# --- ruas ---

func test_street_names_cover_the_26_lines_without_repeating() -> void:
	var names := NameGenerator.street_names(2024)
	assert_eq((names.v as Array).size(), CityLayout.CELLS + 1)
	assert_eq((names.h as Array).size(), CityLayout.CELLS + 1)
	var seen := {}
	for axis in ["v", "h"]:
		for street in names[axis]:
			assert_ne(street, "")
			seen[street] = true
	assert_eq(seen.size(), 26)


func test_only_the_avenue_lines_are_avenues() -> void:
	assert_eq(NameGenerator.AVENUE_LINE, CityLayout.AVENUE_LINE)
	assert_eq(NameGenerator.LINES, CityLayout.CELLS + 1)
	var names := NameGenerator.street_names(7)
	for axis in ["v", "h"]:
		for line in NameGenerator.LINES:
			var is_avenue: bool = (names[axis][line] as String).begins_with("Av.")
			assert_eq(is_avenue, CityLayout.is_avenue(line), "%s %d: %s" % [axis, line, names[axis][line]])


func test_street_names_are_deterministic_and_vary_with_the_seed() -> void:
	assert_eq(NameGenerator.street_names(4), NameGenerator.street_names(4))
	assert_ne(NameGenerator.street_names(4), NameGenerator.street_names(5))


func test_street_name_at() -> void:
	var city := CityLayout.new()
	var block := CityLayout.BLOCK
	# no meio de um trecho de rua vertical (linha 2) e de uma horizontal (linha 3)
	assert_eq(city.street_name_at(Vector2(2 * block + 10.0, 3.5 * block)), city.street_names.v[2])
	assert_eq(city.street_name_at(Vector2(4.5 * block, 3 * block - 20.0)), city.street_names.h[3])
	# no cruzamento aparecem as duas
	var corner := city.street_name_at(Vector2(2 * block, 3 * block))
	assert_true(corner.contains(city.street_names.v[2]) and corner.contains(city.street_names.h[3]))
	assert_true(corner.contains("×"))
	# dentro do lote vale a rua mais próxima
	assert_eq(city.street_name_at(Vector2(2 * block + 130.0, 3.5 * block)), city.street_names.v[2])
	# na avenida
	var avenue := city.street_name_at(Vector2(CityLayout.AVENUE_LINE * block + 80.0, 2.5 * block))
	assert_true(avenue.begins_with("Av."), avenue)


# --- lugar no HUD ---

func test_place_text_joins_district_and_street() -> void:
	var layout := WorldLayout.new()
	var p := Vector2(2 * CityLayout.BLOCK + 10.0, 3.5 * CityLayout.BLOCK)
	assert_eq(layout.place_text(p), "%s • %s" % [layout.district_at(p), layout.city.street_names.v[2]])
	assert_ne(layout.district_at(p), "")
	assert_true(_drawable(layout.place_text(p)))


func test_country_shows_only_the_road_when_near_it() -> void:
	var layout := WorldLayout.new()
	var on_road: Vector2 = (layout.country.road as Rect2).get_center()
	assert_eq(layout.district_at(on_road), "")
	assert_eq(layout.street_name_at(on_road), NameGenerator.COUNTRY_ROAD)
	assert_eq(layout.place_text(on_road), NameGenerator.COUNTRY_ROAD)
	var far := on_road + Vector2(0, 2000)
	assert_eq(layout.place_text(far), "")
	assert_eq(layout.district_id_at(far), "")
