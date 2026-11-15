extends Node
## Estado global de navegação entre o mundo externo e os interiores.

const MAIN_SCENE := "res://scenes/main.tscn"
const INTERIOR_SCENE := "res://scenes/interior/interior.tscn"

const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")

var building_id := -1
var building_shop := ""
var return_position := Vector2.ZERO
var has_return := false

# Dados do jogador sobrevivem às trocas de cena (o nó Player é recriado a cada cena).
var _profiles := {}
var _inventories := {}


func is_inside() -> bool:
	return building_id >= 0


## Só altera o estado (testável sem trocar de cena).
func set_inside(id: int, p_return_position: Vector2, shop := "") -> void:
	building_id = id
	building_shop = shop
	return_position = p_return_position
	has_return = true


func set_outside() -> void:
	building_id = -1
	building_shop = ""


## Posição onde o jogador deve reaparecer no mundo; consome o retorno pendente.
func consume_return_position() -> Vector2:
	has_return = false
	return return_position


func go_inside(id: int, p_return_position: Vector2, shop := "") -> void:
	set_inside(id, p_return_position, shop)
	_change_scene.call_deferred(INTERIOR_SCENE)


func go_outside() -> void:
	set_outside()
	_change_scene.call_deferred(MAIN_SCENE)


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func profile_for(player_index: int) -> RefCounted:
	if not _profiles.has(player_index):
		_profiles[player_index] = ProfileScript.new(player_index)
	return _profiles[player_index]


func inventory_for(player_index: int) -> RefCounted:
	if not _inventories.has(player_index):
		_inventories[player_index] = InventoryScript.starter_kit()
	return _inventories[player_index]


## Zera fichas e inventários (novo jogo / testes).
func reset_players() -> void:
	_profiles.clear()
	_inventories.clear()
