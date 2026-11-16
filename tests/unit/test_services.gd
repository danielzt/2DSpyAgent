extends "res://tests/base_test.gd"
## Serviços dos interiores: custo, efeito, falta de dinheiro; e que cada um só dispara
## pela ação de input com o jogador dentro da zona.

const Services := preload("res://scripts/interior/services.gd")
const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const WorldClockScript := preload("res://scripts/autoload/world_clock.gd")
const GameStateScript := preload("res://scripts/autoload/game_state.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const ItemDefs := preload("res://scripts/items/item_defs.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")


## Quem usa o serviço, sem cena: vida, vida máxima e ficha.
class Actor:
	extends RefCounted
	var health := 4.0
	var profile: RefCounted
	func max_health() -> float:
		return 10.0


var actor: Actor
var clock
var state
var world := {}
var nodes: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	actor = Actor.new()
	actor.profile = ProfileScript.new(1)
	clock = WorldClockScript.new()
	state = GameStateScript.new()
	world = {"clock": clock, "state": state, "score": Score,
		"tip_provider": func() -> Dictionary: return {"crime": "bar_brawl", "crime_name": "Briga de bar", "place": "Bar Saideira",
			"building_id": 3, "position": Vector2(900, 900), "region": "Cidade"}}
	GameState.set_outside()


func after_each() -> void:
	Input.action_release("p1_interact")
	clock.free()
	state.free()
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	GameState.set_outside()
	await wait_frames(2)


func _use(id: String) -> Dictionary:
	return Services.use(id, actor, world)


# --- tabela ---

func test_every_service_has_a_verb_and_a_building() -> void:
	var offered := {}
	for type in Services.BY_TYPE:
		assert_true(BuildingDefs.exists(type), type)
		for id in Services.for_type(type):
			assert_true(Services.exists(id), id)
			offered[id] = true
	for id in Services.DEFS:
		assert_ne(Services.verb(id), "", id)
		assert_true(offered.has(id), "serviço sem prédio: %s" % id)
	assert_eq(Services.for_type("house"), [])
	assert_eq(Services.verb("sleep"), "dormir ($40)")
	assert_eq(Services.verb("deliver"), "entregar os presos")
	assert_true(Services.verb("heal").contains("$5"))
	assert_eq(Services.verb("nada"), "")
	assert_eq(_use("nada").result, "unknown")


func test_no_service_building_is_left_without_interaction() -> void:
	# nenhuma interação pode ser enfeite: todo tipo com cota tem serviço ou loja
	for type in BuildingDefs.ORDER:
		if BuildingDefs.min_count(type) == 0:
			continue
		var has_service: bool = not Services.for_type(type).is_empty() or BuildingDefs.shop_of(type) != ""
		assert_true(has_service or type == "newspaper", "%s sem interação" % type)


# --- hotel, restaurante, lanchonete, hospital ---

func test_sleep_heals_charges_and_moves_the_clock_to_morning() -> void:
	clock.set_hour(22.0)
	var r := _use("sleep")
	assert_eq(r.result, "ok")
	assert_almost_eq(actor.health, 10.0)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 40)
	assert_almost_eq(clock.hour(), 7.0, 0.01)
	assert_eq(clock.day(), 1, "dormir à noite acorda no dia seguinte")
	assert_true(r.message.contains("07:00"))


func test_sleep_without_money_does_nothing() -> void:
	actor.profile.money = 10
	clock.set_hour(22.0)
	assert_eq(_use("sleep").result, "no_money")
	assert_almost_eq(actor.health, 4.0)
	assert_eq(actor.profile.money, 10)
	assert_almost_eq(clock.hour(), 22.0, 0.01)


func test_meal_and_snack_heal_different_amounts() -> void:
	assert_eq(_use("snack").result, "ok")
	assert_almost_eq(actor.health, 7.0)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 10)
	actor.health = 2.0
	assert_eq(_use("meal").result, "ok")
	assert_almost_eq(actor.health, 8.0)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 35)
	actor.health = 9.0
	_use("meal")
	assert_almost_eq(actor.health, 10.0, 0.01, "não passa da vida máxima")


func test_meal_with_full_health_is_not_charged() -> void:
	actor.health = 10.0
	assert_eq(_use("meal").result, "no_need")
	assert_eq(actor.profile.money, ProfileScript.START_MONEY)
	actor.health = 5.0
	actor.profile.money = 5
	assert_eq(_use("meal").result, "no_money")
	assert_almost_eq(actor.health, 5.0)


func test_hospital_charges_per_missing_point() -> void:
	actor.health = 3.5
	var r := _use("heal")
	assert_eq(r.result, "ok")
	assert_almost_eq(actor.health, 10.0)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 7 * Services.HEAL_COST_PER_POINT)
	assert_eq(_use("heal").result, "no_need")
	actor.health = 1.0
	actor.profile.money = 20
	assert_eq(_use("heal").result, "no_money")
	assert_almost_eq(actor.health, 1.0)


