extends "res://tests/base_test.gd"
## Tabela de tipos de prédio e a atribuição de tipo, loja e nome aos prédios da cidade.

const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const Palette := preload("res://scripts/art/palette.gd")

const SEEDS := [2024, 1, 7, 42, 1986, 12345]

var city


func before_each() -> void:
	city = CityLayout.new()


func _counts(layout) -> Dictionary:
	var counts := {}
	for b in layout.buildings:
		counts[b.type] = counts.get(b.type, 0) + 1
	return counts


# --- tabela ---

func test_table_lists_every_type_once() -> void:
	# a casa do agente fica fora do ORDER: é uma das casas, escolhida depois do sorteio
	assert_eq(BuildingDefs.ORDER.size() + 1, BuildingDefs.DEFS.size())
	for type in BuildingDefs.ORDER:
		assert_true(BuildingDefs.exists(type), type)
	assert_true(BuildingDefs.exists("agent_home"))
	assert_eq(BuildingDefs.DEFS.size(), 25, "21 urbanos + redação do jornal + 2 rurais + casa do agente")
	assert_false(BuildingDefs.exists("castelo"))
	assert_eq(BuildingDefs.def("castelo"), {})


func test_every_type_has_complete_data() -> void:
	for type in BuildingDefs.ORDER:
		var def: Dictionary = BuildingDefs.def(type)
		assert_ne(def.name, "", type)
		assert_ne(def.service, "", type)
		assert_gt((def.districts as Array).size(), 0.0, type)
		assert_eq((def.hours as Array).size(), 2, type)
		assert_true(def.hours[0] >= 0 and def.hours[1] <= 24, type)
		for district in def.districts:
			assert_true(district == "country" or DistrictLayout.IDS.has(district), "%s: bairro %s" % [type, district])
		if def.get("no_sign", false):
			continue
		assert_true(Palette.has_color(def.sign_fg), type)
		assert_true(Palette.has_color(def.sign_bg), type)
		assert_ne(def.sign_fg, def.sign_bg, type)
		if def.get("awning", "") != "":
			assert_true(Palette.TONES.has(def.awning), type)


func test_quota_types_and_fill_types_do_not_mix() -> void:
	for type in BuildingDefs.ORDER:
		var def: Dictionary = BuildingDefs.def(type)
		if (def.districts as Array).has("country"):
			continue
		var has_quota: bool = BuildingDefs.min_count(type) > 0
		var fills: bool = def.get("fill", 0) > 0
		assert_true(has_quota != fills, "%s precisa de cota ou de peso de preenchimento" % type)
		if has_quota:
			assert_true(BuildingDefs.max_count(type) >= BuildingDefs.min_count(type), type)


func test_every_district_has_a_fill_type() -> void:
	for district in DistrictLayout.IDS:
		var found := false
		for type in BuildingDefs.ORDER:
			var def: Dictionary = BuildingDefs.def(type)
			if def.get("fill", 0) > 0 and (def.districts as Array).has(district):
				found = true
		assert_true(found, district)


func test_shops_sell_what_they_always_sold() -> void:
	# as lojas viraram entradas da tabela sem perder o estoque
	assert_eq(BuildingDefs.shop_of("armory"), "armory")
	assert_eq(BuildingDefs.shop_of("pharmacy"), "pharmacy")
	assert_eq(BuildingDefs.shop_of("agent_store"), "agent_store")
	assert_eq(BuildingDefs.shop_of("farm_store"), "farm_store")
	assert_eq(BuildingDefs.shop_of("bar"), "")
	assert_eq(ShopDefs.stock("armory"), ["pistol", "shotgun", "taser"])
	assert_eq(ShopDefs.stock("pharmacy"), ["medkit"])
	assert_eq(ShopDefs.stock("agent_store"), ["shield", "taser", "medkit"])
	assert_eq(ShopDefs.stock("farm_store"), ["medkit", "shotgun"])
	for type in BuildingDefs.ORDER:
		if BuildingDefs.shop_of(type) != "":
			assert_true(ShopDefs.exists(BuildingDefs.shop_of(type)), type)


func test_staff_and_homes() -> void:
	assert_true(BuildingDefs.staff_of("bar").has("bartender"))
	assert_eq(BuildingDefs.staff_of("house"), [])
	assert_eq(BuildingDefs.staff_of("castelo"), [])
	assert_true(BuildingDefs.is_home("house"))
	assert_true(BuildingDefs.is_home("apartment"))
	assert_true(BuildingDefs.is_home("farm"))
	assert_false(BuildingDefs.is_home("bank"))
	assert_eq(BuildingDefs.type_name("police"), "Delegacia")
	assert_eq(BuildingDefs.type_name("castelo"), "")


func test_opening_hours() -> void:
	assert_true(BuildingDefs.is_open("bank", 9.0))
	assert_true(BuildingDefs.is_open("bank", 16.9))
	assert_false(BuildingDefs.is_open("bank", 17.0))
	assert_false(BuildingDefs.is_open("bank", 3.0))
	# horário que vira a meia-noite
	assert_true(BuildingDefs.is_open("bar", 23.0))
	assert_true(BuildingDefs.is_open("bar", 2.5))
	assert_false(BuildingDefs.is_open("bar", 3.0))
	assert_false(BuildingDefs.is_open("bar", 12.0))
	assert_true(BuildingDefs.is_open("club", 0.0))
	# 24 horas
	for hour in [0.0, 6.0, 12.0, 23.9]:
		assert_true(BuildingDefs.is_open("police", hour))
		assert_true(BuildingDefs.is_open("house", hour))
	assert_true(BuildingDefs.is_open("bank", 33.5), "hora acima de 24 dá a volta")


