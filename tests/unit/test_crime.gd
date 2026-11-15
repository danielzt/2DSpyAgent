extends "res://tests/base_test.gd"
## Crimes que dependem da região e o gerenciador de ocorrências.

const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const IncidentManagerScript := preload("res://scripts/crime/incident_manager.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var manager
var player
var layout
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	layout = WorldLayout.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.queue_free()
	manager = null
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	for n in tree.get_nodes_in_group("npcs"):
		n.queue_free()
	for b in tree.get_nodes_in_group("bullets"):
		b.queue_free()
	await wait_frames(2)


func _setup(player_pos: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = player_pos
	tree.root.add_child(player)
	manager = IncidentManagerScript.new()
	manager.layout = layout
	manager.rng.seed = 5
	tree.root.add_child(manager)
	await wait_physics_frames(2)


# --- perfis (puros) ---

func test_each_region_has_its_own_crime_types() -> void:
	var city_ids := []
	var country_ids := []
	for t in CrimeProfiles.types_for("Cidade"):
		city_ids.append(t.id)
	for t in CrimeProfiles.types_for("Campo"):
		country_ids.append(t.id)
	assert_gt(city_ids.size(), 1.0)
	assert_gt(country_ids.size(), 1.0)
	for id in city_ids:
		assert_false(country_ids.has(id), "tipo de crime repetido entre regiões: " + id)


func test_type_data_is_complete() -> void:
	for region in CrimeProfiles.PROFILES:
		assert_gt(CrimeProfiles.interval_for(region), 5.0)
		for t in CrimeProfiles.types_for(region):
			assert_ne(t.name, "")
			assert_true(t.weight >= 1 and t.criminals >= 1 and t.reward > 0)


func test_pick_only_returns_types_of_that_region() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for region in ["Cidade", "Campo"]:
		for i in 100:
			var t := CrimeProfiles.pick(region, rng)
			assert_eq(CrimeProfiles.region_of(t.id), region)


func test_pick_respects_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var counts := {}
	for i in 3000:
		var t := CrimeProfiles.pick("Cidade", rng)
		counts[t.id] = counts.get(t.id, 0) + 1
	assert_gt(counts["assault"], counts["gang_fight"], "assalto é mais comum que briga de gangues")
	assert_gt(counts["gang_fight"], 300.0)


func test_pick_unknown_region_is_empty() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(CrimeProfiles.pick("Lua", rng), {})
	assert_eq(CrimeProfiles.types_for("Lua"), [])
	assert_eq(CrimeProfiles.interval_for("Lua"), 60.0)
	assert_false(CrimeProfiles.has_region(""))


func test_country_crimes_are_rarer_than_city_crimes() -> void:
	assert_gt(CrimeProfiles.interval_for("Campo"), CrimeProfiles.interval_for("Cidade"))


func test_lookup_helpers() -> void:
	assert_eq(CrimeProfiles.find_type("cattle_theft").name, "Roubo de gado")
	assert_eq(CrimeProfiles.find_type("???"), {})
	assert_eq(CrimeProfiles.region_of("cattle_theft"), "Campo")
	assert_eq(CrimeProfiles.region_of("assault"), "Cidade")
	assert_eq(CrimeProfiles.region_of("???"), "")


func test_direction_text() -> void:
	var o := Vector2(100, 100)
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(0, -50)), "ao norte")
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(50, 0)), "ao leste")
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(0, 50)), "ao sul")
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(-50, 0)), "ao oeste")
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(50, -50)), "a nordeste")
	assert_eq(CrimeProfiles.direction_text(o, o + Vector2(-50, 50)), "a sudoeste")
	assert_eq(CrimeProfiles.direction_text(o, o), "aqui")


func test_alert_text_has_crime_distance_and_direction() -> void:
	var t := CrimeProfiles.find_type("assault")
	var text := CrimeProfiles.alert_text(t, Vector2(0, 0), Vector2(0, -1200))
	assert_true(text.contains("Assalto armado"))
	assert_true(text.contains("100 m"))
	assert_true(text.contains("ao norte"))