# --- delegacia e banco ---

func test_delivering_prisoners_pays_points_and_money() -> void:
	assert_eq(_use("deliver").result, "no_need")
	actor.profile.prisoners = 3
	var points := Score.points
	var r := _use("deliver")
	assert_eq(r.result, "ok")
	assert_eq(actor.profile.prisoners, 0)
	assert_eq(Score.points, points + 3 * Services.DELIVERY_POINTS)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY + 3 * Services.DELIVERY_MONEY)
	assert_eq(_use("deliver").result, "no_need", "cada preso só rende uma vez")


func test_bank_deposit_and_withdraw() -> void:
	assert_eq(_use("withdraw").result, "no_need")
	assert_eq(_use("deposit").result, "ok")
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 100)
	assert_eq(actor.profile.bank, 100)
	_use("deposit")
	assert_eq(actor.profile.bank, 200)
	assert_eq(actor.profile.money, 0)
	assert_eq(_use("deposit").result, "no_need")
	assert_eq(_use("withdraw").result, "ok")
	assert_eq(actor.profile.money, 100)
	assert_eq(actor.profile.bank, 100)


func test_deposit_takes_what_is_left_when_below_the_step() -> void:
	actor.profile.money = 30
	_use("deposit")
	assert_eq(actor.profile.bank, 30)
	assert_eq(actor.profile.money, 0)


func test_bank_money_survives_defeat() -> void:
	_use("deposit")
	var lost: int = actor.profile.lose_money_on_defeat()
	assert_eq(lost, 50, "perde metade do que carrega")
	assert_eq(actor.profile.money, 50)
	assert_eq(actor.profile.bank, 100, "o dinheiro do banco fica")


# --- bar, boate e QG ---

func test_rumor_buys_a_tip() -> void:
	var r := _use("rumor")
	assert_eq(r.result, "ok")
	assert_eq(state.tip.place, "Bar Saideira")
	assert_true(r.message.contains("Briga de bar: Bar Saideira"))
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 15)
	# com uma pista em aberto, não cobra de novo
	assert_eq(_use("rumor").result, "already")
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 15)


func test_rumor_without_any_crime_to_tell_is_free() -> void:
	world["tip_provider"] = func() -> Dictionary: return {}
	assert_eq(_use("rumor").result, "no_need")
	assert_eq(actor.profile.money, ProfileScript.START_MONEY)
	assert_eq(state.tip, {})


func test_informant_reveals_criminals_for_a_while() -> void:
	assert_eq(_use("informant").result, "ok")
	assert_almost_eq(state.reveal_seconds, Services.INFORMANT_SECONDS)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 50)
	actor.profile.money = 0
	state.reveal_seconds = 0.0
	assert_eq(_use("informant").result, "no_money")
	assert_almost_eq(state.reveal_seconds, 0.0)


func test_briefing_reports_and_gives_one_mission_per_day() -> void:
	actor.profile.prisoners = 2
	var r := _use("briefing")
	assert_eq(r.result, "ok")
	assert_true(r.message.contains("2 preso(s)"))
	assert_true(r.message.contains("Missão: Briga de bar: Bar Saideira"))
	assert_eq(state.tip.building_id, 3)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY, "o briefing é de graça")
	assert_true(_use("briefing").message.contains("Missão em aberto"))
	state.tip = {}
	assert_false(_use("briefing").message.contains("Missão"), "uma missão por dia")
	clock.advance_hours(24.0)
	assert_true(_use("briefing").message.contains("Missão:"))


func test_tip_text() -> void:
	assert_eq(Services.tip_text({"crime_name": "Arrombamento", "place": "Casa 12"}), "Arrombamento: Casa 12")


# --- oficina, cinema e academia ---

func test_paint_cycles_the_agency_car_colors() -> void:
	assert_eq(actor.profile.car_paint, CarSprites.AGENT_PAINTS[0])
	var seen := {}
	for i in CarSprites.AGENT_PAINTS.size():
		assert_eq(_use("paint").result, "ok")
		seen[actor.profile.car_paint] = true
		assert_ne(CarSprites.paint_name(actor.profile.car_paint), "")
	assert_eq(seen.size(), CarSprites.AGENT_PAINTS.size())
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 30 * CarSprites.AGENT_PAINTS.size())


func test_agent_car_uses_the_paint_and_ignores_other_tones() -> void:
	assert_eq(CarSprites.tone_of("agent", "red"), "black", "cor fora da lista da oficina não vale")
	for paint in CarSprites.AGENT_PAINTS:
		assert_eq(CarSprites.tone_of("agent", paint), paint)
		assert_true(CarSprites.frame("agent", paint, 0).only_palette_colors())
	assert_ne(CarSprites.frame("agent", "wine", 0).image.get_data(), CarSprites.frame("agent", "black", 0).image.get_data())


