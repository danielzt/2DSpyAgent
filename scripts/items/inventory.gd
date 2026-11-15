extends RefCounted
## Inventário do jogador: mochila (pilhas por item) e duas mãos.
## Um mesmo item só vai nas duas mãos se houver 2 unidades dele.

const ItemDefs := preload("res://scripts/items/item_defs.gd")

signal changed

const MAX_STACKS := 8
const MAX_COUNT := 9
const HANDS := ["left", "right"]

var _stacks := {}                      # id -> quantidade
var _hands := {"left": "", "right": ""}


## Kit inicial: pistola na esquerda, escudo na direita, mais taser, escopeta e 3 kits médicos.
static func starter_kit() -> RefCounted:
	var inv: RefCounted = (load("res://scripts/items/inventory.gd") as GDScript).new()
	inv.add("pistol")
	inv.add("shield")
	inv.add("taser")
	inv.add("shotgun")
	inv.add("medkit", 3)
	inv.equip("left", "pistol")
	inv.equip("right", "shield")
	return inv


func add(id: String, amount := 1) -> bool:
	if amount <= 0 or not ItemDefs.exists(id):
		return false
	if not _stacks.has(id) and _stacks.size() >= MAX_STACKS:
		return false
	if count(id) + amount > MAX_COUNT:
		return false
	_stacks[id] = count(id) + amount
	changed.emit()
	return true


func count(id: String) -> int:
	return _stacks.get(id, 0)


func ids() -> Array:
	return _stacks.keys()


func remove(id: String, amount := 1) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	_stacks[id] = count(id) - amount
	if _stacks[id] == 0:
		_stacks.erase(id)
	# Solta das mãos o que não existe mais na mochila.
	for hand in HANDS:
		if _hands[hand] == id and _available_for(hand, id) <= 0:
			_hands[hand] = ""
	changed.emit()
	return true


func equip(hand: String, id: String) -> bool:
	if not HANDS.has(hand) or _available_for(hand, id) <= 0:
		return false
	_hands[hand] = id
	changed.emit()
	return true


func unequip(hand: String) -> void:
	if HANDS.has(hand) and _hands[hand] != "":
		_hands[hand] = ""
		changed.emit()


func equipped(hand: String) -> String:
	return _hands.get(hand, "")


func equipped_def(hand: String) -> Dictionary:
	return ItemDefs.get_def(equipped(hand))


## Gasta uma unidade (itens consumíveis).
func consume(id: String) -> bool:
	return remove(id, 1)


# Unidades de `id` livres para a mão `hand` (descontando a outra mão).
func _available_for(hand: String, id: String) -> int:
	var other: String = "right" if hand == "left" else "left"
	return count(id) - (1 if _hands[other] == id else 0)