# --- gerenciador ---

func test_spawn_incident_creates_criminals_of_that_crime() -> void:
	await _setup(Vector2(560, 560))
	var type := CrimeProfiles.find_type("gang_fight")
	var inc: Dictionary = manager.spawn_incident("Cidade", Vector2(2000, 2000), type)
	assert_eq(inc.criminals.size(), 3)
	for c in inc.criminals:
		assert_eq(c.kind, "criminal")
		assert_eq(c.crime, "gang_fight")
	assert_eq(manager.active_count(), 1)


func test_city_and_country_incidents_differ() -> void:
	await _setup(Vector2(560, 560))
	var city_ids := {}
	var country_ids := {}
	for i in 30:
		city_ids[manager.spawn_incident("Cidade", Vector2(2000, 2000)).type.id] = true
		country_ids[manager.spawn_incident("Campo", Vector2(9000, 2000)).type.id] = true
		manager.incidents.clear()
	for id in city_ids:
		assert_eq(CrimeProfiles.region_of(id), "Cidade")
	for id in country_ids:
		assert_eq(CrimeProfiles.region_of(id), "Campo")


func test_spawn_incident_for_unknown_region_does_nothing() -> void:
	await _setup(Vector2(560, 560))
	assert_eq(manager.spawn_incident("Lua", Vector2.ZERO), {})
	assert_eq(manager.active_count(), 0)


func test_try_spawn_places_crime_in_the_players_region() -> void:
	await _setup(Vector2(560, 560))
	assert_true(manager.try_spawn())
	var inc: Dictionary = manager.incidents[0]
	assert_eq(inc.region, "Cidade")
	assert_eq(layout.region_at(inc.center), "Cidade")
	var d: float = inc.center.distance_to(player.global_position)
	# o crime fica em frente a um prédio compatível, que pode estar um pouco mais longe
	assert_true(d >= manager.MIN_DISTANCE - 1.0 and d <= manager.MAX_PLACE_DISTANCE + 1.0)
	assert_false(layout.is_blocked(inc.center, 30.0))


func test_try_spawn_in_the_country_uses_country_crimes() -> void:
	await _setup(Vector2(CityLayoutSize() + 1500.0, 1500.0))
	assert_true(manager.try_spawn())
	assert_eq(manager.incidents[0].region, "Campo")
	assert_eq(CrimeProfiles.region_of(manager.incidents[0].type.id), "Campo")


func CityLayoutSize() -> float:
	return WorldLayout.CityLayout.city_size()


func test_alert_is_shown_to_the_player() -> void:
	await _setup(Vector2(560, 560))
	manager.try_spawn()
	assert_true(player.hud.toast_visible())
	assert_true(player.hud.toast_text().contains("Crime em andamento"))
	assert_true(player.hud.toast_text().contains(manager.incidents[0].type.name))


func test_max_active_incidents() -> void:
	await _setup(Vector2(560, 560))
	for i in manager.MAX_ACTIVE:
		assert_true(manager.try_spawn())
	assert_false(manager.try_spawn())
	assert_eq(manager.active_count(), manager.MAX_ACTIVE)


func test_no_incident_without_players_or_outside_regions() -> void:
	manager = IncidentManagerScript.new()
	manager.layout = layout
	tree.root.add_child(manager)
	assert_false(manager.try_spawn(), "sem jogador")
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(-500, -500)
	tree.root.add_child(player)
	await wait_physics_frames(1)
	assert_false(manager.try_spawn(), "jogador fora das regiões")


