extends "res://tests/base_test.gd"
## Interiores por tipo de prédio: tamanho, planta, móveis, vagas de NPC, zonas de serviço
## e a validação de caminho (entrada -> saída e todas as zonas).

const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const Services := preload("res://scripts/interior/services.gd")
const FurnitureArt := preload("res://scripts/art/furniture_art.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")
const ParserTest := preload("res://tests/unit/test_plan_parser.gd")

const IDS := 20


func _signature(layout) -> Array:
	return [layout.size, layout.mirrored, layout.walls, layout.items, layout.npc_slots, layout.zones, layout.rooms]


# --- tamanho ---

func test_interior_is_bigger_than_the_building() -> void:
	# Proporção interna diferente da externa (como em Retro City), mas do tamanho da tela ou pouco maior.
	var building_size: float = CityLayout.BLOCK - CityLayout.ROAD
	for type in BuildingDefs.ORDER:
		var size: Vector2 = InteriorLayout.new(1, type).size
		assert_gt(size.x, building_size * 3.0, type)
		assert_true(size.x <= 1792.0 and size.y <= 1024.0, "%s grande demais: %s" % [type, size])


func test_size_comes_from_the_plan_not_the_facade() -> void:
	assert_eq(InteriorLayout.size_class_for("armory"), "P")
	assert_eq(InteriorLayout.size_class_for("bar"), "M")
	assert_eq(InteriorLayout.size_class_for("hotel"), "G")
	assert_eq(InteriorLayout.size_class_for("diner"), "P")
	for facade in [150.0, 240.0, 320.0]:
		assert_eq(InteriorLayout.size_class_for("office", facade), "M")
		assert_eq(InteriorLayout.new(3, "office", facade).size, Vector2(1536, 864))


func test_every_building_type_has_a_plan() -> void:
	for type in BuildingDefs.ORDER + ["agent_home"]:
		assert_true(InteriorLayout.is_planned(type), type)
		assert_eq(InteriorLayout.new(1, type).template, type)
	assert_eq(Plans.types().size(), 25, "24 tipos de prédio + a casa do agente")


func test_unknown_type_uses_the_house_plan() -> void:
	var layout := InteriorLayout.new(2, "castelo")
	assert_eq(layout.template, "house")
	assert_eq(layout.size_class, "P")
	_check(layout, "castelo")


# --- determinismo (V2) ---

func test_same_building_gives_the_same_interior() -> void:
	for type in BuildingDefs.ORDER:
		for id in [0, 7, 63]:
			assert_eq(_signature(InteriorLayout.new(id, type)), _signature(InteriorLayout.new(id, type)), "%s %d" % [type, id])


func test_different_buildings_of_a_type_differ() -> void:
	for type in ["bar", "hotel", "house", "warehouse", "armory", "office"]:
		var seen := {}
		for id in 12:
			seen[str(_signature(InteriorLayout.new(id, type)))] = true
		assert_gt(seen.size(), 2.0, "interiores de %s todos iguais" % type)


func test_some_interiors_are_mirrored() -> void:
	var mirrored := 0
	for id in 40:
		if InteriorLayout.new(id, "bar").mirrored:
			mirrored += 1
	assert_true(mirrored > 8 and mirrored < 32, "%d espelhados de 40" % mirrored)


func test_types_have_different_plans() -> void:
	var plans := {}
	for type in ["bar", "hotel", "bank", "police", "hospital", "cinema", "gym", "office", "house", "warehouse", "hq", "club", "workshop", "restaurant", "armory"]:
		var kinds := {}
		for item in InteriorLayout.new(5, type).items:
			kinds[item.kind] = true
		var list := kinds.keys()
		list.sort()
		plans[str(list)] = true
	assert_eq(plans.size(), 15, "cada modelo tem o seu conjunto de móveis")


# --- validade (V5) ---

