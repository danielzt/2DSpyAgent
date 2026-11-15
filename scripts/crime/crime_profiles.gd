extends RefCounted
## Perfis de crime por região: cada região tem seus próprios tipos de crime, frequência,
## número de criminosos e recompensa.

const METERS_PER_PIXEL := 1.0 / 12.0

const PROFILES := {
	"Cidade": {
		"interval": 25.0,  # segundos entre ocorrências
		"types": [
			{"id": "assault", "name": "Assalto armado", "weight": 3, "criminals": 1, "reward": 100},
			{"id": "gang_fight", "name": "Briga de gangues", "weight": 2, "criminals": 3, "reward": 200},
			{"id": "trafficking", "name": "Tráfico de drogas", "weight": 2, "criminals": 2, "reward": 150},
		],
	},
	"Campo": {
		"interval": 45.0,
		"types": [
			{"id": "smuggling", "name": "Contrabando", "weight": 2, "criminals": 2, "reward": 150},
			{"id": "cattle_theft", "name": "Roubo de gado", "weight": 3, "criminals": 1, "reward": 100},
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


## Sorteia um tipo de crime da região, respeitando os pesos. {} se a região não tem perfil.
static func pick(region: String, rng: RandomNumberGenerator) -> Dictionary:
	var types := types_for(region)
	if types.is_empty():
		return {}
	var total := 0
	for t in types:
		total += t.weight
	var roll := rng.randi_range(1, total)
	for t in types:
		roll -= t.weight
		if roll <= 0:
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


static func alert_text(type: Dictionary, from: Vector2, to: Vector2) -> String:
	return "Crime em andamento: %s — a %d m %s" % [
		type.name, roundi(from.distance_to(to) * METERS_PER_PIXEL), direction_text(from, to)]