func test_incident_is_resolved_when_all_criminals_are_dead_or_stunned() -> void:
	await _setup(Vector2(560, 560))
	var score_before: int = Score.points
	var money_before: int = player.profile.money
	var resolved := [0]
	manager.incident_resolved.connect(func(_i): resolved[0] += 1)
	var inc: Dictionary = manager.spawn_incident("Cidade", Vector2(3000, 3000), CrimeProfiles.find_type("trafficking"))
	for c in inc.criminals:
		c.set_physics_process(false)
	inc.criminals[0].take_damage(10, player)
	await wait_physics_frames(2)
	assert_eq(resolved[0], 0, "ainda falta um criminoso")
	inc.criminals[1].stun(3.0, player)
	await wait_physics_frames(2)
	assert_eq(resolved[0], 1)
	var reward: int = inc.type.reward
	# +50 por matar, +30 por atordoar, +reward pelo crime resolvido
	assert_eq(Score.points - score_before, Score.CRIMINAL_REWARD + Score.STUN_CRIMINAL_REWARD + reward)
	assert_gt(player.profile.money, money_before + int(reward * 0.5) - 1)
	assert_eq(manager.active_count(), 0)
	assert_true(player.hud.toast_text().contains("Crime resolvido"))


func test_resolution_is_paid_only_once() -> void:
	await _setup(Vector2(560, 560))
	var inc: Dictionary = manager.spawn_incident("Cidade", Vector2(3000, 3000), CrimeProfiles.find_type("assault"))
	inc.criminals[0].set_physics_process(false)
	inc.criminals[0].take_damage(10, null)
	await wait_physics_frames(5)
	var after_first: int = Score.points
	await wait_physics_frames(30)
	assert_eq(Score.points, after_first)


func test_unresolved_incident_stays_active() -> void:
	await _setup(Vector2(560, 560))
	var inc: Dictionary = manager.spawn_incident("Cidade", Vector2(3000, 3000), CrimeProfiles.find_type("assault"))
	inc.criminals[0].set_physics_process(false)
	await wait_physics_frames(30)
	assert_eq(manager.active_count(), 1)


func test_disabled_manager_never_spawns_on_its_own() -> void:
	await _setup(Vector2(560, 560))
	manager.enabled = false
	manager._timer = 0.0
	await wait_physics_frames(10)
	assert_eq(manager.active_count(), 0)


func test_timer_spawns_incident_automatically() -> void:
	await _setup(Vector2(560, 560))
	manager._timer = 0.01
	await wait_frames(5)
	assert_eq(manager.active_count(), 1)
	assert_gt(manager._timer, 5.0, "reinicia a espera")


func test_register_incident_score() -> void:
	var before: int = Score.points
	assert_eq(Score.register_incident(120), 120)
	assert_eq(Score.points, before + 120)


# --- crimes por bairro e por prédio (Fase 2) ---

func test_city_crimes_name_valid_buildings_and_districts() -> void:
	for t in CrimeProfiles.types_for("Cidade"):
		assert_gt(CrimeProfiles.near_of(t).size(), 0.0, t.id)
		for type in CrimeProfiles.near_of(t):
			assert_true(BuildingDefs.exists(type), "%s: %s" % [t.id, type])
		for district in t.districts:
			assert_true(DistrictLayout.IDS.has(district), "%s: %s" % [t.id, district])
		assert_true(t.night >= 0.0)
	for id in ["bank_heist", "bar_brawl", "break_in"]:
		assert_eq(CrimeProfiles.region_of(id), "Cidade")
	assert_eq(CrimeProfiles.near_of(CrimeProfiles.find_type("cattle_theft")), [], "no campo o crime não pede prédio")


func test_original_crimes_keep_their_numbers() -> void:
	# perfis por região intactos: os seis tipos antigos não mudaram
	var expected := {"assault": [3, 1, 100], "gang_fight": [2, 3, 200], "trafficking": [2, 2, 150],
		"smuggling": [2, 2, 150], "cattle_theft": [3, 1, 100], "illegal_farm": [1, 3, 220]}
	for id in expected:
		var t := CrimeProfiles.find_type(id)
		assert_eq([t.weight, t.criminals, t.reward], expected[id], id)
	assert_eq(CrimeProfiles.types_for("Campo").size(), 3)
	assert_eq(CrimeProfiles.types_for("Cidade").size(), 6)
	assert_almost_eq(CrimeProfiles.interval_for("Cidade"), 25.0)
	assert_almost_eq(CrimeProfiles.interval_for("Campo"), 45.0)


