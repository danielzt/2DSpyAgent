extends RefCounted
## Layout lógico da região Campo: estrada de terra, fazendas, plantações e árvores.
## Determinístico por seed. Ocupa um retângulo à direita da cidade.

const SIZE := Vector2(6720, 6720)
const ROAD_WIDTH := 120.0
const ROAD_Y := 3360.0            # alinhada com uma rua da cidade (6 * BLOCK)
const FARM_COUNT := 7
const FARM_SIZE := Vector2(300, 220)
const FARM_ID_BASE := 1000        # ids distintos dos prédios da cidade
const FARM_SHOP_INDEX := 3        # esta fazenda é o armazém rural
const FIELD_COUNT := 8
const TREE_COUNT := 330
const TREE_TRUNK := 24.0
const DOOR_WIDTH := 56.0
const DOOR_DEPTH := 12.0
const EXIT_SPAWN_OFFSET := 40.0

var origin: Vector2
var road: Rect2
## Mesmo formato dos prédios da cidade.
var buildings: Array[Dictionary] = []
var fields: Array[Rect2] = []
var trees: Array[Vector2] = []


func _init(p_origin: Vector2 = Vector2.ZERO, p_seed: int = 2025) -> void:
	origin = p_origin
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	road = Rect2(origin.x, ROAD_Y - ROAD_WIDTH / 2.0, SIZE.x, ROAD_WIDTH)

	# Fazendas ao norte da estrada, com a porta voltada para ela.
	for k in FARM_COUNT:
		var x := origin.x + 400.0 + k * 880.0
		var rect := Rect2(x, road.position.y - 40.0 - FARM_SIZE.y, FARM_SIZE.x, FARM_SIZE.y)
		var door := Rect2(rect.get_center().x - DOOR_WIDTH / 2.0, rect.end.y, DOOR_WIDTH, DOOR_DEPTH)
		buildings.append({
			"id": FARM_ID_BASE + k,
			"rect": rect,
			"color": Color.from_hsv(rng.randf_range(0.0, 0.12), 0.5, rng.randf_range(0.5, 0.75)),
			"door": door,
			"exit_spawn": Vector2(door.get_center().x, door.end.y + EXIT_SPAWN_OFFSET),
			"shop": "farm_store" if k == FARM_SHOP_INDEX else "",
			"roof": [] as Array[Rect2],
		})

	# Plantações ao sul da estrada.
	var attempts := 0
	while fields.size() < FIELD_COUNT and attempts < 200:
		attempts += 1
		var size := Vector2(rng.randi_range(8, 14) * 50.0, rng.randi_range(6, 10) * 50.0)
		var pos := Vector2(
			rng.randf_range(origin.x + 100.0, origin.x + SIZE.x - 100.0 - size.x),
			rng.randf_range(ROAD_Y + 200.0, SIZE.y - 100.0 - size.y))
		var rect := Rect2(pos, size)
		var overlaps := false
		for other in fields:
			if rect.grow(40.0).intersects(other):
				overlaps = true
				break
		if not overlaps:
			fields.append(rect)

	# Árvores: longe da estrada, das fazendas e das plantações.
	attempts = 0
	while trees.size() < TREE_COUNT and attempts < 5000:
		attempts += 1
		var p := Vector2(
			rng.randf_range(origin.x + 60.0, origin.x + SIZE.x - 60.0),
			rng.randf_range(60.0, SIZE.y - 60.0))
		if _is_clear_for_tree(p):
			trees.append(p)


func _is_clear_for_tree(p: Vector2) -> bool:
	if road.grow(70.0).has_point(p):
		return false
	for b in buildings:
		if (b.rect as Rect2).grow(100.0).has_point(p):
			return false
	for f in fields:
		if f.grow(20.0).has_point(p):
			return false
	for t in trees:
		if t.distance_to(p) < 70.0:
			return false
	return true


func region_rect() -> Rect2:
	return Rect2(origin, SIZE)


## Carros estacionados na estrada de terra.
func vehicle_spawns() -> Array[Dictionary]:
	return [
		{"position": Vector2(origin.x + 700.0, ROAD_Y + 25.0), "rotation": 0.0},
		{"position": Vector2(origin.x + 3000.0, ROAD_Y - 25.0), "rotation": PI},
	]
