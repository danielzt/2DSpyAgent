extends "res://scripts/interaction/interact_zone.gd"
## Porta: ao encostar mostra a instrução; ao pressionar a tecla de interação
## entra no prédio (ou sai dele).

const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const NameGenerator := preload("res://scripts/world/name_generator.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")

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


## Fora do horário de funcionamento do tipo do prédio a porta não abre.
func is_closed() -> bool:
	return not exits and building_type != "" and not BuildingDefs.is_open(building_type, WorldClock.hour())


func closed_text() -> String:
	var text := BuildingDefs.closed_text(building_type)
	return "%s: %s" % [building_name, text] if building_name != "" else text


func prompt_text(player: Node) -> String:
	return closed_text() if is_closed() else super.prompt_text(player)


func interact(player: Node) -> void:
	if is_closed():
		if player.has_method("notify"):
			player.notify(closed_text(), 4.0)
		return
	super.interact(player)
	activate()


func activate() -> void:
	if exits:
		GameState.go_outside()
	else:
		GameState.go_inside(building_id, return_position, shop, building_type, building_name, facade_width)
