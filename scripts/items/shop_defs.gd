extends RefCounted
## Tipos de loja e a lógica pura de compra e venda.

const ItemDefs := preload("res://scripts/items/item_defs.gd")

const SHOPS := {
	"armory": {"name": "Armaria", "stock": ["pistol", "shotgun", "taser"]},
	"pharmacy": {"name": "Farmácia", "stock": ["medkit"]},
	"agent_store": {"name": "Loja do Agente", "stock": ["shield", "taser", "medkit"]},
	"farm_store": {"name": "Armazém Rural", "stock": ["medkit", "shotgun"]},
}


static func exists(shop_id: String) -> bool:
	return SHOPS.has(shop_id)


static func shop_name(shop_id: String) -> String:
	return SHOPS[shop_id].name if SHOPS.has(shop_id) else ""


static func stock(shop_id: String) -> Array:
	return SHOPS[shop_id].stock if SHOPS.has(shop_id) else []


## Compra 1 unidade. Retorna "ok", "not_sold", "no_money" ou "no_space".
static func buy(shop_id: String, item_id: String, inventory: RefCounted, profile: RefCounted) -> String:
	if not stock(shop_id).has(item_id):
		return "not_sold"
	var price := ItemDefs.price(item_id)
	if profile.money < price:
		return "no_money"
	if not inventory.add(item_id):
		return "no_space"
	profile.spend_money(price)
	return "ok"


## Vende 1 unidade por metade do preço. Retorna "ok" ou "not_owned".
static func sell(item_id: String, inventory: RefCounted, profile: RefCounted) -> String:
	if inventory.count(item_id) <= 0:
		return "not_owned"
	inventory.remove(item_id)
	profile.add_money(ItemDefs.sell_price(item_id))
	return "ok"


static func message_for(result: String, item_id := "") -> String:
	var item_name: String = ItemDefs.get_def(item_id).get("name", item_id)
	match result:
		"ok":
			return "Pronto: %s." % item_name
		"no_money":
			return "Dinheiro insuficiente."
		"no_space":
			return "Mochila cheia (ou limite de unidades)."
		"not_sold":
			return "A loja não vende isso."
		"not_owned":
			return "Você não tem isso."
	return ""
