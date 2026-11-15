extends RefCounted
## Definições dos itens que o jogador pode carregar e equipar nas mãos.
## kind: "weapon" (atira ao segurar o botão), "tool" (usa ao clicar), "shield" (bloqueia ao segurar).

const ITEMS := {
	"pistol": {
		"id": "pistol", "name": "Pistola", "kind": "weapon",
		"damage": 1.0, "interval": 0.25, "pellets": 1, "spread": 0.0, "lifetime": 0.7, "effect": "damage",
		"description": "Tiro único e preciso, bom alcance.", "price": 150,
	},
	"shotgun": {
		"id": "shotgun", "name": "Escopeta", "kind": "weapon",
		"damage": 1.0, "interval": 0.8, "pellets": 5, "spread": 0.45, "lifetime": 0.3, "effect": "damage",
		"description": "Cinco projéteis em cone. Curto alcance, muito dano de perto.", "price": 400,
	},
	"taser": {
		"id": "taser", "name": "Taser", "kind": "weapon",
		"damage": 0.0, "interval": 1.5, "pellets": 1, "spread": 0.0, "lifetime": 0.35, "effect": "stun",
		"description": "Atordoa por 3 s sem matar. Atordoar criminoso dá pontos; inocente tira poucos.", "price": 200,
	},
	"medkit": {
		"id": "medkit", "name": "Kit médico", "kind": "tool",
		"heal": 4.0,
		"description": "Recupera 4 de vida ao usar. Consumível.", "price": 40,
	},
	"shield": {
		"id": "shield", "name": "Escudo balístico", "kind": "shield",
		"description": "Segure para bloquear tiros vindos da frente. Andar fica 40% mais lento.", "price": 250,
	},
}


static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func all_ids() -> Array:
	return ITEMS.keys()


static func price(id: String) -> int:
	return get_def(id).get("price", 0)


## Loja compra por metade do preço.
static func sell_price(id: String) -> int:
	return int(price(id) / 2.0)
