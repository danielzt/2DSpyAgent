extends RefCounted
## Layout lógico do mundo inteiro: regiões Cidade e Campo lado a lado.

const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")
const TrafficRoute := preload("res://scripts/vehicle/traffic_route.gd")
const SidewalkGraph := preload("res://scripts/world/sidewalk_graph.gd")
const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const PickupItemDefs := preload("res://scripts/items/item_defs.gd")
const Population := preload("res://scripts/npc/population.gd")
const NameGenerator := preload("res://scripts/world/name_generator.gd")

const CITY_PEDESTRIANS := 110
const COUNTRY_CIVILIANS := 12
const CITY_CRIMINALS := 4
const COUNTRY_CRIMINALS := 6
## Seed do primeiro NPC do mundo (os seguintes somam o índice).
const NPC_SEED_BASE := 1000
## Margem em volta da estrada do campo em que o HUD ainda mostra o nome dela.
const COUNTRY_ROAD_MARGIN := 60.0
const NPC_MIN_START_DISTANCE := 350.0
const CRIMINAL_MIN_START_DISTANCE := 700.0
## Carros de trânsito: [cruzamento de destino, direção de chegada].
const TRAFFIC := [
	[Vector2i(2, 2), Vector2i(1, 0)], [Vector2i(4, 1), Vector2i(0, 1)],
	[Vector2i(6, 3), Vector2i(-1, 0)], [Vector2i(8, 2), Vector2i(0, -1)],
	[Vector2i(10, 4), Vector2i(1, 0)], [Vector2i(3, 6), Vector2i(0, 1)],
	[Vector2i(5, 8), Vector2i(-1, 0)], [Vector2i(7, 6), Vector2i(0, -1)],
	[Vector2i(9, 9), Vector2i(1, 0)], [Vector2i(11, 7), Vector2i(0, 1)],
]
const TRAFFIC_START_BEFORE_NODE := 120.0

## Itens espalhados: [item ("cash" = dinheiro), quantidade, região]
const PICKUP_PLAN := [
	["cash", 40, "Cidade"], ["cash", 25, "Cidade"], ["cash", 60, "Cidade"], ["cash", 30, "Cidade"],
	["cash", 50, "Cidade"], ["cash", 35, "Cidade"], ["medkit", 1, "Cidade"], ["medkit", 1, "Cidade"],
	["medkit", 1, "Cidade"], ["medkit", 2, "Cidade"], ["taser", 1, "Cidade"], ["pistol", 1, "Cidade"],
	["cash", 80, "Campo"], ["cash", 45, "Campo"], ["medkit", 1, "Campo"], ["medkit", 1, "Campo"],
	["shotgun", 1, "Campo"], ["shield", 1, "Campo"],
]

var city
var country
## Cada região: {id:String, name:String, rect:Rect2}
var regions: Array[Dictionary] = []
## Cada NPC: {position, kind, mode ("sidewalk"|"free"), from:Vector4i, to:Vector4i, crime:String,
## seed:int, context:Dictionary}. `context` (trabalho e moradia) só existe para civis.
var npcs: Array[Dictionary] = []
## Trabalho e moradia dos NPCs (Population).
var population
## Cada item no chão: {position:Vector2, item:String, amount:int}
var pickups: Array[Dictionary] = []


func _init(p_seed: int = 2024) -> void:
	city = CityLayout.new(p_seed)
	var cs := CityLayout.city_size()
	country = CountryLayout.new(Vector2(cs, 0.0), p_seed + 1)
	regions = [
		{"id": "city", "name": "Cidade", "rect": Rect2(0, 0, cs, cs)},
		{"id": "country", "name": "Campo", "rect": country.region_rect()},
	]
	population = Population.new(city.buildings, country.buildings, city.districts.names)
	_generate_npcs(p_seed + 7)
	_assign_population()
	_generate_pickups(p_seed + 11)


