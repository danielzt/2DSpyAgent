extends "res://tests/base_test.gd"
## As plantas de interior em mapa de texto (Fase 7): todas válidas, únicas, na escala do personagem,
## com variação entre prédios do mesmo tipo; e o conteúdo de cada planta.

const PlanParser := preload("res://scripts/interior/plan_parser.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const FurnitureArt := preload("res://scripts/art/furniture_art.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const Services := preload("res://scripts/interior/services.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")

const IDS := 20


func _signature(layout) -> String:
	return str([layout.mirrored, layout.variant, layout.items, layout.npc_slots, layout.floor_rects])


## Mesmo conjunto de verificações de test_interior_layout._check, para as plantas.
func _check(layout, label: String) -> void:
	var room: Rect2 = layout.room_rect()
	var solids: Array[Rect2] = layout.solids()
	for item in layout.items:
		assert_true(room.encloses(item.rect), "%s: %s fora da sala" % [label, item.kind])
		assert_true(FurnitureArt.has_kind(item.kind), "%s: móvel sem desenho: %s" % [label, item.kind])
	for s in solids:
		assert_false(s.intersects(layout.clear_zone()), "%s: sólido na área da saída" % label)
		assert_false(s.intersects(layout.exit_door()), "%s: sólido na porta" % label)
	for i in layout.furniture.size():
		for j in range(i + 1, layout.furniture.size()):
			assert_false(layout.furniture[i].intersects(layout.furniture[j]), "%s: móveis sobrepostos %s %s" % [label, layout.furniture[i], layout.furniture[j]])
		for wall in layout.walls:
			assert_false(layout.furniture[i].intersects(wall), "%s: móvel dentro de parede %s" % [label, layout.furniture[i]])
	for room_entry in layout.rooms:
		assert_true(TileFactory.has_tile(room_entry.floor), "%s: piso %s" % [label, room_entry.floor])
		assert_true(TileFactory.has_face(room_entry.wall), "%s: parede %s" % [label, room_entry.wall])
	for z in layout.zones:
		assert_ne(z.verb, "", "%s: zona %s sem verbo" % [label, z.id])
	assert_eq(layout.unreachable(), [] as Array[String], "%s: caminho bloqueado" % label)


func _kinds(layout) -> Dictionary:
	var kinds := {}
	for item in layout.items:
		kinds[item.kind] = kinds.get(item.kind, 0) + 1
	return kinds


func _room_names(layout) -> Array:
	var names := []
	for room in layout.rooms:
		if not names.has(room.name):
			names.append(room.name)
	return names


# --- todas as plantas ---

func test_every_plan_validates() -> void:
	for type in Plans.types():
		assert_eq(PlanParser.validate(Plans.data(type)), [] as Array[String], type)


func test_every_plan_gives_a_valid_interior() -> void:
	for type in Plans.types():
		for id in IDS:
			_check(InteriorLayout.new(id, type), "%s %d" % [type, id])


func test_plans_are_unique() -> void:
	var seen := {}
	for type in Plans.types():
		var key := str(Plans.data(type).object_grid)
		assert_false(seen.has(key), "%s repete a planta de %s" % [type, seen.get(key, "")])
		seen[key] = type


func test_beds_are_to_scale() -> void:
	for type in Plans.types():
		for item in InteriorLayout.new(3, type).items:
			var size: Vector2 = item.rect.size
			if item.kind in ["bed", "hospital_bed", "bunk"]:
				assert_true(size.x <= 48.0 and size.y <= 80.0 or size.x <= 80.0 and size.y <= 48.0, "%s: %s %s" % [type, item.kind, size])
			elif item.kind == "double_bed":
				assert_true(size.x <= 80.0 and size.y <= 80.0, "%s: cama de casal %s" % [type, size])


func test_variants_differ() -> void:
	for type in Plans.types():
		var seen := {}
		for id in 12:
			seen[_signature(InteriorLayout.new(id, type))] = true
		assert_true(seen.size() >= 3, "%s: só %d variações" % [type, seen.size()])
		assert_true(Plans.data(type).get("variants", []).size() >= 2, "%s: menos de 2 variantes" % type)


# --- casa ---

func test_house_plan() -> void:
	assert_true(Plans.has("house"))
	for id in IDS:
		var layout := InteriorLayout.new(id, "house")
		assert_eq(layout.size_class, "P")
		for name in ["Sala", "Cozinha", "Quarto do casal", "Quarto das crianças", "Banheiro"]:
			assert_true(_room_names(layout).has(name), "casa %d sem %s" % [id, name])
		var kinds := _kinds(layout)
		for kind in ["sofa", "armchair", "tv", "stove", "fridge", "sink", "double_bed", "bed", "nightstand",
				"wardrobe", "toilet", "bathtub", "rug"]:
			assert_true(kinds.has(kind), "casa %d sem %s" % [id, kind])
		assert_true(kinds.has("table") or kinds.has("round_table"), "casa %d sem mesa" % id)
		assert_true(layout.npc_slots.size() >= 2 and layout.npc_slots.size() <= 3, "casa %d: %d pessoas" % [id, layout.npc_slots.size()])
		for slot in layout.npc_slots:
			assert_eq(slot.role, "morador")
			assert_false(slot.staff)
		assert_eq(layout.zones.size(), 0)


# --- casa do agente ---

func test_agent_home_plan() -> void:
	assert_true(Plans.has("agent_home"))
	for id in IDS:
		var layout := InteriorLayout.new(id, "agent_home")
		assert_eq(layout.size_class, "M")
		for name in ["Sala", "Escritório", "Quarto", "Cozinha", "Banheiro"]:
			assert_true(_room_names(layout).has(name), "casa do agente %d sem %s" % [id, name])
		var kinds := _kinds(layout)
		for kind in ["sofa", "armchair", "rug", "wall_tv", "bookshelf", "record_player", "floor_lamp", "fireplace",
				"desk", "office_chair", "case_wall", "file_cabinet", "chest", "safe_wall", "double_bed", "wardrobe",
				"dresser", "stove", "fridge", "sink", "table", "coffee_pot", "fruit_bowl", "bathtub", "toilet", "mirror"]:
			assert_true(kinds.has(kind), "casa do agente %d sem %s" % [id, kind])
		assert_true(kinds.get("monitor", 0) >= 2, "dois monitores")
		assert_true(kinds.get("nightstand", 0) >= 2 and kinds.get("table_lamp", 0) >= 2, "criados-mudos com abajur")
		assert_true(kinds.get("chair", 0) >= 2, "cadeiras")
		assert_eq(layout.npc_slots.size(), 0, "sem estranhos")
		assert_false(layout.zone("rest").is_empty())
		assert_false(layout.zone("stash").is_empty())
	var cats := 0
	for id in IDS:
		cats += _kinds(InteriorLayout.new(id, "agent_home")).get("cat", 0)
	assert_true(cats > 0 and cats < IDS, "o gato aparece em algumas casas: %d" % cats)


# --- bar ---

func test_bar_plan() -> void:
	assert_true(Plans.has("bar"))
	for id in IDS:
		var layout := InteriorLayout.new(id, "bar")
		assert_eq(layout.size_class, "M")
		for name in ["Salão", "Balcão", "Sinuca", "Banheiro"]:
			assert_true(_room_names(layout).has(name), "bar %d sem %s" % [id, name])
		var kinds := _kinds(layout)
		for kind in ["counter", "beer_taps", "bottle_wall", "round_table", "chair", "pool_table", "dartboard",
				"jukebox", "toilet", "sink", "glass", "bottle", "ashtray", "pool_cue"]:
			assert_true(kinds.has(kind), "bar %d sem %s" % [id, kind])
		assert_true(kinds.get("bar_stool", 0) >= 4, "banquetas")
		assert_false(layout.zone("rumor").is_empty())
		var bartender := false
		for slot in layout.npc_slots:
			if slot.role == "bartender":
				bartender = slot.staff and slot.act == "work"
			if slot.staff:
				assert_false(CharacterSprites.uniform_for("bar", slot.role, true).is_empty())
		assert_true(bartender, "bartender trabalhando atrás do balcão")


# --- delegacia ---

func test_police_plan() -> void:
	assert_true(Plans.has("police"))
	for id in IDS:
		var layout := InteriorLayout.new(id, "police")
		assert_eq(layout.size_class, "M")
		for name in ["Recepção", "Sala dos agentes", "Celas", "Interrogatório", "Delegado"]:
			assert_true(_room_names(layout).has(name), "delegacia %d sem %s" % [id, name])
		var kinds := _kinds(layout)
		for kind in ["counter", "wanted_board", "office_chair", "computer", "coffee_machine", "notice_board",
				"cell_bars", "toilet", "interrogation_table", "chair", "mirror", "flag", "bookshelf", "file_cabinet", "locker"]:
			assert_true(kinds.has(kind), "delegacia %d sem %s" % [id, kind])
		assert_true(kinds.get("bench", 0) >= 2, "bancos")
		assert_true(kinds.get("desk", 0) >= 5, "mesas dos agentes e do delegado")
		assert_true(kinds.get("bunk", 0) >= 3, "beliches")
		assert_false(layout.zone("deliver").is_empty())
		var roles := {}
		for slot in layout.npc_slots:
			roles[slot.role] = true
			if slot.role == "preso" or slot.role == "visitante":
				assert_false(slot.staff)
		for role in ["policial", "delegado", "preso", "detetive", "atendente"]:
			assert_true(roles.has(role), "delegacia %d sem %s" % [id, role])


# --- hospital ---

func test_hospital_plan() -> void:
	assert_true(Plans.has("hospital"))
	for id in IDS:
		var layout := InteriorLayout.new(id, "hospital")
		assert_eq(layout.size_class, "G")
		for name in ["Recepção", "Enfermaria", "UTI", "Consultório", "Farmácia"]:
			assert_true(_room_names(layout).has(name), "hospital %d sem %s" % [id, name])
		var kinds := _kinds(layout)
		for kind in ["counter", "computer", "water_cooler", "curtain", "nightstand", "cart", "desk", "cabinet",
				"bottle_shelf", "sink", "clock", "notice_board", "stethoscope_tray", "papers"]:
			assert_true(kinds.has(kind), "hospital %d sem %s" % [id, kind])
		assert_true(kinds.get("hospital_bed", 0) >= 8, "6 leitos na enfermaria e 2 na UTI")
		assert_true(kinds.get("monitor", 0) >= 2, "monitores da UTI")
		assert_true(kinds.has("seats") or kinds.get("chair", 0) >= 8, "cadeiras da espera")
		assert_false(layout.zone("heal").is_empty())
		var lying := 0
		var staff_roles := {}
		for slot in layout.npc_slots:
			if slot.role == "paciente" and slot.act == "lie":
				lying += 1
			if slot.staff:
				staff_roles[slot.role] = true
		assert_true(lying >= 3, "hospital %d: só %d pacientes deitados" % [id, lying])
		for role in ["recepcionista", "médica", "enfermeiro", "auxiliar de enfermagem", "farmacêutico"]:
			assert_true(staff_roles.has(role), "hospital %d sem %s" % [id, role])


# --- Etapa 2: verificador comum ---

## Confere tamanho, cômodos, itens, zonas e funcionários da planta de `type` em todos os ids.
func _assert_plan(type: String, size_class: String, rooms: Array, kinds: Array, staff: Array, guests: Array) -> void:
	assert_true(Plans.has(type), "%s sem planta" % type)
	if not Plans.has(type):
		return
	for id in IDS:
		var layout := InteriorLayout.new(id, type)
		var label := "%s %d" % [type, id]
		assert_eq(layout.size_class, size_class, label)
		for name in rooms:
			assert_true(_room_names(layout).has(name), "%s sem cômodo %s" % [label, name])
		var found := _kinds(layout)
		for kind in kinds:
			assert_true(found.has(kind), "%s sem %s" % [label, kind])
		for service in Services.for_type(type):
			assert_false(layout.zone(service).is_empty(), "%s sem zona %s" % [label, service])
		var roles := {}
		for slot in layout.npc_slots:
			roles[slot.role] = slot.staff
			if slot.staff:
				assert_true(BuildingDefs.staff_of(type).has(slot.role), "%s: %s não é funcionário do tipo" % [label, slot.role])
		for role in staff:
			assert_true(roles.get(role, false), "%s sem %s" % [label, role])
		for role in guests:
			assert_true(roles.has(role) and not roles[role], "%s sem %s" % [label, role])


# --- bloco 1 ---

func test_bank_plan() -> void:
	_assert_plan("bank", "M", ["Hall", "Caixas", "Gerência", "Cofre"],
		["teller", "vault", "rope", "column", "desk", "office_chair", "bench", "clock", "safe_wall", "cell_bars"],
		["caixa", "gerente", "segurança"], ["cliente"])


func test_hotel_plan() -> void:
	_assert_plan("hotel", "G", ["Saguão", "Corredor", "Quarto 1", "Quarto 2", "Quarto 3"],
		["counter", "key_rack", "bell", "sofa", "armchair", "luggage_cart", "elevator_door", "column", "double_bed",
		"nightstand", "table_lamp", "wall_tv", "toilet", "cleaning_cart"],
		["recepcionista", "concierge"], ["hóspede"])


func test_restaurant_plan() -> void:
	_assert_plan("restaurant", "M", ["Salão", "Cozinha", "Banheiro"],
		["dining_table", "chair", "candle", "plate", "glass", "stove", "kitchen_counter", "fridge", "sink", "bottle_wall"],
		["chef", "maître", "ajudante de cozinha"], ["cliente"])


func test_diner_plan() -> void:
	_assert_plan("diner", "P", ["Salão", "Cozinha"],
		["booth", "counter", "bar_stool", "griddle", "milkshake", "jukebox", "menu_board", "neon"],
		["atendente", "balconista"], ["cliente"])


func test_club_plan() -> void:
	_assert_plan("club", "G", ["Pista", "Bar", "VIP", "Camarote", "Banheiro"],
		["dj_booth", "speaker", "counter", "bar_stool", "bottle_wall", "sofa", "rope", "neon"],
		["DJ", "bartender", "segurança"], ["dançarino", "informante"])
	var layout := InteriorLayout.new(2, "club")
	var dancers := 0
	for slot in layout.npc_slots:
		if slot.act == "dance":
			dancers += 1
	assert_true(dancers >= 4, "pista com %d dançarinos" % dancers)


# --- bloco 2: lojas ---

func _assert_shop(type: String) -> void:
	for id in 6:
		var layout := InteriorLayout.new(id, type)
		assert_true(layout.is_shop, type)
		assert_eq(layout.npc_slots[0].position, layout.merchant_position(), "%s: vendedor atrás do balcão" % type)
		assert_eq(layout.zone("shop").rect, layout.counter_zone())


func test_armory_plan() -> void:
	_assert_plan("armory", "P", ["Loja", "Estande"], ["counter", "gun_rack", "target", "display_case", "crates"],
		["balconista"], ["cliente"])
	_assert_shop("armory")


func test_pharmacy_plan() -> void:
	_assert_plan("pharmacy", "P", ["Loja", "Manipulação"], ["counter", "shelf", "cross_sign", "scale", "cabinet"],
		["balconista"], ["cliente"])
	_assert_shop("pharmacy")


func test_agent_store_plan() -> void:
	_assert_plan("agent_store", "P", ["Loja", "Depósito"], ["counter", "display_case", "mannequin", "wall_tv"],
		["balconista"], ["cliente"])
	_assert_shop("agent_store")


func test_market_plan() -> void:
	_assert_plan("market", "P", ["Loja", "Depósito"], ["checkout", "shelf", "freezer", "shopping_cart", "fruit_bowl"],
		["caixa", "estoquista"], ["cliente"])
	_assert_shop("market")


func test_gas_station_plan() -> void:
	_assert_plan("gas_station", "P", ["Loja", "Depósito"], ["counter", "drink_fridge", "coffee_machine", "shelf"],
		["frentista"], ["cliente"])
	_assert_shop("gas_station")


func test_farm_store_plan() -> void:
	_assert_plan("farm_store", "P", ["Loja", "Depósito"], ["counter", "feed_sacks", "barrel", "tool_rack", "scale"],
		["balconista"], ["cliente"])
	_assert_shop("farm_store")


func test_shops_all_look_different() -> void:
	var seen := {}
	for type in ["armory", "pharmacy", "agent_store", "market", "gas_station", "farm_store"]:
		var kinds := _kinds(InteriorLayout.new(1, type)).keys()
		kinds.sort()
		seen[str(kinds)] = type
	assert_eq(seen.size(), 6, "cada loja com seu conjunto de móveis")
