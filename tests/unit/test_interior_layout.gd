extends "res://tests/base_test.gd"
## Interiores por tipo de prédio: tamanho, planta, móveis, vagas de NPC, zonas de serviço
## e a validação de caminho (entrada -> saída e todas as zonas).

const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const Services := preload("res://scripts/interior/services.gd")
const FurnitureArt := preload("res://scripts/art/furniture_art.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")

const IDS := 20


func _signature(layout) -> Array:
	return [layout.size, layout.mirrored, layout.walls, layout.items, layout.npc_slots, layout.zones, layout.rooms]


# --- tamanho ---

func test_interior_is_much_bigger_than_building() -> void:
	# Proporção interna diferente da externa (como em Retro City).
	var building_size: float = CityLayout.BLOCK - CityLayout.ROAD
	for class_id in InteriorLayout.SIZE_ORDER:
		assert_gt(InteriorLayout.SIZES[class_id].x, building_size * 3.0)
	assert_gt(InteriorLayout.new(1, "hotel").size.x, building_size * 4.0)


func test_size_follows_type_and_facade_width() -> void:
	assert_eq(InteriorLayout.size_class_for("armory"), "P")
	assert_eq(InteriorLayout.size_class_for("bar"), "M")
	assert_eq(InteriorLayout.size_class_for("hotel"), "G")
	assert_eq(InteriorLayout.size_class_for("restaurant"), "M")
	assert_eq(InteriorLayout.size_class_for("diner"), "P", "lanchonete usa a planta do restaurante, menor")
	# fachada estreita desce um degrau; larga sobe um
	assert_eq(InteriorLayout.size_class_for("bar", 150.0), "P")
	assert_eq(InteriorLayout.size_class_for("bar", 300.0), "G")
	assert_eq(InteriorLayout.size_class_for("house", 150.0), "P", "não desce abaixo do menor")
	assert_eq(InteriorLayout.size_class_for("hotel", 300.0), "G", "não sobe acima do maior")
	assert_eq(InteriorLayout.new(3, "bar", 300.0).size, InteriorLayout.SIZES["G"])


func test_every_building_type_has_a_template() -> void:
	for type in BuildingDefs.ORDER:
		assert_true(InteriorLayout.TEMPLATES.has(type), type)
	for type in InteriorLayout.TEMPLATES:
		var template: String = InteriorLayout.TEMPLATES[type]
		assert_true(InteriorLayout.BASE_SIZE.has(template), template)
		assert_true(TileFactory.has_tile(InteriorLayout.FLOORS[template]), template)
	assert_eq(InteriorLayout.BASE_SIZE.size(), 16, "15 modelos de interior + a casa do agente")
	assert_eq(InteriorLayout.template_of("castelo"), InteriorLayout.DEFAULT_TEMPLATE)


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


func test_interiors_stay_valid_in_every_size() -> void:
	for type in BuildingDefs.ORDER:
		for width in [150.0, 300.0]:
			for id in 4:
				_check(InteriorLayout.new(id, type, width), "%s %d (fachada %d)" % [type, id, int(width)])


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
	var expected := {"hotel": ["bed", "counter", "sofa"], "restaurant": ["table", "stove"], "bar": ["counter", "stool", "pool_table"],
		"armory": ["shelf", "counter"], "police": ["cell_bars", "bunk", "desk"], "hospital": ["hospital_bed", "cabinet"],
		"bank": ["vault", "counter"], "cinema": ["seats", "movie_screen"], "gym": ["ring", "treadmill", "weights"],
		"workshop": ["car_lift", "workbench", "tires"], "club": ["dj_booth", "speaker"], "house": ["bed", "sofa", "stove", "tv"],
		"warehouse": ["forklift"], "hq": ["washer", "washer_secret", "briefing_table", "wall_screen"], "office": ["desk", "cabinet"]}
	for type in expected:
		var kinds := {}
		for item in InteriorLayout.new(6, type).items:
			kinds[item.kind] = true
		for kind in expected[type]:
			assert_true(kinds.has(kind), "%s sem %s" % [type, kind])


func test_hotel_rooms_vary_with_the_seed() -> void:
	var beds := {}
	for id in 20:
		var count := 0
		for item in InteriorLayout.new(id, "hotel").items:
			if item.kind == "bed":
				count += 1
		beds[count] = true
		assert_true(count >= 4 and count <= 6, "hotel com %d camas" % count)
	assert_gt(beds.size(), 1.0)


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
		assert_true(guests >= 2 and guests <= InteriorLayout.MIN_PEOPLE["M"], "bar com %d clientes" % guests)
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