func _check(layout, label: String) -> void:
	var room: Rect2 = layout.room_rect()
	var solids: Array[Rect2] = layout.solids()
	for item in layout.items:
		assert_true(room.encloses(item.rect), "%s: %s fora da sala" % [label, item.kind])
		assert_true(FurnitureArt.has_kind(item.kind), "%s: móvel sem desenho: %s" % [label, item.kind])
	for i in solids.size():
		assert_false(solids[i].intersects(layout.clear_zone()), "%s: sólido na área da saída" % label)
		assert_false(solids[i].has_point(layout.spawn_point()), "%s: sólido na entrada" % label)
		assert_false(solids[i].intersects(layout.exit_door()), "%s: sólido na porta" % label)
	for i in layout.furniture.size():
		for j in range(i + 1, layout.furniture.size()):
			assert_false(layout.furniture[i].intersects(layout.furniture[j]), "%s: móveis sobrepostos" % label)
		for wall in layout.walls:
			assert_false(layout.furniture[i].intersects(wall), "%s: móvel dentro de parede" % label)
	for slot in layout.npc_slots:
		assert_true(room.grow(-12.0).has_point(slot.position), "%s: vaga de %s fora da sala" % [label, slot.role])
		if slot.get("act", "post") in ["sit", "lie", "exercise"]:
			continue  # sentado ou deitado fica sobre o móvel por definição
		for solid in solids:
			assert_false(solid.grow(10.0).has_point(slot.position), "%s: vaga de %s dentro de um sólido" % [label, slot.role])
	for z in layout.zones:
		assert_true(room.encloses(z.rect), "%s: zona %s fora da sala" % [label, z.id])
		assert_ne(z.verb, "", "%s: zona %s sem verbo" % [label, z.id])
	assert_eq(layout.unreachable(), [] as Array[String], "%s: caminho bloqueado" % label)


func test_every_type_gives_a_valid_interior() -> void:
	for type in BuildingDefs.ORDER:
		for id in IDS:
			_check(InteriorLayout.new(id, type), "%s %d" % [type, id])


func test_blocked_path_is_detected() -> void:
	var layout := InteriorLayout.new(2, "hotel")
	assert_eq(layout.unreachable(), [] as Array[String])
	# uma parede de lado a lado em frente à entrada isola a saída do resto
	layout.walls.append(Rect2(0, layout.size.y - 300.0, layout.size.x, 16))
	assert_true(layout.unreachable().has("zona sleep"))


func test_exit_door_and_spawn() -> void:
	for type in ["house", "bar", "hotel"]:
		var layout := InteriorLayout.new(4, type)
		assert_true(layout.room_rect().encloses(layout.exit_door()))
		assert_false(layout.exit_door().has_point(layout.spawn_point()))
		assert_true(layout.room_rect().has_point(layout.spawn_point()))
		assert_true(layout.clear_zone().has_point(layout.spawn_point()))
		assert_almost_eq(layout.exit_door().end.y, layout.size.y, 0.01, "saída na parede sul")


# --- conteúdo por tipo ---

func test_rooms_and_inner_walls() -> void:
	for type in ["hotel", "police", "hospital", "office", "house", "cinema", "hq", "bank"]:
		var layout := InteriorLayout.new(3, type)
		assert_gt(layout.rooms.size(), 0.0, type)
		assert_gt(layout.walls.size(), 1.0, type)
		for room in layout.rooms:
			assert_true(layout.room_rect().grow(1.0).encloses(room.rect), "%s: cômodo %s fora" % [type, room.name])
			assert_true(TileFactory.has_tile(room.floor), room.floor)
			assert_ne(room.name, "")


func test_recognizable_furniture_by_type() -> void:
	var expected := {"hotel": ["double_bed", "counter", "sofa"], "restaurant": ["dining_table", "stove"], "bar": ["counter", "bar_stool", "pool_table"],
		"armory": ["gun_rack", "counter"], "police": ["cell_bars", "bunk", "desk"], "hospital": ["hospital_bed", "cabinet"],
		"bank": ["vault", "counter"], "cinema": ["seats", "movie_screen"], "gym": ["ring", "treadmill", "weights"],
		"workshop": ["car_lift", "workbench", "tires"], "club": ["dj_booth", "speaker"], "house": ["bed", "sofa", "stove", "tv"],
		"warehouse": ["forklift"], "hq": ["washer", "washer_secret", "briefing_table", "wall_screen"], "office": ["desk", "photocopier"]}
	for type in expected:
		var kinds := {}
		for item in InteriorLayout.new(6, type).items:
			kinds[item.kind] = true
		for kind in expected[type]:
			assert_true(kinds.has(kind), "%s sem %s" % [type, kind])