func test_movie_advances_two_hours_and_boosts_xp() -> void:
	clock.set_hour(14.0)
	var base: float = actor.profile.xp_multiplier()
	assert_eq(_use("movie").result, "ok")
	assert_almost_eq(clock.hour(), 16.0, 0.01)
	assert_almost_eq(actor.profile.xp_multiplier(), base * ProfileScript.XP_BOOST, 0.001)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 20)
	actor.profile.tick(Services.MOVIE_XP_BOOST_SECONDS + 1.0)
	assert_almost_eq(actor.profile.xp_multiplier(), base, 0.001, "o bônus acaba")


func test_training_gives_xp_once_per_day() -> void:
	assert_eq(_use("train").result, "ok")
	assert_eq(actor.profile.xp, 20)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 30)
	assert_eq(_use("train").result, "already")
	assert_eq(actor.profile.xp, 20)
	assert_eq(actor.profile.money, ProfileScript.START_MONEY - 30)
	clock.advance_hours(24.0)
	assert_eq(_use("train").result, "ok")
	assert_eq(actor.profile.xp, 40)


# --- comida para levar (mercado e posto) ---

func test_snack_item_heals_and_has_its_own_limit() -> void:
	assert_true(ItemDefs.exists("snack"))
	assert_almost_eq(ItemDefs.get_def("snack").heal, 3.0)
	assert_eq(ItemDefs.max_count("snack"), 5)
	assert_eq(ItemDefs.max_count("medkit"), 0)
	var inv = InventoryScript.new()
	assert_true(inv.add("snack", 5))
	assert_false(inv.add("snack"), "leva no máximo 5 lanches")
	assert_true(inv.add("medkit", 9))


func test_market_and_gas_station_sell_food() -> void:
	for shop in ["market", "gas_station"]:
		assert_true(ShopDefs.exists(shop))
		assert_true(ShopDefs.stock(shop).has("snack"))
		assert_eq(BuildingDefs.shop_of(shop), shop)
	assert_eq(ShopDefs.price_in("market", "snack"), ItemDefs.price("snack"))
	assert_eq(ShopDefs.price_in("gas_station", "snack"), roundi(ItemDefs.price("snack") * 1.5), "o posto cobra 50% a mais")
	assert_eq(ShopDefs.price_in("armory", "pistol"), ItemDefs.price("pistol"), "as lojas antigas não mudaram de preço")
	var inv = InventoryScript.new()
	var profile = ProfileScript.new(1)
	assert_eq(ShopDefs.buy("gas_station", "snack", inv, profile), "ok")
	assert_eq(profile.money, ProfileScript.START_MONEY - 18)
	profile.money = 15
	assert_eq(ShopDefs.buy("gas_station", "snack", inv, profile), "no_money")
	assert_eq(ShopDefs.buy("market", "snack", inv, profile), "ok")


# --- pistas (puro) ---

func test_make_tip_points_to_a_compatible_building() -> void:
	var layout := WorldLayout.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 15:
		var tip := CrimeProfiles.make_tip(layout, rng, Vector2(3360, 3360))
		assert_false(tip.is_empty())
		var b: Dictionary = layout.building_by_id(tip.building_id)
		var type := CrimeProfiles.find_type(tip.crime)
		assert_true(CrimeProfiles.near_of(type).has(b.type), "%s em %s" % [tip.crime, b.type])
		assert_eq(tip.place, b.name)
		assert_eq(tip.position, b.exit_spawn)
		assert_eq(tip.crime_name, type.name)


# --- cena: só pela ação de input, com o jogador na zona (V6) ---

func _interior(type: String, id := 4) -> Node:
	GameState.set_inside(id, Vector2(3000, 3000), BuildingDefs.shop_of(type), type, "Lugar de Teste")
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	nodes.append(interior)
	await wait_physics_frames(3)
	return interior


func _player() -> Node:
	return tree.get_nodes_in_group("players")[0]


func test_interior_builds_zones_furniture_and_npcs_of_its_type() -> void:
	var interior := await _interior("hotel")
	var layout = interior.layout
	assert_eq(layout.template, "hotel")
	assert_eq(tree.get_nodes_in_group("service_zones").size(), layout.zones.size())
	assert_eq(tree.get_nodes_in_group("furniture").size(), layout.furniture.size())
	assert_eq(tree.get_nodes_in_group("interior_npcs").size(), layout.npc_slots.size())
	assert_gt(tree.get_nodes_in_group("floor_items").size(), 0.0)
	assert_eq(_player().place_name, "Lugar de Teste")
	assert_eq(_player().global_position, layout.spawn_point())


