extends "res://scripts/interaction/interact_zone.gd"
## Porta: ao encostar mostra a instrução; ao pressionar a tecla de interação
## entra no prédio (ou sai dele).

const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const NameGenerator := preload("res://scripts/world/name_generator.gd")

@export var building_id := -1
@export var exits := false
## Onde o jogador reaparece no mundo ao sair do prédio.
@export var return_position := Vector2.ZERO
## Tipo de loja do prédio ("" se for um prédio comum).
@export var shop := ""
## Tipo (BuildingDefs) e nome próprio do prédio; o nome aparece na instrução do HUD.
@export var building_type := ""
@export var building_name := ""
## Largura da fachada (px): define o tamanho do interior.
@export var facade_width := 240.0


func _ready() -> void:
	if exits:
		verb = "sair"
	elif building_name != "":
		verb = "entrar %s" % NameGenerator.at_place(building_name)
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
		GameState.go_inside(building_id, return_position, shop, building_type, building_name, facade_width)
