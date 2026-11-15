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

var layout
var props
var incidents


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
		car.position = spawn.position
		car.rotation = spawn.rotation
		add_child(car)
	var traffic_index := 0
	for t in layout.traffic_spawns():
		var car := CAR_SCENE.instantiate()
		var variant := CarSprites.variant_for(traffic_index)
		car.ai_controlled = true
		car.ai_seed = 100 + traffic_index
		car.model = variant.model
		car.tone = variant.tone
		car.position = t.position
		car.rotation = t.rotation
		car.start_route(t.node, t.dir)
		add_child(car)
		traffic_index += 1
	var npc_index := 0
	for n in layout.npcs:
		var npc := NPC_SCENE.instantiate()
		npc.kind = n.kind
		npc.crime = n.crime
		npc.ai_seed = 1000 + npc_index
		npc.position = n.position
		if n.mode == "sidewalk":
			npc.start_on_sidewalk(n.from, n.to)
		add_child(npc)
		npc_index += 1
	for p in layout.pickups:
		PickupScript.spawn(self, p.position, p.item, p.amount)
	var s := WorldLayout.world_size()
	_add_wall(Rect2(-40, -40, s.x + 80, 40))
	_add_wall(Rect2(-40, s.y, s.x + 80, 40))
	_add_wall(Rect2(-40, 0, 40, s.y))
	_add_wall(Rect2(s.x, 0, 40, s.y))

	incidents = IncidentManagerScript.new()
	incidents.layout = layout
	add_child(incidents)
	queue_redraw()


func _process(_delta: float) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		p.region_name = layout.region_at(p.global_position)


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