func test_service_needs_the_interact_action_inside_the_zone() -> void:
	var interior := await _interior("hotel")
	var p := _player()
	p.health = 3.0
	var money: int = p.profile.money
	# longe da zona, apertar E não faz nada
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	await wait_physics_frames(2)
	assert_almost_eq(p.health, 3.0)
	assert_eq(p.profile.money, money)
	# dentro da zona aparece a instrução, mas nada acontece sem apertar
	p.global_position = (interior.layout.zone("sleep").rect as Rect2).get_center()
	await wait_physics_frames(4)
	assert_true(p.current_prompt().contains("dormir ($40)"), p.current_prompt())
	assert_almost_eq(p.health, 3.0)
	assert_eq(p.profile.money, money)
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_almost_eq(p.health, p.max_health())
	assert_eq(p.profile.money, money - 40)
	assert_true(p.hud.toast_visible())
	assert_true(p.hud.toast_text().contains("dormiu"))


func test_every_service_zone_works_in_its_scene() -> void:
	for type in Services.BY_TYPE:
		var interior := await _interior(type)
		var p := _player()
		p.health = 2.0
		p.profile.prisoners = 1
		p.profile.bank = 100
		for id in Services.for_type(type):
			var result: Dictionary = interior.use_service(id, p)
			assert_true(result.result == "ok" or result.result == "no_need", "%s/%s: %s" % [type, id, result.result])
			assert_ne(result.message, "", "%s/%s sem mensagem" % [type, id])
		interior.queue_free()
		await wait_frames(2)
		GameState.reset_players()


func test_interior_staff_say_where_they_work() -> void:
	await _interior("bar")
	var staff := 0
	for npc in tree.get_nodes_in_group("interior_npcs"):
		assert_true(npc.stationary)
		assert_eq(npc.kind, "innocent")
		if npc.identity.get("work_name", "") != "":
			staff += 1
			assert_eq(npc.identity.work_name, "Lugar de Teste")
			assert_true(BuildingDefs.staff_of("bar").has(npc.identity.role))
			assert_true(npc.get_meta("role") == npc.identity.role)
	assert_gt(staff, 0.0)


func test_residents_say_where_they_live() -> void:
	var found := 0
	for id in [1, 2, 3, 5, 8, 9]:
		var interior := await _interior("house", id)
		for npc in tree.get_nodes_in_group("interior_npcs"):
			assert_eq(npc.identity.home_name, "Lugar de Teste")
			assert_true(preload("res://scripts/npc/npc_identity.gd").answer(npc.identity, "about").contains("Lugar de Teste"))
			found += 1
		interior.queue_free()
		await wait_frames(2)
	assert_gt(found, 0.0)


func test_interior_npcs_stay_in_place() -> void:
	await _interior("bar")
	var before := {}
	for npc in tree.get_nodes_in_group("interior_npcs"):
		if npc.activity != "patrol":   # quem faz ronda anda de propósito (ver test_npc)
			before[npc] = npc.global_position
	assert_gt(float(before.size()), 3.0)
	await wait_physics_frames(40)
	for npc in before:
		assert_almost_eq((npc.global_position as Vector2).distance_to(before[npc]), 0.0, 2.0)


func test_interior_size_follows_the_facade() -> void:
	GameState.set_inside(4, Vector2.ZERO, "", "restaurant", "Restaurante", 300.0)
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	nodes.append(interior)
	await wait_frames(2)
	assert_eq(interior.layout.size_class, "G")
	assert_eq(_player().get_node("Camera2D").limit_right, int(interior.layout.size.x))


func test_windows_show_the_sky_of_the_hour() -> void:
	var planned := await _interior("house")
	var windows := 0
	for item in planned.layout.items:
		if item.kind == "window":
			windows += 1
	assert_gt(float(windows), 0.0, "a planta da casa tem janelas")
	assert_eq(planned._window_skies.size(), windows, "cada janela da planta mostra o céu")
	planned.queue_free()
	await wait_frames(3)
	var interior := await _interior("office")
	assert_gt(interior.window_rects().size(), 0.0)
	for rect in interior.window_rects():
		for solid in interior.layout.solids():
			assert_false((solid as Rect2).intersects(rect), "janela atrás de móvel")
	var noon: Color = interior.sky_color(12.0)
	var midnight: Color = interior.sky_color(0.0)
	assert_gt(noon.get_luminance(), midnight.get_luminance() + 0.1)
	assert_gt(midnight.b, midnight.r, "à noite o céu é azulado")


func test_health_is_kept_between_scenes() -> void:
	await _interior("house")
	var p := _player()
	p.health = 3.0
	nodes[0].queue_free()
	await wait_frames(3)
	assert_almost_eq(GameState.profile_for(1).health, 3.0)
	await _interior("house")
	assert_almost_eq(_player().health, 3.0, 0.01, "entrar em um prédio não cura")