static func world_size() -> Vector2:
	var cs := CityLayout.city_size()
	return Vector2(cs + CountryLayout.SIZE.x, maxf(cs, CountryLayout.SIZE.y))


static func spawn_point() -> Vector2:
	return CityLayout.spawn_point()


## Todos os prédios do mundo (cidade + fazendas).
func buildings() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(city.buildings)
	all.append_array(country.buildings)
	return all


func region_at(point: Vector2) -> String:
	for r in regions:
		if (r.rect as Rect2).has_point(point):
			return r.name
	return ""


func region_rect(region_name: String) -> Rect2:
	for r in regions:
		if r.name == region_name:
			return r.rect
	return Rect2()


func building_at(point: Vector2) -> int:
	for b in buildings():
		if (b.rect as Rect2).has_point(point):
			return b.id
	return -1


func building_by_id(id: int) -> Dictionary:
	for b in buildings():
		if b.id == id:
			return b
	return {}


## Id do bairro do ponto ("" fora da cidade).
func district_id_at(point: Vector2) -> String:
	return city.districts.district_at(point)


## Nome do bairro do ponto ("" fora da cidade).
func district_at(point: Vector2) -> String:
	return city.districts.name_at(point)


## Nome da rua do ponto: na cidade, a rua onde está ou a mais próxima; no campo, a estrada
## (só perto dela).
func street_name_at(point: Vector2) -> String:
	if (regions[0].rect as Rect2).has_point(point):
		return city.street_name_at(point)
	if (country.road as Rect2).grow(COUNTRY_ROAD_MARGIN).has_point(point):
		return NameGenerator.COUNTRY_ROAD
	return ""


## Texto do HUD: "Bairro • Rua" (o que existir).
func place_text(point: Vector2) -> String:
	var parts: Array[String] = []
	for part in [district_at(point), street_name_at(point)]:
		if part != "":
			parts.append(part)
	return " • ".join(parts)


## Prédios dos tipos dados cuja saída fica entre `min_d` e `max_d` de `point`.
func buildings_of(types: Array, point: Vector2, min_d := 0.0, max_d := INF) -> Array:
	var result: Array = []
	for b in buildings():
		if not types.has(b.get("type", "")):
			continue
		var d := (b.exit_spawn as Vector2).distance_to(point)
		if d >= min_d and d <= max_d:
			result.append(b)
	return result


