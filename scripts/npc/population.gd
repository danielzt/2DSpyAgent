extends RefCounted
## Liga cada NPC ao mundo (lógica pura): um prédio real onde trabalha e outro onde mora.
## Determinístico pela seed do NPC. Quem é da cidade trabalha e mora na cidade; quem é do
## campo, nas fazendas.

const BuildingDefs := preload("res://scripts/world/building_defs.gd")

const CITY := "Cidade"
const COUNTRY := "Campo"

## Por região: prédios com funcionários e prédios de moradia.
var _work := {}
var _homes := {}
## id do bairro -> nome (para o campo "district" do contexto).
var _district_names := {}


func _init(city_buildings: Array, country_buildings: Array, district_names := {}) -> void:
	_district_names = district_names
	_index(CITY, city_buildings)
	_index(COUNTRY, country_buildings)


func _index(region: String, buildings: Array) -> void:
	_work[region] = []
	_homes[region] = []
	for b in buildings:
		var type: String = b.get("type", "")
		if not BuildingDefs.staff_of(type).is_empty():
			_work[region].append(b)
		if BuildingDefs.is_home(type):
			_homes[region].append(b)


func workplaces(region: String) -> Array:
	return _work.get(region, [])


func homes(region: String) -> Array:
	return _homes.get(region, [])


## Contexto de um NPC: {work_id, work_name, work_type, role, home_id, home_name, district}.
## `district` é o nome do bairro onde mora ("Campo" fora da cidade). {} se a região não tem
## onde trabalhar ou morar.
func context_for(npc_seed: int, region: String) -> Dictionary:
	var work: Array = workplaces(region)
	var home: Array = homes(region)
	if work.is_empty() or home.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = npc_seed * 2654435 + 97
	var job: Dictionary = work[rng.randi_range(0, work.size() - 1)]
	var house: Dictionary = home[rng.randi_range(0, home.size() - 1)]
	var staff: Array = BuildingDefs.staff_of(job.type)
	return {
		"work_id": job.id,
		"work_name": job.name,
		"work_type": job.type,
		"role": staff[rng.randi_range(0, staff.size() - 1)],
		"home_id": house.id,
		"home_name": house.name,
		"district": _district_names.get(house.get("district", ""), COUNTRY if region == COUNTRY else ""),
	}