func test_weight_changes_with_district_and_night() -> void:
	var brawl := CrimeProfiles.find_type("bar_brawl")
	assert_almost_eq(CrimeProfiles.weight_of(brawl), 2.0)
	assert_almost_eq(CrimeProfiles.weight_of(brawl, "nightlife"), 6.0)
	assert_almost_eq(CrimeProfiles.weight_of(brawl, "nightlife", true), 18.0)
	assert_almost_eq(CrimeProfiles.weight_of(brawl, "civic"), 2.0, 0.01, "bairro sem multiplicador")
	assert_almost_eq(CrimeProfiles.weight_of(CrimeProfiles.find_type("bank_heist"), "center", true), 0.0)
	assert_almost_eq(CrimeProfiles.weight_of(CrimeProfiles.find_type("illegal_farm"), "", true), 1.0)


func test_pick_follows_the_district() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var counts := {"nightlife": {}, "residential": {}}
	for district in counts:
		for i in 2000:
			var id: String = CrimeProfiles.pick("Cidade", rng, district).id
			counts[district][id] = counts[district].get(id, 0) + 1
	assert_gt(counts["nightlife"]["bar_brawl"], counts["residential"]["bar_brawl"] * 2.0)
	assert_gt(counts["residential"]["break_in"], counts["nightlife"]["break_in"] * 1.5)
	assert_gt(counts["nightlife"]["bar_brawl"], counts["nightlife"]["assault"])


func test_bank_heist_never_happens_at_night() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var by_day := 0
	for i in 1500:
		assert_ne(CrimeProfiles.pick("Cidade", rng, "center", true).id, "bank_heist")
		if CrimeProfiles.pick("Cidade", rng, "center").id == "bank_heist":
			by_day += 1
	assert_gt(by_day, 50.0)


func test_alert_text_names_the_place() -> void:
	var t := CrimeProfiles.find_type("bar_brawl")
	var text := CrimeProfiles.alert_text(t, Vector2(0, 0), Vector2(600, 0), "Bar Saideira")
	assert_true(text.contains("Briga de bar (Bar Saideira)"), text)
	assert_true(text.contains("50 m"))
	assert_false(CrimeProfiles.alert_text(t, Vector2(0, 0), Vector2(600, 0)).contains("("))


func test_buildings_of_filters_by_type_and_distance() -> void:
	var from := Vector2(3360, 3360)
	var bars: Array = layout.buildings_of(["bar"], from)
	assert_true(bars.size() >= BuildingDefs.min_count("bar"))
	for b in bars:
		assert_eq(b.type, "bar")
	for b in layout.buildings_of(["bar", "club"], from, 500.0, 1500.0):
		var d: float = (b.exit_spawn as Vector2).distance_to(from)
		assert_true(d >= 500.0 and d <= 1500.0)
	assert_eq(layout.buildings_of(["castelo"], from), [])
	var nearest: Dictionary = layout.nearest_building_of(["bar"], from)
	for b in bars:
		assert_true((nearest.exit_spawn as Vector2).distance_to(from) <= (b.exit_spawn as Vector2).distance_to(from) + 0.01)
	assert_eq(layout.nearest_building_of(["castelo"], from), {})