## Prédio mais próximo de `point` entre os tipos dados ({} se não houver).
func nearest_building_of(types: Array, point: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for b in buildings_of(types, point):
		var d := (b.exit_spawn as Vector2).distance_to(point)
		if d < best_d:
			best_d = d
			best = b
	return best


func vehicle_spawns() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(CityLayout.vehicle_spawns())
	all.append_array(country.vehicle_spawns())
	return all


## Cada carro de trânsito: {node:Vector2i, dir:Vector2i, lane:int, position:Vector2, rotation:float}.
## `lane` é a faixa que o carro usa nas avenidas (alterna entre a de dentro e a de fora).
func traffic_spawns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in TRAFFIC.size():
		var node: Vector2i = TRAFFIC[i][0]
		var dir: Vector2i = TRAFFIC[i][1]
		var lane := i % 2
		result.append({
			"node": node,
			"dir": dir,
			"lane": lane,
			"position": TrafficRoute.lane_point(node, dir, lane) - Vector2(dir) * TRAFFIC_START_BEFORE_NODE,
			"rotation": Vector2(dir).angle(),
		})
	return result


## Ponto livre (fora de prédios, árvores e carros) entre `min_d` e `max_d` de `center`, dentro de `area`.
## Retorna Vector2.INF se não achar.
func free_point_near(center: Vector2, min_d: float, max_d: float, rng: RandomNumberGenerator, area: Rect2) -> Vector2:
	for i in 60:
		var p := center + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(min_d, max_d)
		if area.has_point(p) and not is_blocked(p, 30.0):
			return p
	return Vector2.INF


## True se o ponto está dentro/perto de prédio, árvore ou carro estacionado.
func is_blocked(p: Vector2, margin: float) -> bool:
	for b in buildings():
		if (b.rect as Rect2).grow(margin).has_point(p):
			return true
	for t in country.trees:
		if t.distance_to(p) < margin + 24.0:
			return true
	for t in city.trees:
		if t.distance_to(p) < margin + 24.0:
			return true
	for v in vehicle_spawns():
		if (v.position as Vector2).distance_to(p) < margin + 30.0:
			return true
	return false


func _generate_npcs(npc_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = npc_seed
	# Pedestres da cidade andam pelas calçadas.
	var placed := 0
	var attempts := 0
	while placed < CITY_PEDESTRIANS and attempts < 4000:
		attempts += 1
		var s := SidewalkGraph.random_sidewalk_point(rng)
		var p: Vector2 = s.position
		if p.distance_to(spawn_point()) < NPC_MIN_START_DISTANCE or _near_vehicle(p, 50.0) or _inside_building(p):
			continue
		npcs.append({"position": p, "kind": "innocent", "mode": "sidewalk", "from": s.from, "to": s.to, "crime": ""})
		placed += 1
	var cs := CityLayout.city_size()
	var city_area := Rect2(100, 100, cs - 200, cs - 200)
	var country_area: Rect2 = country.region_rect().grow(-200)
	_scatter(rng, COUNTRY_CIVILIANS, "innocent", country_area, NPC_MIN_START_DISTANCE, "Campo")
	_scatter(rng, CITY_CRIMINALS, "criminal", city_area, CRIMINAL_MIN_START_DISTANCE, "Cidade")
	_scatter(rng, COUNTRY_CRIMINALS, "criminal", country_area, CRIMINAL_MIN_START_DISTANCE, "Campo")


## Dá a cada NPC a sua seed e, aos civis, um trabalho e uma moradia na região onde estão.
func _assign_population() -> void:
	for i in npcs.size():
		var npc: Dictionary = npcs[i]
		npc["seed"] = NPC_SEED_BASE + i
		npc["context"] = {}
		if npc.kind == "innocent":
			npc["context"] = population.context_for(npc.seed, region_at(npc.position))


func _scatter(rng: RandomNumberGenerator, count: int, kind: String, area: Rect2, min_start_distance: float, region_name: String) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 3000:
		attempts += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if p.distance_to(spawn_point()) < min_start_distance or is_blocked(p, 24.0) or _near_traffic(p):
			continue
		var crime := ""
		if kind == "criminal":
			crime = CrimeProfiles.pick(region_name, rng).id
		npcs.append({"position": p, "kind": kind, "mode": "free", "from": Vector4i.ZERO, "to": Vector4i.ZERO, "crime": crime})
		placed += 1


func _generate_pickups(pickup_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pickup_seed
	for plan in PICKUP_PLAN:
		var region: String = plan[2]
		for i in 200:
			var p: Vector2
			if region == "Cidade":
				p = SidewalkGraph.random_sidewalk_point(rng).position
			else:
				var area: Rect2 = country.region_rect().grow(-200)
				p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			if p.distance_to(spawn_point()) < 150.0 or is_blocked(p, 12.0) or _near_traffic(p):
				continue
			pickups.append({"position": p, "item": plan[0], "amount": plan[1]})
			break


func _inside_building(p: Vector2) -> bool:
	for b in city.buildings:
		if (b.rect as Rect2).grow(6.0).has_point(p):
			return true
	for t in city.trees:
		if t.distance_to(p) < 34.0:
			return true
	return false


func _near_vehicle(p: Vector2, d: float) -> bool:
	for v in vehicle_spawns():
		if (v.position as Vector2).distance_to(p) < d:
			return true
	return false


func _near_traffic(p: Vector2) -> bool:
	for t in traffic_spawns():
		if (t.position as Vector2).distance_to(p) < 80.0:
			return true
	return false
