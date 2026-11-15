extends Node
## Estado global de navegação entre o mundo externo e os interiores.

const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
const INTERIOR_SCENE := "res://scenes/interior/interior.tscn"

const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")

var building_id := -1
var building_shop := ""
## Tipo (BuildingDefs) e nome próprio do prédio em que o jogador está.
var building_type := ""
var building_name := ""
## Largura da fachada do prédio (define o tamanho do interior).
var building_width := 240.0
var return_position := Vector2.ZERO
## Pista de crime (rumor de bar ou missão do briefing): {crime, crime_name, place, building_id,
## position}. Ao voltar para a rua, o crime acontece no lugar indicado e o HUD aponta o caminho.
var tip := {}
## Segundos restantes da revelação de criminosos comprada do informante.
var reveal_seconds := 0.0
## Seed do mundo e o layout dele (criado sob demanda, para os interiores consultarem a cidade).
var world_seed := 2024
var _world_layout
var has_return := false
## Opções de conforto: tremor de câmera (Fase 5).
var screen_shake := true

# Dados do jogador sobrevivem às trocas de cena (o nó Player é recriado a cada cena).
var _profiles := {}
var _inventories := {}


func is_inside() -> bool:
	return building_id >= 0


## Só altera o estado (testável sem trocar de cena).
func set_inside(id: int, p_return_position: Vector2, shop := "", type := "", p_name := "", p_width := 240.0) -> void:
	building_width = p_width
	building_id = id
	building_shop = shop
	building_type = type
	building_name = p_name
	return_position = p_return_position
	has_return = true
	for index in _profiles:
		_profiles[index].know_building(id)  # visitado: o ícone entra no mapa


func set_outside() -> void:
	building_id = -1
	building_shop = ""
	building_type = ""
	building_name = ""


## Posição onde o jogador deve reaparecer no mundo; consome o retorno pendente.
func consume_return_position() -> Vector2:
	has_return = false
	return return_position


func go_inside(id: int, p_return_position: Vector2, shop := "", type := "", p_name := "", p_width := 240.0) -> void:
	if Transition.busy:
		return
	# O estado só muda com a íris fechada (Transition roda o `before`).
	Transition.go(INTERIOR_SCENE, set_inside.bind(id, p_return_position, shop, type, p_name, p_width))


func go_outside() -> void:
	if Transition.busy:
		return
	Transition.go(MAIN_SCENE, set_outside)


## Volta ao menu de título (zera a partida).
func go_to_title() -> void:
	if Transition.busy:
		return
	Transition.go(TITLE_SCENE, func() -> void:
		set_outside()
		new_game())


## Começa uma partida nova: perfis, inventários, relógio e pontos zerados.
func new_game() -> void:
	reset_players()
	has_return = false
	WorldClock.reset()
	Score.reset()


## Do título para o jogo.
func start_game() -> void:
	if Transition.busy:
		return
	Transition.go(MAIN_SCENE, new_game)


func profile_for(player_index: int) -> RefCounted:
	if not _profiles.has(player_index):
		_profiles[player_index] = ProfileScript.new(player_index)
	return _profiles[player_index]


func inventory_for(player_index: int) -> RefCounted:
	if not _inventories.has(player_index):
		_inventories[player_index] = InventoryScript.starter_kit()
	return _inventories[player_index]


## Layout do mundo (o mesmo que a cena principal monta), criado na primeira consulta.
func world_layout() -> RefCounted:
	if _world_layout == null:
		_world_layout = (load("res://scripts/world/world_layout.gd") as GDScript).new(world_seed)
	return _world_layout


## Zera fichas, inventários, pista e revelação (novo jogo / testes).
func reset_players() -> void:
	_profiles.clear()
	_inventories.clear()
	tip = {}
	reveal_seconds = 0.0
