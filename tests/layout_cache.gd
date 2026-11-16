extends RefCounted
## Cache de `InteriorLayout` para os testes: gerar uma planta custa ~15 ms e as varreduras
## (todos os tipos x dezenas de ids) geravam as mesmas plantas várias vezes, em testes e
## arquivos diferentes. A geração é determinística por (id, tipo) e a largura da fachada não
## muda a planta (garantido por `test_interior_layout.test_facade_does_not_change_the_layout`).
##
## Só para uso de LEITURA: quem altera o layout (ex.: acrescenta parede) deve usar
## `InteriorLayout.new`. Também não use para testar determinismo (compararia o objeto com ele mesmo).
## Com planta injetada (`Plans.override`) o cache é ignorado.

const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")

static var _cache := {}


static func layout(building_id: int, type: String) -> InteriorLayout:
	if Plans.has_overrides():
		return InteriorLayout.new(building_id, type)
	var key := "%s#%d" % [type, building_id]
	if not _cache.has(key):
		_cache[key] = InteriorLayout.new(building_id, type)
	return _cache[key]


static func size() -> int:
	return _cache.size()


static func clear() -> void:
	_cache.clear()
