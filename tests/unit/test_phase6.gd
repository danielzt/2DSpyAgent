extends "res://tests/base_test.gd"
## Fase 6: casinhas do bairro residencial, casa do agente, serviços de casa, uniformes e
## interiores cheios (hospital, delegacia, casas).

const CityLayout := preload("res://scripts/world/city_layout.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const Services := preload("res://scripts/interior/services.gd")
const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const WorldClockScript := preload("res://scripts/autoload/world_clock.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const FurnitureArt := preload("res://scripts/art/furniture_art.gd")
const MapIcons := preload("res://scripts/art/map_icons.gd")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")

var city
var layout


## Quem usa o serviço, sem cena.
class Actor:
	extends RefCounted
	var health := 4.0
	var profile: RefCounted
	var inventory: RefCounted
	func max_health() -> float:
		return 10.0


func before_each() -> void:
	layout = WorldLayout.new()
	city = layout.city


# --- casinhas do bairro residencial ---

func _houses() -> Array:
	var list: Array = []
	for b in city.buildings:
		if b.get("forced", "") == "house":
			list.append(b)
	return list


func test_residential_lots_have_many_small_houses() -> void:
	var houses := _houses()
	assert_gt(float(houses.size()), 30.0, "o bairro residencial precisa de várias casas")
	for b in houses:
		assert_eq(b.district, "residential")
		assert_true(b.type == "house" or b.type == "agent_home", "tipo %s" % b.type)
		var rect: Rect2 = b.rect
		assert_true(rect.size.x >= CityLayout.HOUSE_WIDTH.x - 4.0 and rect.size.x <= CityLayout.HOUSE_WIDTH.y + 4.0)


func test_houses_never_overlap_and_stay_inside_their_lot() -> void:
	var houses := _houses()
	for i in houses.size():
		var a: Rect2 = houses[i].rect
		var inside := false
		for lot in city.lots:
			if lot.grow(0.5).encloses(a):
				inside = true
		assert_true(inside, "casa %d fora do lote" % houses[i].id)
		for j in range(i + 1, houses.size()):
			assert_false(a.intersects(houses[j].rect), "casas %d e %d se sobrepõem" % [houses[i].id, houses[j].id])


func test_every_house_door_has_room_for_the_player_to_stand() -> void:
	for b in _houses():
		var spawn: Vector2 = b.exit_spawn
		var probe := Rect2(spawn - Vector2(14, 14), Vector2(28, 28))
		for other in city.buildings:
			assert_false((other.rect as Rect2).intersects(probe), "casa %d: porta tapada por %d" % [b.id, other.id])
		for t in city.trees:
			assert_false(probe.grow(10.0).has_point(t), "árvore na porta da casa %d" % b.id)


func test_house_lots_have_an_open_side_to_reach_the_alley() -> void:
	# cada lote de casas deixa o lado do beco livre: nenhuma casa chega a menos de HOUSE_OPEN_SIDE de uma ponta
	for lot in city.lots:
		var inside: Array = []
		for b in _houses():
			if lot.grow(0.5).encloses(b.rect):
				inside.append(b)
		if inside.is_empty():
			continue
		var left := INF
		var right := INF
		for b in inside:
			left = minf(left, (b.rect as Rect2).position.x - lot.position.x)
			right = minf(right, lot.end.x - (b.rect as Rect2).end.x)
		assert_true(maxf(left, right) >= CityLayout.HOUSE_OPEN_SIDE - 4.0, "lote sem passagem para o beco")


func test_houses_are_deterministic_by_seed() -> void:
	var other := CityLayout.new(2024)
	assert_eq(other.buildings.size(), city.buildings.size())
	for i in other.buildings.size():
		assert_eq(other.buildings[i].rect, city.buildings[i].rect)
		assert_eq(other.buildings[i].type, city.buildings[i].type)


# --- casa do agente ---

func test_there_is_exactly_one_agent_home_in_the_residential_district() -> void:
	for seed_value in [2024, 7, 99, 12345]:
		var c := CityLayout.new(seed_value)
		var homes := []
		for b in c.buildings:
			if b.type == "agent_home":
				homes.append(b)
		assert_eq(homes.size(), 1, "seed %d" % seed_value)
		assert_eq(homes[0].district, "residential", "seed %d" % seed_value)
		assert_eq(homes[0].name, "Casa do agente")


func test_agent_home_is_a_home_near_the_hq() -> void:
	var home: Dictionary = layout.home()
	assert_false(home.is_empty())
	assert_true(BuildingDefs.is_home(home.type))
	assert_true(BuildingDefs.always_open(home.type))
	var hq_center := Vector2.ZERO
	for b in city.buildings:
		if b.type == "hq":
			hq_center = (b.rect as Rect2).get_center()
	var home_d := (home.rect as Rect2).get_center().distance_to(hq_center)
	for b in city.buildings:
		if b.type == "house" and b.district == "residential":
			assert_true((b.rect as Rect2).get_center().distance_to(hq_center) >= home_d - 0.01, "havia uma casa mais perto do QG")


func test_agent_home_has_a_map_icon_and_no_sign() -> void:
	assert_eq(MapIcons.glyph_of("agent_home"), "myhome")
	assert_true(MapIcons.GLYPHS.has("myhome"))
	assert_ne(MapIcons.label_of("myhome"), "")
	assert_eq(BuildingStyle.for_building(layout.home()).sign, "")


func test_a_new_profile_knows_and_marks_the_agent_home() -> void:
	GameState.reset_players()
	var profile: RefCounted = GameState.profile_for(1)
	var home: Dictionary = GameState.world_layout().home()
	assert_true(profile.known_buildings.has(home.id))
	assert_true(profile.is_explored(home.exit_spawn))
	assert_eq(profile.waypoints.size(), 1)
	assert_eq(profile.waypoints[0].name, "Casa")
	assert_eq(profile.waypoints[0].pos, home.exit_spawn)
	assert_eq(profile.active_waypoint, 0)


# --- interior da casa do agente ---

func test_agent_home_interior_is_complete_and_has_no_strangers() -> void:
	for id in [0, 5, 31, 77]:
		for facade in [150.0, 240.0, 320.0]:
			var inner := InteriorLayout.new(id, "agent_home", facade)
			assert_eq(inner.template, "agent_home")
			assert_ne(inner.size_class, "P", "a casa do agente não é pequena")
			assert_eq(inner.unreachable(), [], "casa %d fachada %d" % [id, facade])
			assert_eq(inner.npc_slots.size(), 0, "sem estranhos na casa do agente")
			var kinds := {}
			for item in inner.items:
				kinds[item.kind] = true
			for needed in ["double_bed", "chest", "stove", "fridge", "sofa", "wall_tv", "bathtub", "toilet", "monitor", "wardrobe"]:
				assert_true(kinds.has(needed), "casa sem %s" % needed)
			var zone_ids := []
			for z in inner.zones:
				zone_ids.append(z.id)
			assert_true(zone_ids.has("rest") and zone_ids.has("stash"), "dormir e baú")
			var room_names := []
			for room in inner.rooms:
				room_names.append(room.name)
			for room_name in ["Sala", "Escritório", "Quarto", "Cozinha", "Banheiro"]:
				assert_true(room_names.has(room_name), room_name)


func test_agent_home_interior_is_fuller_than_the_old_home() -> void:
	var home := InteriorLayout.new(3, "agent_home")
	var plain := InteriorLayout.new(3, "house")
	assert_gt(float(home.items.size()), 30.0)
	assert_gt(float(plain.items.size()), 18.0, "a casa comum também ficou mais cheia")


# --- serviços da casa ---

func _actor() -> Actor:
	var actor := Actor.new()
	actor.profile = ProfileScript.new(1)
	actor.inventory = InventoryScript.starter_kit()
	return actor


func test_resting_at_home_is_free_heals_and_skips_to_the_morning() -> void:
	var actor := _actor()
	var clock = WorldClockScript.new()
	clock.set_hour(23.0)
	var money: int = actor.profile.money
	var result: Dictionary = Services.use("rest", actor, {"clock": clock})
	assert_eq(result.result, "ok")
	assert_eq(actor.health, actor.max_health())
	assert_eq(actor.profile.money, money, "de graça")
	assert_almost_eq(clock.hour(), Services.WAKE_HOUR, 0.01)
	assert_eq(clock.day(), 1)
	clock.free()


func test_the_chest_restocks_medkits_once_a_day() -> void:
	var actor := _actor()
	var clock = WorldClockScript.new()
	actor.inventory.consume("medkit")
	actor.inventory.consume("medkit")
	assert_eq(actor.inventory.count("medkit"), 1)
	var first: Dictionary = Services.use("stash", actor, {"clock": clock})
	assert_eq(first.result, "ok")
	assert_eq(actor.inventory.count("medkit"), Services.STASH_KITS)
	actor.inventory.consume("medkit")
	var second: Dictionary = Services.use("stash", actor, {"clock": clock})
	assert_eq(second.result, "no_need", "só uma vez por dia")
	assert_eq(actor.inventory.count("medkit"), Services.STASH_KITS - 1)
	clock.advance_hours(24.0)
	assert_eq(Services.use("stash", actor, {"clock": clock}).result, "ok", "no dia seguinte repõe")
	clock.free()


func test_home_services_are_listed_for_the_agent_home() -> void:
	assert_eq(Services.for_type("agent_home"), ["rest", "stash"])
	assert_true(Services.exists("rest") and Services.exists("stash"))
	assert_eq(Services.cost("rest"), 0)


func test_pressing_interact_in_the_bedroom_zone_rests() -> void:
	var inner := InteriorLayout.new(4, "agent_home")
	GameState.set_inside(4, Vector2(500, 500), "", "agent_home", "Casa do agente", 240.0)
	var scene := INTERIOR_SCENE.instantiate()
	tree.root.add_child(scene)
	await wait_physics_frames(3)
	var player = tree.get_nodes_in_group("players")[0]
	WorldClock.set_hour(22.0)
	player.health = 3.0
	var zone: Dictionary = scene.layout.zone("rest")
	player.global_position = (zone.rect as Rect2).get_center()
	await wait_physics_frames(3)
	assert_true(player.current_prompt().contains("dormir"), player.current_prompt())
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(player.health, player.max_health())
	assert_almost_eq(WorldClock.hour(), Services.WAKE_HOUR, 0.1)
	assert_eq(inner.template, "agent_home")
	scene.queue_free()
	GameState.set_outside()
	await wait_frames(2)


# --- uniformes ---

func test_hospital_staff_wear_white_and_patients_gowns() -> void:
	var base := CharacterSprites.civilian_look(5)
	for role in ["médica", "enfermeiro", "farmacêutico", "técnico de raio-X", "auxiliar de enfermagem"]:
		var look := CharacterSprites.dressed(base, role)
		assert_eq(look.shirt, "white", role)
		assert_eq(look.pants, "white", role)
	assert_eq(CharacterSprites.dressed(base, "paciente").shirt, "ice")


func test_police_cooks_and_prisoners_have_their_own_clothes() -> void:
	var base := CharacterSprites.civilian_look(9)
	assert_eq(CharacterSprites.dressed(base, "policial").shirt, "blue")
	assert_eq(CharacterSprites.dressed(base, "delegado").cap, "navy")
	assert_eq(CharacterSprites.dressed(base, "preso").shirt, "orange")
	assert_eq(CharacterSprites.dressed(base, "chef").cap, "white")
	assert_eq(CharacterSprites.dressed(base, "mecânico").pants, "blue")


func test_unknown_roles_keep_the_everyday_clothes() -> void:
	var base := CharacterSprites.civilian_look(3)
	assert_eq(CharacterSprites.dressed(base, "turista"), base)
	assert_eq(CharacterSprites.dressed(base, ""), base)
	assert_false(CharacterSprites.has_uniform("turista"))
	assert_true(CharacterSprites.has_uniform("médica"))


func test_look_for_applies_the_uniform_but_never_to_criminals() -> void:
	assert_eq(CharacterSprites.look_for("innocent", 4, "policial").shirt, "blue")
	assert_ne(CharacterSprites.look_for("criminal", 4, "policial").shirt, "blue")


func test_uniform_colors_are_palette_names() -> void:
	var palette := preload("res://scripts/art/palette.gd")
	for entry in CharacterSprites.UNIFORMS:
		for key in entry[1]:
			var value: String = entry[1][key]
			assert_true(value == "" or palette.COLORS.has(value), "%s: %s" % [key, value])


func test_hospital_staff_all_white_by_building() -> void:
	for role in BuildingDefs.staff_of("hospital") + ["atendente"]:
		assert_eq(CharacterSprites.look_for("innocent", 5, role, "hospital", true).shirt, "white", role)
	assert_eq(CharacterSprites.look_for("innocent", 5, "médica", "hospital", true).detail, "coat")
	assert_eq(CharacterSprites.look_for("innocent", 5, "enfermeiro", "hospital", true).hat, "nurse_cap")


func test_police_staff_all_blue_with_kepi() -> void:
	for role in BuildingDefs.staff_of("police") + ["atendente"]:
		if role == "perito" or role == "detetive":
			continue
		var look := CharacterSprites.look_for("innocent", 8, role, "police", true)
		assert_eq(look.shirt, "blue", role)
		assert_eq(look.hat, "kepi", role)
	assert_eq(CharacterSprites.look_for("innocent", 8, "perito", "police", true).detail, "coat")
	assert_eq(CharacterSprites.look_for("innocent", 8, "preso", "police", false).shirt, "orange")
	assert_eq(CharacterSprites.look_for("innocent", 8, "paciente", "hospital", false).shirt, "ice")


func test_customers_keep_their_clothes() -> void:
	var base := CharacterSprites.civilian_look(7)
	var look := CharacterSprites.look_for("innocent", 7, "frequentador", "bar", false)
	for key in ["shirt", "shirt2", "pants", "cap", "hat", "detail"]:
		assert_eq(look[key], base[key], key)
	assert_eq(CharacterSprites.look_for("criminal", 7, "bartender", "bar", true), CharacterSprites.criminal_look(7))


func test_every_building_type_has_a_staff_uniform() -> void:
	var palette := preload("res://scripts/art/palette.gd")
	for type in BuildingDefs.ORDER:
		if type in ["house", "apartment", "agent_home"]:
			continue
		assert_true(CharacterSprites.BUILDING_UNIFORMS.has(type), type)
		var entry: Dictionary = CharacterSprites.BUILDING_UNIFORMS[type]
		assert_false((entry.staff as Dictionary).is_empty(), type)
		var all: Array = [entry.staff]
		for role in entry.get("roles", {}):
			all.append(entry.roles[role])
		for overrides in all:
			for key in overrides:
				if key in ["shirt", "shirt2", "pants", "cap", "detail_color"]:
					var value: String = overrides[key]
					assert_true(value == "" or palette.COLORS.has(value), "%s %s: %s" % [type, key, value])
	assert_eq(CharacterSprites.look_for("innocent", 3, "morador", "house", false).shirt, CharacterSprites.civilian_look(3).shirt)


func test_hat_and_detail_change_the_sprite() -> void:
	var base := CharacterSprites.civilian_look(11)
	base.hair_style = "short"
	for hat in ["kepi", "nurse_cap", "chef_hat", "helmet", "straw"]:
		var look := base.duplicate()
		look.hat = hat
		look.cap = "navy"
		for dir in ["down", "up", "right"]:
			assert_ne(CharacterSprites.rows_for(look, dir, 0), CharacterSprites.rows_for(base, dir, 0), "%s %s" % [hat, dir])
	for detail in ["coat", "apron", "vest", "tie", "badge", "reflective"]:
		var look := base.duplicate()
		look.detail = detail
		look.detail_color = "amber"
		assert_ne(CharacterSprites.rows_for(look, "down", 0), CharacterSprites.rows_for(base, "down", 0), detail)
		assert_true(CharacterSprites.build(look, "down", 0).only_palette_colors(), detail)
	assert_ne(CharacterSprites.look_key(base), CharacterSprites.look_key(CharacterSprites.look_for("innocent", 11, "policial", "police", true)))


func test_interior_npcs_get_their_uniform() -> void:
	GameState.set_inside(9, Vector2(500, 500), "", "hospital", "Hospital Teste", 240.0)
	var scene := INTERIOR_SCENE.instantiate()
	tree.root.add_child(scene)
	await wait_physics_frames(3)
	var whites := 0
	for npc in tree.get_nodes_in_group("interior_npcs"):
		if npc.uniform_staff:
			assert_eq(npc.look().shirt, "white", "equipe de branco: %s" % npc.get_meta("role"))
			whites += 1
		elif npc.get_meta("role") == "paciente":
			assert_eq(npc.look().shirt, "ice", "paciente de camisola")
	assert_gt(float(whites), 3.0, "equipe de branco")
	scene.queue_free()
	GameState.set_outside()
	await wait_frames(2)


# --- interiores cheios ---

func test_every_interior_has_the_minimum_amount_of_people() -> void:
	for type in BuildingDefs.ORDER:
		if InteriorLayout.is_planned(type):
			continue   # nas plantas, a gente é definida nelas (ver test_plans.gd)
		for id in [1, 8, 15]:
			var inner := InteriorLayout.new(id, type, 240.0)
			assert_true(inner.npc_slots.size() >= InteriorLayout.MIN_PEOPLE[inner.size_class],
					"%s %d tem %d pessoas" % [type, id, inner.npc_slots.size()])


func test_people_never_stand_inside_furniture_or_walls() -> void:
	for type in ["hospital", "police", "house", "bar", "hotel", "office"]:
		for id in range(10):
			var inner := InteriorLayout.new(id, type)
			for slot in inner.npc_slots:
				if slot.get("act", "post") in ["sit", "lie"]:
					continue   # sentado ou deitado fica sobre o próprio móvel
				var probe := Rect2(slot.position - Vector2(10, 10), Vector2(20, 20))
				for solid in inner.solids():
					assert_false(solid.intersects(probe), "%s %d: %s dentro de um sólido" % [type, id, slot.role])


func test_hospital_is_a_complete_hospital() -> void:
	for id in range(6):
		var inner := InteriorLayout.new(id, "hospital", 320.0)
		var rooms := []
		for room in inner.rooms:
			rooms.append(room.name)
		for needed in ["Enfermaria", "UTI", "Consultório", "Farmácia", "Recepção"]:
			assert_true(rooms.has(needed), "hospital %d sem %s" % [id, needed])
		var kinds := {}
		for item in inner.items:
			kinds[item.kind] = true
		for needed in ["hospital_bed", "monitor", "desk", "computer", "cart", "counter", "bottle_shelf"]:
			assert_true(kinds.has(needed), "hospital %d sem %s" % [id, needed])
		var roles := {}
		for slot in inner.npc_slots:
			roles[slot.role] = true
		assert_true(roles.has("paciente"), "sem pacientes")
		assert_true(roles.size() >= 4, "equipe variada: %s" % str(roles.keys()))
		assert_eq(inner.unreachable(), [], "hospital %d" % id)
		assert_eq(inner.size_class, "G", "hospital é grande (planta própria)")


func test_police_station_is_a_complete_police_station() -> void:
	for id in range(6):
		var inner := InteriorLayout.new(id, "police", 320.0)
		var rooms := []
		for room in inner.rooms:
			rooms.append(room.name)
		for needed in ["Celas", "Sala dos agentes", "Delegado", "Interrogatório", "Recepção"]:
			assert_true(rooms.has(needed), "delegacia %d sem %s" % [id, needed])
		var kinds := {}
		for item in inner.items:
			kinds[item.kind] = true
		for needed in ["cell_bars", "bunk", "toilet", "desk", "computer", "file_cabinet", "bookshelf", "locker", "bench"]:
			assert_true(kinds.has(needed), "delegacia %d sem %s" % [id, needed])
		var roles := {}
		for slot in inner.npc_slots:
			roles[slot.role] = true
		assert_true(roles.has("policial") and roles.has("preso"), "policiais e presos")
		assert_true(roles.has("delegado"), "delegado")
		assert_eq(inner.unreachable(), [], "delegacia %d" % id)


func test_police_staff_wear_blue_in_the_scene() -> void:
	GameState.set_inside(6, Vector2(500, 500), "", "police", "Delegacia Teste", 240.0)
	var scene := INTERIOR_SCENE.instantiate()
	tree.root.add_child(scene)
	await wait_physics_frames(3)
	var blue := 0
	for npc in tree.get_nodes_in_group("interior_npcs"):
		if npc.uniform_staff and npc.get_meta("role") != "detetive":
			assert_eq(npc.look().shirt, "blue", npc.get_meta("role"))
			blue += 1
		if npc.get_meta("role") == "preso":
			assert_eq(npc.look().shirt, "orange")
	assert_gt(float(blue), 3.0)
	scene.queue_free()
	GameState.set_outside()
	await wait_frames(2)


func test_ordinary_home_has_all_four_rooms() -> void:
	for id in range(8):
		var inner := InteriorLayout.new(id, "house")
		var rooms := []
		for room in inner.rooms:
			rooms.append(room.name)
		for needed in ["Sala", "Quarto do casal", "Banheiro", "Cozinha"]:
			assert_true(rooms.has(needed), "casa %d sem %s" % [id, needed])
		assert_eq(inner.unreachable(), [], "casa %d" % id)


func test_decoration_never_blocks_a_door_or_a_room() -> void:
	for type in BuildingDefs.ORDER + ["agent_home"]:
		for id in range(6):
			for facade in [150.0, 240.0, 320.0]:
				assert_eq(InteriorLayout.new(id, type, facade).unreachable(), [], "%s %d (%d)" % [type, id, facade])


func test_new_furniture_kinds_have_art() -> void:
	for kind in ["computer", "monitor", "file_cabinet", "cart", "xray", "toilet", "bathtub", "bookshelf", "vending", "sink", "curtain", "trash", "coat_rack"]:
		assert_true(FurnitureArt.has_kind(kind), kind)
		var canvas: RefCounted = FurnitureArt.canvas(kind, 24, 20)
		assert_true(canvas.only_palette_colors(), kind)
		assert_gt(canvas.opaque_count(), 30.0, kind)


func test_interiors_are_deterministic_with_decoration() -> void:
	for type in ["hospital", "police", "agent_home", "bar"]:
		var a := InteriorLayout.new(12, type, 240.0)
		var b := InteriorLayout.new(12, type, 240.0)
		assert_eq(a.items.size(), b.items.size())
		for i in a.items.size():
			assert_eq(a.items[i].rect, b.items[i].rect)
		assert_eq(a.npc_slots.size(), b.npc_slots.size())