func test_size_rule() -> void:
	assert_true(BuildingDefs.fits("police", Rect2(0, 0, 280, 260)))
	assert_false(BuildingDefs.fits("police", Rect2(0, 0, 200, 300)), "delegacia precisa de 280 de largura")
	assert_true(BuildingDefs.fits("bar", Rect2(0, 0, 160, 160)))
	assert_false(BuildingDefs.fits("bar", Rect2(0, 0, 160, 140)))
	assert_true(BuildingDefs.fits("farm", Rect2(0, 0, 10, 10)))


# --- atribuição ---

func test_every_building_has_a_type_and_a_name() -> void:
	for s in SEEDS:
		var layout := CityLayout.new(s)
		for b in layout.buildings:
			assert_true(BuildingDefs.exists(b.type), "seed %d, prédio %d sem tipo" % [s, b.id])
			assert_ne(b.name, "", "seed %d, prédio %d sem nome" % [s, b.id])


func test_minimum_and_maximum_counts_are_respected_in_any_seed() -> void:
	for s in SEEDS:
		var counts := _counts(CityLayout.new(s))
		for type in BuildingDefs.ORDER:
			var minimum := BuildingDefs.min_count(type)
			if minimum == 0:
				continue
			var n: int = counts.get(type, 0)
			assert_true(n >= minimum and n <= BuildingDefs.max_count(type),
				"seed %d: %d x %s (de %d a %d)" % [s, n, type, minimum, BuildingDefs.max_count(type)])


func test_story_types_exist_in_any_seed() -> void:
	# roteiro-jogo.md 1.1: a campanha precisa destes prédios em qualquer mapa
	for s in SEEDS + [3, 4, 5, 6, 8, 9, 10]:
		var counts := _counts(CityLayout.new(s))
		for type in BuildingDefs.STORY_TYPES:
			assert_gt(counts.get(type, 0), 0.0, "seed %d sem %s" % [s, type])


func test_minimum_size_is_respected() -> void:
	for s in SEEDS:
		for b in CityLayout.new(s).buildings:
			if BuildingDefs.min_count(b.type) > 0:
				assert_true(BuildingDefs.fits(b.type, b.rect), "seed %d: %s pequeno demais (%s)" % [s, b.name, str((b.rect as Rect2).size)])


func test_types_land_in_their_districts() -> void:
	for s in SEEDS:
		for b in CityLayout.new(s).buildings:
			assert_true((BuildingDefs.def(b.type).districts as Array).has(b.district),
				"seed %d: %s (%s) no bairro %s" % [s, b.name, b.type, b.district])


func test_service_buildings_are_a_fair_share_of_the_city() -> void:
	var services := 0
	for b in city.buildings:
		if BuildingDefs.min_count(b.type) > 0:
			services += 1
	assert_true(services >= 39 and services <= 56, "%d prédios com serviço" % services)
	assert_gt(float(city.buildings.size()), services * 2.0, "a maioria é moradia, escritório ou armazém")


func test_types_cap_the_floors() -> void:
	for b in city.buildings:
		var def: Dictionary = BuildingDefs.def(b.type)
		if def.has("max_floors"):
			assert_true(b.floors <= def.max_floors, b.name)


func test_assignment_is_deterministic() -> void:
	var a := CityLayout.new(9)
	var b := CityLayout.new(9)
	for i in a.buildings.size():
		assert_eq(a.buildings[i].type, b.buildings[i].type)
		assert_eq(a.buildings[i].name, b.buildings[i].name)
		assert_eq(a.buildings[i].district, b.buildings[i].district)
		assert_eq(a.buildings[i].floors, b.buildings[i].floors)


func test_door_is_reachable_from_the_sidewalk() -> void:
	# da porta até a calçada de baixo do lote não há prédio nem árvore no caminho
	for b in city.buildings:
		var door: Rect2 = b.door
		var lot := Rect2()
		for candidate in city.lots:
			if candidate.grow(0.5).encloses(b.rect):
				lot = candidate
		assert_gt(lot.size.x, 0.0, "prédio %d fora de lote" % b.id)
		var path := Rect2(door.position.x, door.position.y, door.size.x, lot.end.y + CityLayout.SIDEWALK / 2.0 - door.position.y)
		if b.get("forced", "") == "house":
			# as casas da fileira de cima abrem para o beco: basta o espaço do jogador à frente
			path = Rect2(door.position.x, door.position.y, door.size.x, door.size.y + CityLayout.EXIT_SPAWN_OFFSET + 24.0)
		for other in city.buildings:
			if other.id != b.id:
				assert_false((other.rect as Rect2).intersects(path), "prédio %d bloqueia a porta de %d" % [other.id, b.id])
		for t in city.trees:
			assert_false(path.grow(12.0).has_point(t), "árvore na frente da porta de %d" % b.id)


func test_farms_have_types_and_names() -> void:
	var country := CountryLayout.new(Vector2(6720, 0))
	var stores := 0
	var names := {}
	for b in country.buildings:
		assert_true(b.type == "farm" or b.type == "farm_store")
		assert_eq(b.shop, BuildingDefs.shop_of(b.type))
		assert_ne(b.name, "")
		names[b.name] = true
		if b.type == "farm_store":
			stores += 1
			assert_true(b.name.begins_with("Armazém Rural"))
		else:
			assert_true(b.name.begins_with("Fazenda"))
	assert_eq(stores, 1)
	assert_eq(names.size(), country.buildings.size(), "fazendas com nome repetido")
