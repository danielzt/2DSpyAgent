extends "res://scripts/interaction/interact_zone.gd"
## Porta: ao encostar mostra a instrução; ao pressionar a tecla de interação
## entra no prédio (ou sai dele).

const ShopDefs := preload("res://scripts/items/shop_defs.gd")

@export var building_id := -1
@export var exits := false
## Onde o jogador reaparece no mundo ao sair do prédio.
@export var return_position := Vector2.ZERO
## Tipo de loja do prédio ("" se for um prédio comum).
@export var shop := ""


func _ready() -> void:
	if exits:
		verb = "sair"
	elif shop != "":
		verb = "entrar na %s" % ShopDefs.shop_name(shop)
	else:
		verb = "entrar"
	super._ready()


func interact(player: Node) -> void:
	super.interact(player)
	activate()


func activate() -> void:
	if exits:
		GameState.go_outside()
	else:
		GameState.go_inside(building_id, return_position, shop)