func test_hotel_has_three_furnished_rooms() -> void:
	# planta do hotel (Fase 7): três quartos fixos, cada um com cama de casal
	for id in 20:
		var beds := 0
		for item in InteriorLayout.new(id, "hotel").items:
			if item.kind == "double_bed":
				beds += 1
		assert_eq(beds, 3, "hotel %d" % id)


func test_every_service_has_a_zone() -> void:
	for type in Services.BY_TYPE:
		for id in 5:
			var layout := InteriorLayout.new(id, type)
			for service in Services.for_type(type):
				var z: Dictionary = layout.zone(service)
				assert_false(z.is_empty(), "%s sem zona de %s" % [type, service])
				assert_eq(z.verb, Services.verb(service))
	assert_eq(InteriorLayout.new(1, "house").zones.size(), 0, "moradia só tem conversa")
	assert_eq(InteriorLayout.new(1, "bar").zone("sleep"), {})


func test_shops_keep_counter_merchant_and_buy_zone() -> void:
	for type in ["armory", "pharmacy", "agent_store", "farm_store", "market", "gas_station"]:
		for id in 6:
			var layout := InteriorLayout.new(id, type)
			assert_true(layout.is_shop, type)
			assert_eq(layout.shop, BuildingDefs.shop_of(type))
			var zone: Rect2 = layout.counter_zone()
			assert_almost_eq(zone.position.y, layout.counter.end.y, 0.001)
			assert_true(layout.room_rect().encloses(zone))
			assert_false(zone.intersects(layout.counter))
			assert_true(layout.merchant_position().y < layout.counter.position.y)
			assert_eq(layout.zone("shop").rect, zone)
			assert_true(layout.furniture.has(layout.counter))
			assert_eq(layout.npc_slots[0].position, layout.merchant_position(), "o vendedor é a primeira vaga")
			for r in layout.furniture:
				assert_false(r.intersects(zone), "%s: móvel na zona de compra" % type)
	assert_false(InteriorLayout.new(1, "bar").is_shop)
	assert_true(InteriorLayout.new(1, "armory").is_shop)


func test_staff_slots_use_the_roles_of_the_building_type() -> void:
	for type in BuildingDefs.ORDER:
		var staff := BuildingDefs.staff_of(type)
		if staff.is_empty() or type == "farm" or type == "warehouse":
			continue
		var layout := InteriorLayout.new(2, type)
		var found := 0
		for slot in layout.npc_slots:
			if slot.staff and staff.has(slot.role):
				found += 1
		assert_gt(found, 0.0, "%s sem funcionário" % type)


func test_guests_vary_and_have_roles() -> void:
	var counts := {}
	for id in 30:
		var guests := 0
		var spots := []
		for slot in InteriorLayout.new(id, "bar").npc_slots:
			assert_ne(slot.role, "")
			if not slot.staff:
				guests += 1
				spots.append(slot.position)
		counts[str(spots)] = true  # o total é completado até o mínimo; o que varia são os lugares
		assert_true(guests >= 2 and guests <= 8, "bar com %d clientes" % guests)
	assert_gt(counts.size(), 1.0)
	var residents := 0
	for id in 30:
		for slot in InteriorLayout.new(id, "house").npc_slots:
			assert_eq(slot.role, "morador")
			residents += 1
	assert_gt(residents, 5.0)


func test_club_has_an_informant() -> void:
	var layout := InteriorLayout.new(1, "club")
	var roles := []
	for slot in layout.npc_slots:
		roles.append(slot.role)
	assert_true(roles.has("informante"))
	assert_true(roles.has("DJ"))


