extends Node
## Gera crimes em andamento conforme a região onde o jogador está (CrimeProfiles) e
## paga um bônus quando todos os criminosos do crime são mortos ou atordoados.

const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")

signal incident_started(incident: Dictionary)
signal incident_resolved(incident: Dictionary)

const MAX_ACTIVE := 2
const FIRST_DELAY := 12.0
const MIN_DISTANCE := 500.0
const MAX_DISTANCE := 900.0
## Até onde procurar um prédio compatível com o crime (em frente ao qual ele acontece).
const MAX_PLACE_DISTANCE := 1500.0
const MONEY_REWARD_SHARE := 0.5   # fração da recompensa paga também em dinheiro
const SPREAD := 45.0              # espalhamento dos criminosos em volta do ponto do crime

var layout                        # WorldLayout
var enabled := true
var rng := RandomNumberGenerator.new()
## Cada crime: {type:Dictionary, region:String, center:Vector2, criminals:Array, id:int, place:String}
var incidents: Array[Dictionary] = []

var _timer := FIRST_DELAY
var _next_id := 1


func _ready() -> void:
	if rng.seed == 0:
		rng.randomize()


func _process(delta: float) -> void:
	if layout == null or not enabled:
		return
	_check_resolved()
	_timer -= delta
	if _timer <= 0.0:
		try_spawn()
		_timer = _next_interval()


func active_count() -> int:
	return incidents.size()


## Tenta criar um crime perto de um jogador, na região dele. Retorna true se criou.
func try_spawn() -> bool:
	if layout == null or incidents.size() >= MAX_ACTIVE:
		return false
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return false
	var player: Node2D = players[rng.randi_range(0, players.size() - 1)]
	var region: String = layout.region_at(player.global_position)
	if not CrimeProfiles.has_region(region):
		return false
	# O tipo depende do bairro; o lugar, de um prédio compatível com o tipo.
	var type: Dictionary = CrimeProfiles.pick(region, rng, layout.district_id_at(player.global_position))
	if type.is_empty():
		return false
	var place: Dictionary = pick_place(type, player.global_position)
	if not place.is_empty():
		spawn_incident(region, place.exit_spawn, type, place.name)
		return true
	var point: Vector2 = layout.free_point_near(player.global_position, MIN_DISTANCE, MAX_DISTANCE, rng, layout.region_rect(region))
	if point == Vector2.INF:
		return false
	spawn_incident(region, point, type)
	return true


## Prédio em frente ao qual o crime acontece: um dos tipos `near` do crime, nem perto
## demais nem longe demais do jogador. {} se o crime não pede prédio ou não há nenhum.
func pick_place(type: Dictionary, from: Vector2) -> Dictionary:
	var near: Array = CrimeProfiles.near_of(type)
	if near.is_empty():
		return {}
	var options: Array = layout.buildings_of(near, from, MIN_DISTANCE, MAX_PLACE_DISTANCE)
	if options.is_empty():
		return {}
	return options[rng.randi_range(0, options.size() - 1)]


## Cria o crime: sorteia o tipo pela região (ou usa `type`) e coloca os criminosos em volta de `center`.
## `place`: nome do prédio em frente ao qual o crime acontece (aparece no aviso).
func spawn_incident(region: String, center: Vector2, type := {}, place := "") -> Dictionary:
	if type.is_empty():
		type = CrimeProfiles.pick(region, rng)
	if type.is_empty():
		return {}
	var criminals: Array = []
	for i in type.criminals:
		var npc := NPC_SCENE.instantiate()
		npc.kind = "criminal"
		npc.crime = type.id
		npc.ai_seed = rng.randi_range(1, 1000000)
		npc.position = center + Vector2.RIGHT.rotated(TAU * i / maxi(type.criminals, 1)) * (SPREAD if type.criminals > 1 else 0.0)
		get_parent().add_child(npc)
		criminals.append(npc)
	var incident := {"type": type, "region": region, "center": center, "criminals": criminals, "id": _next_id, "place": place}
	_next_id += 1
	incidents.append(incident)
	for p in get_tree().get_nodes_in_group("players"):
		if p.has_method("notify"):
			p.notify(CrimeProfiles.alert_text(type, p.global_position, center, place), 8.0)
	incident_started.emit(incident)
	return incident


func _check_resolved() -> void:
	for incident in incidents.duplicate():
		if _is_resolved(incident):
			incidents.erase(incident)
			var reward: int = incident.type.reward
			Score.register_incident(reward)
			for p in get_tree().get_nodes_in_group("players"):
				p.profile.add_money(roundi(reward * MONEY_REWARD_SHARE))
				p.notify("Crime resolvido: %s (+%d pontos)" % [incident.type.name, reward], 6.0)
			incident_resolved.emit(incident)


func _is_resolved(incident: Dictionary) -> bool:
	for c in incident.criminals:
		if is_instance_valid(c) and not c.dead and not c.stunned:
			return false
	return true


func _next_interval() -> float:
	var players := get_tree().get_nodes_in_group("players")
	var region := ""
	if not players.is_empty() and layout != null:
		region = layout.region_at((players[0] as Node2D).global_position)
	return CrimeProfiles.interval_for(region) * rng.randf_range(0.8, 1.2)
