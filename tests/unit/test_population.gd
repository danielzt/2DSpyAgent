extends "res://tests/base_test.gd"
## NPCs ligados ao mundo: trabalho e moradia em prédios reais, e as falas que os citam.

const Population := preload("res://scripts/npc/population.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const NameGenerator := preload("res://scripts/world/name_generator.gd")

var layout


func before_each() -> void:
	layout = WorldLayout.new()


# --- população (pura) ---

func test_workplaces_have_staff_and_homes_are_homes() -> void:
	for region in [Population.CITY, Population.COUNTRY]:
		assert_gt(layout.population.workplaces(region).size(), 0.0, region)
		assert_gt(layout.population.homes(region).size(), 0.0, region)
		for b in layout.population.workplaces(region):
			assert_false(BuildingDefs.staff_of(b.type).is_empty(), b.name)
		for b in layout.population.homes(region):
			assert_true(BuildingDefs.is_home(b.type), b.name)
	assert_eq(layout.population.workplaces("Lua"), [])


func test_context_points_to_real_buildings() -> void:
	for s in range(1000, 1060):
		for region in [Population.CITY, Population.COUNTRY]:
			var c: Dictionary = layout.population.context_for(s, region)
			var work: Dictionary = layout.building_by_id(c.work_id)
			var home: Dictionary = layout.building_by_id(c.home_id)
			assert_eq(work.name, c.work_name)
			assert_eq(home.name, c.home_name)
			assert_eq(work.type, c.work_type)
			assert_true(BuildingDefs.staff_of(work.type).has(c.role), "%s não trabalha em %s" % [c.role, work.type])
			assert_true(BuildingDefs.is_home(home.type))
			assert_eq(layout.region_at(work.exit_spawn), region)
			assert_eq(layout.region_at(home.exit_spawn), region)
			assert_ne(c.district, "")


func test_city_district_is_the_one_where_the_npc_lives() -> void:
	for s in range(1, 40):
		var c: Dictionary = layout.population.context_for(s, Population.CITY)
		var home: Dictionary = layout.building_by_id(c.home_id)
		assert_eq(c.district, layout.district_at((home.rect as Rect2).get_center()))
	assert_eq(layout.population.context_for(5, Population.COUNTRY).district, "Campo")


func test_context_is_deterministic_and_varies() -> void:
	assert_eq(layout.population.context_for(77, Population.CITY), layout.population.context_for(77, Population.CITY))
	var works := {}
	var homes := {}
	for s in range(1, 120):
		var c: Dictionary = layout.population.context_for(s, Population.CITY)
		works[c.work_id] = true
		homes[c.home_id] = true
	assert_gt(works.size(), 30.0, "todo mundo trabalha no mesmo lugar")
	assert_gt(homes.size(), 30.0, "todo mundo mora no mesmo lugar")


func test_region_without_buildings_gives_no_context() -> void:
	var empty := Population.new([], [])
	assert_eq(empty.context_for(1, Population.CITY), {})
	assert_eq(layout.population.context_for(1, "Lua"), {})


# --- NPCs do mundo ---

func test_every_civilian_has_a_job_and_a_home_in_its_region() -> void:
	var civilians := 0
	for i in layout.npcs.size():
		var npc: Dictionary = layout.npcs[i]
		assert_eq(npc.seed, WorldLayout.NPC_SEED_BASE + i)
		if npc.kind != "innocent":
			assert_eq(npc.context, {}, "criminoso não tem ficha de trabalho")
			continue
		civilians += 1
		var c: Dictionary = npc.context
		var region: String = layout.region_at(npc.position)
		assert_false(c.is_empty(), "civil %d sem contexto" % i)
		assert_eq(layout.region_at(layout.building_by_id(c.work_id).exit_spawn), region)
		assert_eq(layout.region_at(layout.building_by_id(c.home_id).exit_spawn), region)
	assert_eq(civilians, WorldLayout.CITY_PEDESTRIANS + WorldLayout.COUNTRY_CIVILIANS)


# --- identidade e falas ---

func test_identity_without_context_is_unchanged() -> void:
	var id := NpcIdentity.generate(42)
	assert_true(NpcIdentity.JOBS.has(id.job))
	assert_false(NpcIdentity.has_place(id))
	assert_false(id.has("work_name"))
	assert_true(NpcIdentity.answer(id, "job").begins_with("Trabalho com"))
	assert_true(NpcIdentity.answer(id, "about").contains("moro por aqui"))
	assert_eq(NpcIdentity.generate(42, "innocent", {}), id)


func test_context_does_not_change_name_age_or_traits() -> void:
	var plain := NpcIdentity.generate(42)
	var linked := NpcIdentity.generate(42, "innocent", layout.population.context_for(42, Population.CITY))
	for key in ["name", "age", "traits", "mood", "years", "seed", "kind"]:
		assert_eq(linked[key], plain[key], key)
	assert_true(NpcIdentity.has_place(linked))
	assert_eq(linked.job, linked.role)


func test_answers_name_the_workplace_and_the_home() -> void:
	for s in range(1000, 1030):
		var c: Dictionary = layout.population.context_for(s, Population.CITY)
		var id := NpcIdentity.generate(s, "innocent", c)
		var job := NpcIdentity.answer(id, "job")
		assert_true(job.contains(c.work_name), job)
		assert_true(job.contains(c.role), job)
		assert_true(job.begins_with("Sou "), job)
		var about := NpcIdentity.answer(id, "about")
		assert_true(about.contains(c.home_name), about)
		assert_true(about.contains(c.district), about)
		assert_true(about.contains(id.name))
		var summary := NpcIdentity.summary(id)
		assert_true(summary.contains(c.role) and summary.contains(c.work_name), summary)


func test_answers_use_the_right_preposition() -> void:
	var c := {"work_id": 1, "work_name": "Cantina Bela Máfia", "work_type": "restaurant", "role": "chef",
		"home_id": 2, "home_name": "Edifício Codinome", "district": "Vila Sossego"}
	var id := NpcIdentity.generate(9, "innocent", c)
	assert_true(NpcIdentity.answer(id, "job").contains("Sou chef na Cantina Bela Máfia há"))
	assert_true(NpcIdentity.answer(id, "about").contains("moro no Edifício Codinome, na Vila Sossego, há"))


func test_country_civilians_talk_about_the_farms() -> void:
	var c: Dictionary = layout.population.context_for(3, Population.COUNTRY)
	var id := NpcIdentity.generate(3, "innocent", c)
	assert_true(NpcIdentity.answer(id, "about").contains("no Campo"))
	assert_true(BuildingDefs.is_home(layout.building_by_id(c.home_id).type))
