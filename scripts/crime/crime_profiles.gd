extends RefCounted
## Perfis de crime por região: cada região tem seus próprios tipos de crime, frequência,
## número de criminosos e recompensa.
## Na cidade o crime também depende do lugar: `near` lista os tipos de prédio em frente aos
## quais ele acontece, `districts` multiplica o peso conforme o bairro (id do DistrictLayout)
## e `night` multiplica o peso à noite (0 = não acontece à noite; vale a partir da Fase 4).

const METERS_PER_PIXEL := 1.0 / 12.0

const PROFILES := {
	"Cidade": {
		"interval": 25.0,  # segundos entre ocorrências
		"types": [
			{"id": "assault", "name": "Assalto armado", "weight": 3, "criminals": 1, "reward": 100,
				"near": ["bank", "market", "gas_station"], "districts": {"center": 1.5, "residential": 1.2}, "night": 1.5},
			{"id": "gang_fight", "name": "Briga de gangues", "weight": 2, "criminals": 3, "reward": 200,
				"near": ["warehouse", "bar"], "districts": {"industrial": 2.0, "nightlife": 1.5}, "night": 2.0},
			{"id": "trafficking", "name": "Tráfico de drogas", "weight": 2, "criminals": 2, "reward": 150,
				"near": ["warehouse", "club"], "districts": {"industrial": 1.5, "nightlife": 2.0}, "night": 2.0},
			{"id": "bank_heist", "name": "Assalto a banco", "weight": 1, "criminals": 3, "reward": 260,
				"near": ["bank"], "districts": {"center": 2.0, "upscale": 1.5}, "night": 0.0},
			{"id": "bar_brawl", "name": "Briga de bar", "weight": 2, "criminals": 2, "reward": 120,
				"near": ["bar", "club"], "districts": {"nightlife": 3.0}, "night": 3.0},
			{"id": "break_in", "name": "Arrombamento", "weight": 2, "criminals": 1, "reward": 110,
				"near": ["house", "apartment"], "districts": {"residential": 2.0, "upscale": 2.0}, "night": 3.0},
		],
	},
	"Campo": {
		"interval": 45.0,
		"types": [
			{"id": "smuggling", "name": "Contrabando", "weight": 2, "criminals": 2, "reward": 150, "night": 2.0},
			{"id": "cattle_theft", "name": "Roubo de gado", "weight": 3, "criminals": 1, "reward": 100, "night": 1.5},
			{"id": "illegal_farm", "name": "Plantação ilegal", "weight": 1, "criminals": 3, "reward": 220},
		],
	},
}


static func has_region(region: String) -> bool:
	return PROFILES.has(region)


static func types_for(region: String) -> Array:
	return PROFILES[region].types if PROFILES.has(region) else []


static func interval_for(region: String) -> float:
	return PROFILES[region].interval if PROFILES.has(region) else 60.0


## Peso de um tipo de crime em um bairro (id; "" = sem bairro) e período do dia.
static func weight_of(type: Dictionary, district := "", night := false) -> float:
	var weight: float = type.weight
	weight *= float((type.get("districts", {}) as Dictionary).get(district, 1.0))
	if night:
		weight *= float(type.get("night", 1.0))
	return weight


## Tipos de prédio em frente aos quais o crime acontece ([] = em qualquer lugar).
static func near_of(type: Dictionary) -> Array:
	return type.get("near", [])


## Sorteia um tipo de crime da região, respeitando os pesos (ajustados pelo bairro e pelo
## período do dia). {} se a região não tem perfil ou nenhum tipo pode acontecer.
static func pick(region: String, rng: RandomNumberGenerator, district := "", night := false) -> Dictionary:
	var types := types_for(region)
	if types.is_empty():
		return {}
	var total := 0.0
	for t in types:
		total += weight_of(t, district, night)
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for t in types:
		var weight := weight_of(t, district, night)
		if weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return t
	return types[types.size() - 1]


static func find_type(type_id: String) -> Dictionary:
	for region in PROFILES:
		for t in PROFILES[region].types:
			if t.id == type_id:
				return t
	return {}


## Região a que um tipo de crime pertence ("" se desconhecido).
static func region_of(type_id: String) -> String:
	for region in PROFILES:
		for t in PROFILES[region].types:
			if t.id == type_id:
				return region
	return ""


## Pista de um crime que vai acontecer: sorteia um tipo de crime da cidade e um prédio
## compatível, de preferência perto de `near_point`. `layout` é o WorldLayout.
## {crime, crime_name, place, building_id, position, region} ou {} se não houver prédio.
static func make_tip(layout: RefCounted, rng: RandomNumberGenerator, near_point: Vector2, night := false) -> Dictionary:
	for attempt in 8:
		var type := pick("Cidade", rng, layout.district_id_at(near_point), night)
		if type.is_empty() or near_of(type).is_empty():
			continue
		var options: Array = layout.buildings_of(near_of(type), near_point, 300.0, 2500.0)
		if options.is_empty():
			options = layout.buildings_of(near_of(type), near_point)
		if options.is_empty():
			continue
		var b: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		return {"crime": type.id, "crime_name": type.name, "place": b.name, "building_id": b.id,
			"position": b.exit_spawn, "region": "Cidade"}
	return {}


## Direção aproximada de `to` vista de `from` ("ao norte", "a nordeste"...).
static func direction_text(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if d.length() < 1.0:
		return "aqui"
	var names := ["leste", "sudeste", "sul", "sudoeste", "oeste", "noroeste", "norte", "nordeste"]
	var index := int(roundf(d.angle() / (PI / 4.0))) % 8
	if index < 0:
		index += 8
	var name: String = names[index]
	return ("ao " if name in ["leste", "oeste", "norte", "sul"] else "a ") + name


## `place`: nome do prédio em frente ao qual o crime acontece ("" se não houver).
static func alert_text(type: Dictionary, from: Vector2, to: Vector2, place := "") -> String:
	var what: String = type.name if place == "" else "%s (%s)" % [type.name, place]
	return "Crime em andamento: %s — a %d m %s" % [
		what, roundi(from.distance_to(to) * METERS_PER_PIXEL), direction_text(from, to)]
