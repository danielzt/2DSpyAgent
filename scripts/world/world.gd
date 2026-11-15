extends Node2D
## Mundo externo: monta nós (chão, prédios, portas, árvores, carros, NPCs, itens, paredes)
## a partir do WorldLayout. O visual vem da fábrica de arte (scripts/art).

const WorldLayout := preload("res://scripts/world/world_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")
const StreetPropsLayout := preload("res://scripts/world/street_props_layout.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const GroundChunkScript := preload("res://scripts/world/ground_chunk.gd")
const PickupScript := preload("res://scripts/items/pickup.gd")
const IncidentManagerScript := preload("res://scripts/crime/incident_manager.gd")
const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const LightLayerScript := preload("res://scripts/world/light_layer.gd")
const TireMarksScript := preload("res://scripts/effects/tire_marks.gd")
const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const BuildingArt := preload("res://scripts/art/building_art.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const DOOR_SCRIPT := preload("res://scripts/world/door.gd")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")

const TEXEL := 2.0
const BUILDING_Z := 2
const FARM_YARD_MARGIN := 24.0
const TRACK_OFFSET := 18.0
## Segundos entre o jogador chegar à rua e o crime da pista começar.
const TIP_DELAY := 4.0
## Criminosos revelados pelo informante: até onde e quantos.
const REVEAL_RANGE := 1800.0
const REVEAL_MAX := 4
## População conforme a hora: de quanto em quanto tempo conferir, e a que distância dos
## jogadores alguém pode aparecer ou sumir sem ser visto.
const POPULATION_CHECK := 2.0
const OFFSCREEN_DISTANCE := 1000.0
## Mapa: de quanto em quanto tempo conferir os prédios por perto, e a que distância da parede
## o jogador "vê" o prédio (ele ganha ícone no mapa).
const SEEN_CHECK := 0.5
const SEEN_RADIUS := 380.0

var layout
var props
var incidents

## Tinta do ambiente (cor da hora) e camada de luz.
var ambient: CanvasModulate
var lights
## Marcas de pneu deixadas pelo carro do jogador (Fase 5).
var tire_marks: Node2D

var _tip_timer := TIP_DELAY
var _tip_incident_id := -1
var _traffic_spawns: Array[Dictionary] = []
var _home_doors := PackedVector2Array()
## índice -> nó (pedestres de calçada e carros de trânsito em cena)
var _npc_nodes := {}
var _traffic_nodes := {}
## índices mandados para casa por causa da hora (voltam de manhã)
var _dismissed_npcs := {}
var _dismissed_traffic := {}
var _population_timer := POPULATION_CHECK
var _seen_timer := 0.0

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layout = WorldLayout.new()
	props = StreetPropsLayout.new(layout.city, layout.city.world_seed)
	_add_ground_chunks()
	for b in layout.buildings():
		_add_building(b)
	for p in layout.country.trees:
		_add_tree_trunk(p)
	for p in layout.city.trees:
		_add_tree_trunk(p)
	for spawn in layout.vehicle_spawns():
		var car := CAR_SCENE.instantiate()
		car.model = "agent"   # carros da agência: os únicos que o jogador dirige
		car.tone = GameState.profile_for(1).car_paint   # pintura escolhida na oficina
		car.position = spawn.position
		car.rotation = spawn.rotation
		add_child(car)
	# Trânsito e pedestres dependem da hora: de noite há menos carros e menos gente na rua.
	_traffic_spawns = layout.traffic_spawns()
	for doors in layout.buildings():
		if BuildingDefs.is_home(doors.get("type", "")):
			_home_doors.append(doors.exit_spawn)
	var hour: float = WorldClock.hour()
	for index in _traffic_spawns.size():
		if index < DayCycle.traffic_cars(hour):
			_spawn_traffic(index)
		else:
			_dismissed_traffic[index] = true
	var pedestrians := 0
	for index in layout.npcs.size():
		if layout.npcs[index].mode == "sidewalk":
			pedestrians += 1
			if pedestrians > DayCycle.city_pedestrians(hour):
				_dismissed_npcs[index] = true
				continue
		_spawn_npc(index)
	for p in layout.pickups:
		PickupScript.spawn(self, p.position, p.item, p.amount)
	var s := WorldLayout.world_size()
	_add_wall(Rect2(-40, -40, s.x + 80, 40))
	_add_wall(Rect2(-40, s.y, s.x + 80, 40))
	_add_wall(Rect2(-40, 0, 40, s.y))
	_add_wall(Rect2(s.x, 0, 40, s.y))

	tire_marks = Node2D.new()
	tire_marks.set_script(TireMarksScript)
	tire_marks.name = "TireMarks"
	add_child(tire_marks)

	incidents = IncidentManagerScript.new()
	incidents.layout = layout
	incidents.incident_resolved.connect(_on_incident_resolved)
	add_child(incidents)

	# Dia e noite: a cor ambiente tinge o mundo; as luzes ficam em uma camada à parte.
	ambient = CanvasModulate.new()
	ambient.name = "Ambient"
	ambient.color = WorldClock.ambient_color()
	add_child(ambient)
	lights = CanvasLayer.new()
	lights.set_script(LightLayerScript)
	lights.name = "Lights"
	lights.setup(layout, props)
	add_child(lights)
	queue_redraw()


func _spawn_traffic(index: int) -> void:
	var t: Dictionary = _traffic_spawns[index]
	var car := CAR_SCENE.instantiate()
	var variant := CarSprites.variant_for(index)
	car.ai_controlled = true
	car.ai_seed = 100 + index
	car.model = variant.model
	car.tone = variant.tone
	car.position = t.position
	car.rotation = t.rotation
	car.ai_lane = t.lane
	car.start_route(t.node, t.dir)
	add_child(car)
	_traffic_nodes[index] = car
	_dismissed_traffic.erase(index)


func _spawn_npc(index: int) -> void:
	var n: Dictionary = layout.npcs[index]
	var npc := NPC_SCENE.instantiate()
	npc.kind = n.kind
	npc.crime = n.crime
	npc.ai_seed = n.seed
	npc.context = n.context
	npc.position = n.position
	if n.mode == "sidewalk":
		npc.start_on_sidewalk(n.from, n.to)
		_npc_nodes[index] = npc
	add_child(npc)
	_dismissed_npcs.erase(index)


# --- população conforme a hora ---

## Pedestres de calçada em cena que não estão indo para casa.
func active_pedestrians() -> int:
	var count := 0
	for index in _npc_nodes:
		var npc: Node = _npc_nodes[index]
		if is_instance_valid(npc) and not npc.dead and not npc.going_home:
			count += 1
	return count


func active_traffic() -> int:
	var count := 0
	for index in _traffic_nodes:
		if is_instance_valid(_traffic_nodes[index]):
			count += 1
	return count


func _far_from_players(point: Vector2) -> bool:
	for p in get_tree().get_nodes_in_group("players"):
		if (p.global_position as Vector2).distance_to(point) < OFFSCREEN_DISTANCE:
			return false
	return true


## Ajusta pedestres e trânsito à hora: de noite o excesso vai para casa (pedestres somem em
## uma porta de moradia; carros saem de cena longe da vista); de manhã voltam, também longe
## da vista. Quem morreu não volta.
func sync_population() -> void:
	var hour: float = WorldClock.hour()
	for index in _npc_nodes.keys():
		if not is_instance_valid(_npc_nodes[index]):
			_npc_nodes.erase(index)
	var surplus := active_pedestrians() - DayCycle.city_pedestrians(hour)
	if surplus > 0:
		var indexes := _npc_nodes.keys()
		indexes.sort()
		indexes.reverse()
		for index in indexes:
			if surplus <= 0:
				break
			var npc: Node = _npc_nodes[index]
			if not npc.going_home and not npc.dead:
				npc.go_home(_home_doors)
				_dismissed_npcs[index] = true
				surplus -= 1
	elif surplus < 0:
		var back := _dismissed_npcs.keys()
		back.sort()
		for index in back:
			if surplus >= 0:
				break
			if _npc_nodes.has(index) or not _far_from_players(layout.npcs[index].position):
				continue
			_spawn_npc(index)
			surplus += 1

	for index in _traffic_nodes.keys():
		if not is_instance_valid(_traffic_nodes[index]):
			_traffic_nodes.erase(index)
	var wanted := DayCycle.traffic_cars(hour)
	for index in _traffic_spawns.size():
		var present: bool = _traffic_nodes.has(index)
		if index >= wanted and present:
			var car: Node2D = _traffic_nodes[index]
			if _far_from_players(car.global_position):
				car.queue_free()
				_traffic_nodes.erase(index)
				_dismissed_traffic[index] = true
		elif index < wanted and not present and _dismissed_traffic.has(index):
			if _far_from_players(_traffic_spawns[index].position):
				_spawn_traffic(index)


func _process(delta: float) -> void:
	var tint: Color = WorldClock.ambient_color()
	if ambient.color != tint:
		ambient.color = tint
	_population_timer -= delta
	if _population_timer <= 0.0:
		_population_timer = POPULATION_CHECK
		sync_population()
	_seen_timer -= delta
	if _seen_timer <= 0.0:
		_seen_timer = SEEN_CHECK
		mark_seen_buildings()
	_update_tip(delta)
	var targets := current_targets()
	for p in get_tree().get_nodes_in_group("players"):
		p.region_name = layout.region_at(p.global_position)
		p.place_name = layout.place_text(p.global_position)
		p.targets = targets
		if not p.died.is_connected(_on_player_died):
			p.died.connect(_on_player_died.bind(p))


## Os prédios a até SEEN_RADIUS de um jogador entram no mapa dele. Retorna quantos eram novos.
func mark_seen_buildings() -> int:
	var added := 0
	for p in get_tree().get_nodes_in_group("players"):
		var known: Dictionary = p.profile.known_buildings
		for b in layout.buildings():
			if known.has(b.id):
				continue
			if (b.rect as Rect2).grow(SEEN_RADIUS).has_point(p.global_position):
				known[b.id] = true
				added += 1
	return added


# --- derrota, pistas e alvos ---

## Derrota: o agente acorda em frente ao hospital (e já perdeu parte do dinheiro em mãos).
func _on_player_died(player: Node) -> void:
	var hospital: Dictionary = layout.nearest_building_of(["hospital"], player.global_position)
	if not hospital.is_empty():
		player.global_position = hospital.exit_spawn
		player.notify("Você acordou no %s. Perdeu $%d." % [hospital.name, player.last_defeat_loss], 7.0)


## A pista (rumor de bar ou missão do briefing) vira um crime de verdade no lugar indicado,
## pouco depois de o jogador chegar à rua. Ela só some quando o crime é resolvido.
func _update_tip(delta: float) -> void:
	if GameState.reveal_seconds > 0.0:
		GameState.reveal_seconds = maxf(GameState.reveal_seconds - delta, 0.0)
	var tip: Dictionary = GameState.tip
	if tip.is_empty() or _tip_incident_id >= 0 or incidents == null:
		return
	if get_tree().get_nodes_in_group("players").is_empty():
		return
	_tip_timer -= delta
	if _tip_timer > 0.0:
		return
	var type: Dictionary = CrimeProfiles.find_type(tip.get("crime", ""))
	if type.is_empty():
		GameState.tip = {}
		return
	var incident: Dictionary = incidents.spawn_incident(tip.get("region", "Cidade"), tip.position, type, tip.get("place", ""))
	_tip_incident_id = incident.get("id", -1)


func _on_incident_resolved(incident: Dictionary) -> void:
	if incident.get("id", -2) == _tip_incident_id:
		_tip_incident_id = -1
		_tip_timer = TIP_DELAY
		GameState.tip = {}


## Posições que as setas do HUD apontam: o lugar da pista e, enquanto durar a revelação do
## informante, os criminosos por perto.
func current_targets() -> Array:
	var targets: Array = []
	var tip: Dictionary = GameState.tip
	if not tip.is_empty():
		targets.append(tip.position)
	if GameState.reveal_seconds > 0.0:
		var players := get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			var from: Vector2 = (players[0] as Node2D).global_position
			var found: Array = []
			for npc in get_tree().get_nodes_in_group("npcs"):
				if npc.kind == "criminal" and not npc.dead and (npc.global_position as Vector2).distance_to(from) <= REVEAL_RANGE:
					found.append(npc.global_position)
			found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(from) < b.distance_squared_to(from))
			targets.append_array(found.slice(0, REVEAL_MAX))
	return targets


## Base do mundo: asfalto sob a cidade e grama sob o campo (dois retângulos de tile
## repetido), mais a estrada, as plantações e os terreiros das fazendas.
func _draw() -> void:
	if layout == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	var cs := CityLayout.city_size()
	var s := WorldLayout.world_size()
	_tile("asphalt", Rect2(0, 0, cs, cs))
	_tile("grass", Rect2(cs, 0, s.x - cs, s.y))

	var country = layout.country
	var index := 0
	for f in country.fields:
		var field: Rect2 = f
		_tile("field" if index % 2 == 0 else "field_green", field)
		_fence(field)
		index += 1
	for b in country.buildings:
		_tile("dirt", (b.rect as Rect2).grow(FARM_YARD_MARGIN))
		var door: Rect2 = b.door
		_tile("dirt", Rect2(door.position.x, door.end.y, door.size.x, country.road.position.y - door.end.y))
	var road: Rect2 = country.road
	_tile("dirt", road)
	var edge := Palette.get_color("brown")
	draw_rect(_t(Rect2(road.position.x, road.position.y, road.size.x, TEXEL)), edge)
	draw_rect(_t(Rect2(road.position.x, road.end.y - TEXEL, road.size.x, TEXEL)), edge)
	for offset in [-TRACK_OFFSET, TRACK_OFFSET]:
		draw_rect(_t(Rect2(road.position.x, road.get_center().y + offset - TEXEL, road.size.x, TEXEL * 2.0)), edge)


static func _t(rect: Rect2) -> Rect2:
	return Rect2(rect.position / TEXEL, rect.size / TEXEL)


func _tile(id: String, rect: Rect2) -> void:
	draw_texture_rect(SpriteFactory.tile(id), _t(rect), true)


## Cerca em volta de um retângulo (mourões e ripas).
func _fence(rect: Rect2) -> void:
	var h := SpriteFactory.prop("fence_h")
	var v := SpriteFactory.prop("fence_v")
	var r := _t(rect.grow(6.0))
	draw_texture_rect(h, Rect2(r.position.x, r.position.y - 2.0, r.size.x, h.get_height()), true)
	draw_texture_rect(h, Rect2(r.position.x, r.end.y - 2.0, r.size.x, h.get_height()), true)
	draw_texture_rect(v, Rect2(r.position.x, r.position.y, v.get_width(), r.size.y), true)
	draw_texture_rect(v, Rect2(r.end.x - 2.0, r.position.y, v.get_width(), r.size.y), true)


## Um nó de chão por pedaço de 560x560 px, na cidade e no campo.
func _add_ground_chunks() -> void:
	var block := CityLayout.BLOCK
	var trees_by_chunk := {}
	for p in layout.city.trees + layout.country.trees:
		var key := Vector2i(int(floor(p.x / block)), int(floor(p.y / block)))
		if not trees_by_chunk.has(key):
			trees_by_chunk[key] = []
		trees_by_chunk[key].append(p)
	var s := WorldLayout.world_size()
	for cx in int(ceil(s.x / block)):
		for cy in int(ceil(s.y / block)):
			var chunk := Node2D.new()
			chunk.set_script(GroundChunkScript)
			chunk.chunk = Vector2i(cx, cy)
			chunk.world_layout = layout
			chunk.props_layout = props
			chunk.lot_index = cx * CityLayout.CELLS + cy if cx < CityLayout.CELLS and cy < CityLayout.CELLS else -1
			chunk.trees = trees_by_chunk.get(Vector2i(cx, cy), [])
			chunk.add_to_group("ground_chunks")
			add_child(chunk)


func _add_tree_trunk(p: Vector2) -> void:
	add_child(_make_solid(Rect2(p - Vector2.ONE * CountryLayout.TREE_TRUNK / 2.0, Vector2.ONE * CountryLayout.TREE_TRUNK)))


func _add_building(b: Dictionary) -> void:
	var rect: Rect2 = b.rect
	var body := _make_solid(rect)
	body.z_index = BUILDING_Z
	var style := BuildingStyle.for_building(b)
	var texture := SpriteFactory.custom(BuildingStyle.cache_key(b, style),
		func() -> RefCounted: return BuildingArt.render(b, style))
	var visual := SpriteFactory.make_sprite(texture, rect.size / (2.0 * TEXEL))
	visual.name = "Visual"
	body.add_child(visual)
	body.add_to_group("buildings")
	add_child(body)

	var door_rect: Rect2 = b.door
	var door := Area2D.new()
	door.set_script(DOOR_SCRIPT)
	door.building_id = b.id
	door.return_position = b.exit_spawn
	door.shop = b.shop
	door.building_type = b.get("type", "")
	door.building_name = b.get("name", "")
	door.facade_width = rect.size.x
	door.position = door_rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = door_rect.size
	shape.shape = rs
	door.add_child(shape)
	door.add_to_group("building_doors")
	add_child(door)


func _add_wall(rect: Rect2) -> void:
	add_child(_make_solid(rect))


func _make_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.add_child(shape)
	return body
