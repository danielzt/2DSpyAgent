extends Node
## Estado global de navegação entre o mundo externo e os interiores.

const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
const INTERIOR_SCENE := "res://scenes/interior/interior.tscn"

const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const SaveGame := preload("res://scripts/save/save_game.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")

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


## Autosave: só liga quando uma partida de verdade começa (título -> jogo); testes não gravam.
var autosave := false


func is_inside() -> bool:
	return building_id >= 0


## Grava o save. `position`: onde o jogador está no mundo (dentro de prédio vale a porta).
func save_now(position := Vector2.ZERO) -> bool:
	var spot := return_position if is_inside() or position == Vector2.ZERO else position
	var players := {}
	for index in _profiles:
		players[index] = {"profile": _profiles[index], "inventory": inventory_for(index)}
	return SaveGame.write(SaveGame.snapshot(world_seed, players, WorldClock.seconds, Score.points, spot))


## Grava só se o autosave estiver ligado.
func autosave_now(position := Vector2.ZERO) -> void:
	if autosave:
		save_now(position)


## Carrega o save para a memória (sem trocar de cena). Retorna false se não houver save válido.
func load_save() -> bool:
	var data: Dictionary = SaveGame.read()
	if data.is_empty():
		return false
	new_game()
	world_seed = int(data.get("seed", world_seed))
	_world_layout = null
	CityLayout.use_seed(world_seed)
	for key in data.get("players", {}):
		var index := int(key)
		var entry: Dictionary = data.players[key]
		profile_for(index).from_dict(entry.get("profile", {}))
		inventory_for(index).from_dict(entry.get("inventory", {}))
	WorldClock.seconds = float(data.get("clock", WorldClock.seconds))
	Score.points = int(data.get("points", 0))
	return_position = SaveGame.vec(data.get("position"))
	has_return = return_position != Vector2.ZERO
	return true


## Do título: continua a partida salva.
func continue_game() -> void:
	if Transition.busy or not SaveGame.exists():
		return
	Transition.go(MAIN_SCENE, func() -> void:
		if load_save():
			autosave = true
		else:
			new_game())


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
		_profiles[index].explore(p_return_position)
	autosave_now()


func set_outside() -> void:
	building_id = -1
	building_shop = ""
	building_type = ""
	building_name = ""
	autosave_now()


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
		autosave = false
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
	Transition.go(MAIN_SCENE, func() -> void:
		new_game()
		autosave = true)


func profile_for(player_index: int) -> RefCounted:
	if not _profiles.has(player_index):
		var profile: RefCounted = ProfileScript.new(player_index)
		_profiles[player_index] = profile
		_welcome_home(profile)
	return _profiles[player_index]


## A ficha nova já conhece a casa do agente e a traz marcada no mapa e no HUD.
func _welcome_home(profile: RefCounted) -> void:
	var home: Dictionary = world_layout().home()
	if home.is_empty():
		return
	profile.know_building(home.id)
	profile.explore(home.exit_spawn)
	profile.add_waypoint(home.exit_spawn, "Casa")


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
