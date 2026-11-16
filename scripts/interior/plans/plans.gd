extends RefCounted
## Registro das plantas de interior em mapa de texto (ver `plan_parser.gd`).
## Cada planta é um script com `static func data() -> Dictionary`.
## Os tipos sem planta usam o construtor antigo de `interior_layout.gd`.

## Tipo de prédio -> script da planta.
const PLANS := {
	"house": preload("res://scripts/interior/plans/house.gd"),
	"agent_home": preload("res://scripts/interior/plans/agent_home.gd"),
	"bar": preload("res://scripts/interior/plans/bar.gd"),
	"police": preload("res://scripts/interior/plans/police.gd"),
	"hospital": preload("res://scripts/interior/plans/hospital.gd"),
	"bank": preload("res://scripts/interior/plans/bank.gd"),
	"hotel": preload("res://scripts/interior/plans/hotel.gd"),
	"restaurant": preload("res://scripts/interior/plans/restaurant.gd"),
	"diner": preload("res://scripts/interior/plans/diner.gd"),
	"club": preload("res://scripts/interior/plans/club.gd"),
	"armory": preload("res://scripts/interior/plans/armory.gd"),
	"pharmacy": preload("res://scripts/interior/plans/pharmacy.gd"),
	"agent_store": preload("res://scripts/interior/plans/agent_store.gd"),
	"market": preload("res://scripts/interior/plans/market.gd"),
	"gas_station": preload("res://scripts/interior/plans/gas_station.gd"),
	"farm_store": preload("res://scripts/interior/plans/farm_store.gd"),
	"workshop": preload("res://scripts/interior/plans/workshop.gd"),
	"gym": preload("res://scripts/interior/plans/gym.gd"),
	"cinema": preload("res://scripts/interior/plans/cinema.gd"),
	"office": preload("res://scripts/interior/plans/office.gd"),
	"newspaper": preload("res://scripts/interior/plans/newspaper.gd"),
	"apartment": preload("res://scripts/interior/plans/apartment.gd"),
	"farm": preload("res://scripts/interior/plans/farm.gd"),
	"warehouse": preload("res://scripts/interior/plans/warehouse.gd"),
	"hq": preload("res://scripts/interior/plans/hq.gd"),
}

## Plantas injetadas (testes): têm prioridade sobre o registro.
static var _overrides := {}


static func has(type: String) -> bool:
	return _overrides.has(type) or PLANS.has(type)


static func data(type: String) -> Dictionary:
	if _overrides.has(type):
		return _overrides[type]
	return PLANS[type].data()


static func types() -> Array:
	var result := PLANS.keys()
	for type in _overrides:
		if not result.has(type):
			result.append(type)
	return result


static func override(type: String, plan: Dictionary) -> void:
	_overrides[type] = plan


static func clear_overrides() -> void:
	_overrides.clear()