func test_pick_place_returns_a_compatible_building() -> void:
	await _setup(Vector2(3360, 3360))
	manager.enabled = false
	var found := 0
	for t in CrimeProfiles.types_for("Cidade"):
		var place: Dictionary = manager.pick_place(t, player.global_position)
		if place.is_empty():
			continue
		found += 1
		assert_true(CrimeProfiles.near_of(t).has(place.type), "%s em frente a %s" % [t.id, place.type])
		var d: float = (place.exit_spawn as Vector2).distance_to(player.global_position)
		assert_true(d >= manager.MIN_DISTANCE and d <= manager.MAX_PLACE_DISTANCE)
	assert_gt(found, 3.0)
	assert_eq(manager.pick_place(CrimeProfiles.find_type("cattle_theft"), player.global_position), {})


func test_city_crime_appears_in_front_of_a_compatible_building() -> void:
	await _setup(Vector2(3360, 3360))
	manager.enabled = false
	var with_place := 0
	for i in 12:
		manager.incidents.clear()
		if not manager.try_spawn():
			continue
		var inc: Dictionary = manager.incidents[0]
		if inc.place == "":
			continue
		with_place += 1
		var building := {}
		for b in layout.buildings():
			if b.name == inc.place:
				building = b
		assert_true(CrimeProfiles.near_of(inc.type).has(building.type), "%s em frente a %s" % [inc.type.id, building.type])
		assert_eq(inc.center, building.exit_spawn)
		assert_eq(layout.building_at(inc.center), -1, "crime dentro de prédio")
	assert_gt(with_place, 6.0)


func test_country_crimes_still_use_a_free_point() -> void:
	await _setup(Vector2(9500, 2000))
	manager.enabled = false
	assert_true(manager.try_spawn())
	var inc: Dictionary = manager.incidents[0]
	assert_eq(inc.place, "")
	assert_eq(inc.region, "Campo")
	assert_eq(CrimeProfiles.region_of(inc.type.id), "Campo")


# --- crimes à noite (Fase 4) ---

func test_crimes_come_faster_at_night_in_the_city() -> void:
	await _setup(Vector2(3360, 3360))
	manager.enabled = false
	WorldClock.paused = true
	WorldClock.set_hour(12.0)
	manager.rng.seed = 9
	var by_day: float = manager._next_interval()
	WorldClock.set_hour(23.0)
	manager.rng.seed = 9
	var by_night: float = manager._next_interval()
	assert_almost_eq(by_night, by_day * 0.64, 0.01)


func test_country_interval_does_not_change_at_night() -> void:
	await _setup(Vector2(9500, 2000))
	manager.enabled = false
	WorldClock.paused = true
	WorldClock.set_hour(12.0)
	manager.rng.seed = 9
	var by_day: float = manager._next_interval()
	WorldClock.set_hour(23.0)
	manager.rng.seed = 9
	assert_almost_eq(manager._next_interval(), by_day, 0.001)


func test_night_spawns_use_the_night_weights() -> void:
	await _setup(Vector2(3360, 3360))
	manager.enabled = false
	WorldClock.paused = true
	WorldClock.set_hour(23.0)
	var seen := {}
	for i in 40:
		manager.incidents.clear()
		if manager.try_spawn():
			seen[manager.incidents[0].type.id] = true
	assert_false(seen.has("bank_heist"), "assalto a banco não acontece à noite")
	assert_gt(seen.size(), 1.0)


func test_bank_heist_needs_an_open_bank() -> void:
	await _setup(Vector2(3360, 3360))
	manager.enabled = false
	WorldClock.paused = true
	var heist := CrimeProfiles.find_type("bank_heist")
	assert_true(heist.open_only)
	WorldClock.set_hour(18.0)
	assert_eq(manager.pick_place(heist, player.global_position), {}, "banco fechado às 18:00")
	WorldClock.set_hour(10.0)
	var found := false
	for i in 10:
		var place: Dictionary = manager.pick_place(heist, player.global_position)
		if not place.is_empty():
			found = true
			assert_eq(place.type, "bank")
	var banks: Array = layout.buildings_of(["bank"], player.global_position, manager.MIN_DISTANCE, manager.MAX_PLACE_DISTANCE)
	assert_eq(found, not banks.is_empty())