# --- arte dos móveis ---

func test_every_furniture_kind_is_drawn_with_palette_colors() -> void:
	for kind in FurnitureArt.kinds():
		var canvas: RefCounted = FurnitureArt.canvas(kind, 48, 32)
		assert_eq(Vector2i(canvas.width, canvas.height), Vector2i(48, 32), kind)
		assert_true(canvas.only_palette_colors(), kind)
		if not FurnitureArt.ON_KINDS.has(kind):
			assert_gt(canvas.opaque_count(), 100.0, kind)
		assert_eq(FurnitureArt.tones(kind).size(), 3, kind)
	assert_false(FurnitureArt.has_kind("trono"))


func test_furniture_art_is_cached_per_kind_and_size() -> void:
	assert_true(FurnitureArt.canvas("bed", 64, 44) == FurnitureArt.canvas("bed", 64, 44))
	assert_false(FurnitureArt.canvas("bed", 64, 44) == FurnitureArt.canvas("bed", 44, 64))
	assert_ne(FurnitureArt.canvas("bed", 64, 44).image.get_data(), FurnitureArt.canvas("sofa", 64, 44).image.get_data())


func test_used_furniture_renders_at_its_real_size() -> void:
	for type in ["hotel", "club", "hq", "workshop", "gym"]:
		for item in InteriorLayout.new(2, type).items:
			var w := int(item.rect.size.x / 2.0)
			var h := int(item.rect.size.y / 2.0)
			var canvas: RefCounted = FurnitureArt.canvas(item.kind, w, h)
			assert_true(canvas.only_palette_colors(), "%s %dx%d" % [item.kind, w, h])


# --- plantas (mapa de texto) ---

func test_injected_plan_is_used() -> void:
	Plans.override("cinema", ParserTest.fixture())
	var layout := InteriorLayout.new(3, "cinema")
	assert_true(layout.planned)
	assert_true(InteriorLayout.is_planned("cinema"))
	assert_eq(layout.size, Vector2(1280, 736))
	assert_eq(InteriorLayout.size_class_for("cinema", 300.0), "P", "a fachada não muda o tamanho da planta")
	assert_eq(layout.exit_door().size.x, 96.0)
	assert_true(layout.clear_zone().has_point(layout.spawn_point()))
	assert_gt(float(layout.wall_faces.size()), 0.0)
	assert_gt(float(layout.floor_rects.size()), 0.0)
	_check(layout, "planta injetada")
	Plans.clear_overrides()
	assert_eq(InteriorLayout.new(3, "cinema").size, Vector2(1792, 1024), "volta para a planta do cinema")


func test_planned_zones_get_the_service_verb() -> void:
	Plans.override("cinema", ParserTest.fixture())
	var layout := InteriorLayout.new(5, "cinema")
	assert_eq(layout.zone("heal").verb, Services.verb("heal"))
	Plans.clear_overrides()


# --- móveis na escala do personagem (texels = px / 2) ---

const NEW_FURNITURE := {"armchair": [24, 24], "double_bed": [40, 40], "chair": [16, 16], "office_chair": [16, 16],
	"floor_lamp": [16, 16], "fireplace": [48, 16], "record_player": [24, 16], "dresser": [40, 16],
	"round_table": [32, 32], "bar_stool": [12, 12], "beer_taps": [32, 12], "interrogation_table": [48, 32],
	"flag": [16, 16], "coffee_machine": [16, 16], "kitchen_counter": [32, 16],
	"teller": [48, 16], "column": [16, 16], "luggage_cart": [24, 16], "dining_table": [32, 32], "booth": [32, 24],
	"griddle": [32, 16], "milkshake": [16, 16], "dance_floor": [64, 48], "cleaning_cart": [24, 16],
	"target": [16, 16], "display_case": [48, 16], "freezer": [48, 24], "checkout": [32, 16], "shopping_cart": [16, 12],
	"feed_sacks": [32, 24], "barrel": [16, 16], "mannequin": [16, 16], "scale": [16, 16], "drink_fridge": [32, 16],
	"compressor": [16, 16], "punching_bag": [16, 16], "bench_press": [32, 16], "exercise_bike": [16, 24],
	"shower": [16, 16], "turnstile": [16, 16], "newspaper_stack": [16, 16], "photocopier": [32, 16], "projector": [24, 16]}


