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
