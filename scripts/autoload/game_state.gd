extends Node
## Estado global de navegação entre o mundo externo e os interiores.

const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
const INTERIOR_SCENE := "res://scenes/interior/interior.tscn"
## Grupos da cena do mundo externo (main.gd) e da cena de interior (interior.gd).
const WORLD_GROUP := "outside_world"
const INTERIOR_GROUP := "interiors"

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
## Mundo externo guardado (fora da árvore) enquanto o jogador está num interior: ao sair,
## a mesma cena volta, com carros, bandidos, NPCs e itens onde estavam.
var parked_world: Node = null
## Pai e posição do mundo na árvore antes de ser guardado (para voltar ao mesmo lugar).
var _parked_parent: Node = null
var _parked_was_current := false

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
		_profiles[index].explore(p_return_position)


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
	Transition.run(func() -> void: _enter_building.call_deferred(),
		set_inside.bind(id, p_return_position, shop, type, p_name, p_width))


func go_outside() -> void:
	if Transition.busy:
		return
	Transition.run(func() -> void: _leave_building.call_deferred(), set_outside)


## Guarda o mundo externo (sem destruí-lo) e monta o interior no lugar dele.
## Sem mundo em cena (ex.: interior dentro de interior), troca de cena como antes.
func _enter_building() -> void:
	var tree := get_tree()
	var world := tree.get_first_node_in_group(WORLD_GROUP)
	if world == null:
		tree.change_scene_to_file(INTERIOR_SCENE)
		return
	discard_parked_world()
	park_world(world)
	var interior: Node = (load(INTERIOR_SCENE) as PackedScene).instantiate()
	_parked_parent.add_child(interior)
	if _parked_was_current:
		tree.current_scene = interior


## Desfaz o interior e devolve o mundo guardado; sem mundo guardado, carrega um novo.
func _leave_building() -> void:
	var tree := get_tree()
	var was_current := false
	for interior in tree.get_nodes_in_group(INTERIOR_GROUP):
		was_current = was_current or interior == tree.current_scene
		interior.get_parent().remove_child(interior)   # sai da árvore já (o jogador salva a vida)
		interior.queue_free()
	if not is_instance_valid(parked_world):
		parked_world = null
		tree.change_scene_to_file(MAIN_SCENE)
		return
	var world := parked_world
	var parent: Node = _parked_parent if is_instance_valid(_parked_parent) else tree.root
	parked_world = null
	_parked_parent = null
	parent.add_child(world)
	if _parked_was_current or was_current:
		tree.current_scene = world
	if world.has_method("resume_from_interior"):
		world.resume_from_interior()


## Tira o mundo da árvore sem liberá-lo: fora da árvore nada nele processa (fica congelado).
func park_world(world: Node) -> void:
	var tree := get_tree()
	_parked_parent = world.get_parent()
	_parked_was_current = world == tree.current_scene
	_parked_parent.remove_child(world)
	parked_world = world


## Libera o mundo guardado (novo jogo, volta ao título).
func discard_parked_world() -> void:
	if is_instance_valid(parked_world):
		parked_world.free()
	parked_world = null
	_parked_parent = null
	_parked_was_current = false


## Volta ao menu de título (zera a partida).
func go_to_title() -> void:
	if Transition.busy:
		return
	Transition.go(TITLE_SCENE, func() -> void:
		set_outside()
		new_game())


func _exit_tree() -> void:
	discard_parked_world()


## Começa uma partida nova: perfis, inventários, relógio e pontos zerados.
func new_game() -> void:
	discard_parked_world()
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