func test_new_kinds_have_art_at_real_scale() -> void:
	for kind in NEW_FURNITURE:
		var size: Array = NEW_FURNITURE[kind]
		assert_true(FurnitureArt.has_kind(kind), kind)
		var canvas: RefCounted = FurnitureArt.canvas(kind, size[0], size[1])
		assert_true(canvas.only_palette_colors(), kind)
		assert_gt(float(canvas.opaque_count()), size[0] * size[1] * 0.4, kind)
	for kind in FurnitureArt.WALL_KINDS:
		var canvas: RefCounted = FurnitureArt.canvas(kind, 16, 12)
		assert_true(canvas.only_palette_colors(), kind)
		assert_gt(float(canvas.opaque_count()), 16 * 12 * 0.4, kind)
	for kind in FurnitureArt.ON_KINDS:
		var canvas: RefCounted = FurnitureArt.canvas(kind, 8, 8)
		assert_true(canvas.only_palette_colors(), kind)
		assert_gt(float(canvas.opaque_count()), 8 * 8 * 0.2, kind)


func test_tone_changes_the_art() -> void:
	var blue: RefCounted = FurnitureArt.canvas("sofa", 48, 24, "blue")
	var plain: RefCounted = FurnitureArt.canvas("sofa", 48, 24)
	assert_ne(blue.image.get_data(), plain.image.get_data())
	assert_true(blue.only_palette_colors())
	assert_ne(FurnitureArt.cache_key("sofa", 48, 24, "blue"), FurnitureArt.cache_key("sofa", 48, 24))


func test_wall_and_on_kinds_are_listed() -> void:
	assert_eq(FurnitureArt.WALL_KINDS.size(), 26)
	assert_true(FurnitureArt.WALL_KINDS.has("roll_door"))
	assert_true(FurnitureArt.WALL_KINDS.has("whiteboard"))
	assert_true(FurnitureArt.ON_KINDS.has("typewriter"))
	for kind in ["gun_rack", "tool_rack", "cross_sign"]:
		assert_true(FurnitureArt.WALL_KINDS.has(kind), kind)
	assert_eq(FurnitureArt.ON_KINDS.size(), 19)
	for kind in ["neon", "key_rack", "elevator_door", "menu_board"]:
		assert_true(FurnitureArt.WALL_KINDS.has(kind), kind)
	for kind in ["candle", "bell", "cash_register"]:
		assert_true(FurnitureArt.ON_KINDS.has(kind), kind)
	for kind in FurnitureArt.WALL_KINDS + FurnitureArt.ON_KINDS:
		assert_true(FurnitureArt.has_kind(kind), kind)


func test_planned_shop_keeps_counter_merchant_and_buy_zone() -> void:
	Plans.override("armory", ParserTest.shop_fixture())
	for id in 6:
		var layout := InteriorLayout.new(id, "armory")
		assert_true(layout.planned and layout.is_shop)
		var zone: Rect2 = layout.counter_zone()
		assert_almost_eq(zone.position.y, layout.counter.end.y, 0.001)
		assert_eq(layout.zone("shop").rect, zone)
		assert_true(layout.furniture.has(layout.counter))
		assert_eq(layout.npc_slots[0].position, layout.merchant_position(), "o vendedor é a primeira vaga")
		assert_true(layout.npc_slots[0].staff)
		assert_eq(layout.npc_slots[0].role, BuildingDefs.staff_of("armory")[0])
		for r in layout.furniture:
			assert_false(r.intersects(zone), "móvel na zona de compra")
		_check(layout, "loja planejada %d" % id)
	Plans.clear_overrides()
