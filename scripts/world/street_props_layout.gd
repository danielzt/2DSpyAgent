extends RefCounted
## Layout lógico do mobiliário urbano e do paisagismo (sem nós): postes, semáforos,
## hidrantes, lixeiras, pontos de ônibus, bancas, árvores de calçada, bueiros, e o
## desenho dos parques e quintais. Determinístico por seed e por quarteirão.
##
## Regra: a calçada tem 30 px e os pedestres andam pelo meio dela, então tudo que fica
## na calçada é não sólido e fica na faixa junto ao meio-fio.

const CityLayout := preload("res://scripts/world/city_layout.gd")

## Distância do lote até a linha dos objetos junto ao meio-fio.
const CURB_LINE := 24.0
## Distância do lote até o centro da calçada (ponto de ônibus e banca ficam aqui).
const MID_LINE := 15.0
const SLOTS := [0.14, 0.32, 0.5, 0.68, 0.86]
const DOOR_CLEARANCE := 48.0
const LANE_OFFSET := 26.0
const PATH_WIDTH := 28.0

const TREE_CHANCE := 0.35
const BIN_CHANCE := 0.30
const HYDRANT_CHANCE := 0.30
const BUS_STOP_CHANCE := 0.12
const NEWSSTAND_CHANCE := 0.08
const MANHOLE_CHANCE := 0.5
const POND_CHANCE := 0.35

## Objetos desenhados acima dos personagens (o resto fica no chão).
const OVERLAY_KINDS := ["lamp", "traffic_light", "small_tree", "bus_stop", "newsstand"]

var world_seed: int
## Cada objeto: {kind:String, position:Vector2, layer:"ground"|"overlay", solid:bool, block:Vector2i}
## `position` é a base (objetos em pé) ou o centro (objetos deitados no chão).
var props: Array[Dictionary] = []
## Por índice do lote: {paths:Array[Rect2], pond:Rect2, has_pond:bool}
var parks := {}

var _by_block := {}


func _init(city: RefCounted, p_seed: int = 2024) -> void:
	world_seed = p_seed
	for index in city.lots.size():
		var lot: Rect2 = city.lots[index]
		var block := Vector2i(index / CityLayout.CELLS, index % CityLayout.CELLS)
		var rng := RandomNumberGenerator.new()
		rng.seed = p_seed * 1000003 + index * 7919 + 5
		_fill_sidewalks(city, lot, block, rng)
		if city.parks.has(lot):
			_fill_park(city, index, lot, block, rng)
	var yard_rng := RandomNumberGenerator.new()
	yard_rng.seed = p_seed * 31 + 77
	for yard in city.yards:
		_fill_yard(yard, yard_rng)


## Objetos do quarteirão (cx, cy).
func for_block(block: Vector2i) -> Array:
	return _by_block.get(block, [])


static func block_of(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(point.x / CityLayout.BLOCK)), 0, CityLayout.CELLS - 1),
		clampi(int(floor(point.y / CityLayout.BLOCK)), 0, CityLayout.CELLS - 1))


func _add(kind: String, position: Vector2, block: Vector2i) -> void:
	var prop := {
		"kind": kind,
		"position": Vector2(snappedf(position.x, 2.0), snappedf(position.y, 2.0)),
		"layer": "overlay" if OVERLAY_KINDS.has(kind) else "ground",
		"solid": false,
		"block": block,
	}
	props.append(prop)
	if not _by_block.has(block):
		_by_block[block] = []
	_by_block[block].append(prop)


## Centros das portas voltadas para a calçada de baixo do lote.
func _door_centers(city: RefCounted, lot: Rect2) -> Array[float]:
	var result: Array[float] = []
	for b in city.buildings:
		if lot.grow(0.5).encloses(b.rect):
			result.append((b.door as Rect2).get_center().x)
	return result


func _fill_sidewalks(city: RefCounted, lot: Rect2, block: Vector2i, rng: RandomNumberGenerator) -> void:
	var doors := _door_centers(city, lot)
	# Lados: 0 cima, 1 baixo, 2 esquerda, 3 direita. Cada lado tem vagas ao longo do meio-fio.
	var free := {}
	for side in 4:
		var slots: Array = SLOTS.duplicate()
		for i in range(slots.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: float = slots[i]
			slots[i] = slots[j]
			slots[j] = swap
		free[side] = slots

	for side in 4:
		_place(side, "lamp", lot, block, free, doors, CURB_LINE)
		if rng.randf() < TREE_CHANCE:
			_place(side, "small_tree", lot, block, free, doors, CURB_LINE)
		if rng.randf() < BIN_CHANCE:
			_place(side, "bin", lot, block, free, doors, CURB_LINE)
	if rng.randf() < HYDRANT_CHANCE:
		_place(rng.randi_range(0, 3), "hydrant", lot, block, free, doors, CURB_LINE)
	if rng.randf() < BUS_STOP_CHANCE:
		_place(rng.randi_range(0, 1), "bus_stop", lot, block, free, doors, MID_LINE)
	if rng.randf() < NEWSSTAND_CHANCE:
		_place(rng.randi_range(0, 1), "newsstand", lot, block, free, doors, MID_LINE)

	# Semáforos nos cantos que dão para um cruzamento interno.
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var node: Vector2i = block + corner
		if node.x < 1 or node.x > CityLayout.CELLS - 1 or node.y < 1 or node.y > CityLayout.CELLS - 1:
			continue
		var x := lot.position.x - CURB_LINE if corner.x == 0 else lot.end.x + CURB_LINE
		var y := lot.position.y - CURB_LINE if corner.y == 0 else lot.end.y + CURB_LINE
		_add("traffic_light", Vector2(x, y), block)

	# Bueiro na faixa da rua de cima.
	if rng.randf() < MANHOLE_CHANCE:
		_add("manhole", Vector2(
			lot.position.x + lot.size.x * rng.randf_range(0.15, 0.85),
			block.y * CityLayout.BLOCK + LANE_OFFSET * (1.0 if rng.randf() < 0.5 else -1.0)), block)


## Coloca um objeto na primeira vaga livre do lado; desiste se o lado estiver cheio.
func _place(side: int, kind: String, lot: Rect2, block: Vector2i, free: Dictionary, doors: Array[float], offset: float) -> void:
	var slots: Array = free[side]
	while not slots.is_empty():
		var u: float = slots.pop_back()
		var p: Vector2
		match side:
			0:
				p = Vector2(lot.position.x + lot.size.x * u, lot.position.y - offset)
			1:
				p = Vector2(lot.position.x + lot.size.x * u, lot.end.y + offset)
			2:
				p = Vector2(lot.position.x - offset, lot.position.y + lot.size.y * u)
			_:
				p = Vector2(lot.end.x + offset, lot.position.y + lot.size.y * u)
		if side == 1 and _near_door(p.x, doors):
			continue
		_add(kind, p, block)
		return


func _near_door(x: float, doors: Array[float]) -> bool:
	for d in doors:
		if absf(d - x) < DOOR_CLEARANCE:
			return true
	return false


func _fill_park(city: RefCounted, index: int, lot: Rect2, block: Vector2i, rng: RandomNumberGenerator) -> void:
	var center := lot.get_center()
	var paths: Array[Rect2] = [
		Rect2(center.x - PATH_WIDTH / 2.0, lot.position.y, PATH_WIDTH, lot.size.y),
		Rect2(lot.position.x, center.y - PATH_WIDTH / 2.0, lot.size.x, PATH_WIDTH),
	]
	var pond := Rect2()
	var has_pond := false
	if rng.randf() < POND_CHANCE:
		var size := Vector2(snappedf(rng.randf_range(96.0, 130.0), 4.0), snappedf(rng.randf_range(70.0, 100.0), 4.0))
		var quadrant := Vector2(rng.randi_range(0, 1), rng.randi_range(0, 1))
		var q_origin := lot.position + Vector2(18.0, 18.0) \
			+ quadrant * Vector2(lot.size.x / 2.0 + PATH_WIDTH / 2.0, lot.size.y / 2.0 + PATH_WIDTH / 2.0)
		var q_size := lot.size / 2.0 - Vector2(PATH_WIDTH / 2.0 + 36.0, PATH_WIDTH / 2.0 + 36.0)
		size = Vector2(minf(size.x, q_size.x), minf(size.y, q_size.y))
		var candidate := Rect2(q_origin + (q_size - size) / 2.0, size)
		candidate.position = Vector2(snappedf(candidate.position.x, 2.0), snappedf(candidate.position.y, 2.0))
		var clear := true
		for t in city.trees:
			if candidate.grow(40.0).has_point(t):
				clear = false
				break
		if clear:
			pond = candidate
			has_pond = true
	parks[index] = {"paths": paths, "pond": pond, "has_pond": has_pond}

	# Bancos ao lado do caminho, canteiros e arbustos.
	_add("bench", center + Vector2(-46.0, -30.0), block)
	_add("bench", center + Vector2(46.0, 30.0), block)
	for i in rng.randi_range(3, 5):
		var p := _free_park_point(lot, paths, pond, rng)
		if p != Vector2.INF:
			_add("flowers" if i % 2 == 0 else "bush", p, block)


func _free_park_point(lot: Rect2, paths: Array[Rect2], pond: Rect2, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 20:
		var p := Vector2(
			rng.randf_range(lot.position.x + 24.0, lot.end.x - 24.0),
			rng.randf_range(lot.position.y + 24.0, lot.end.y - 24.0))
		var ok := not pond.grow(14.0).has_point(p)
		for path in paths:
			if path.grow(12.0).has_point(p):
				ok = false
		if ok:
			return p
	return Vector2.INF


func _fill_yard(yard: Rect2, rng: RandomNumberGenerator) -> void:
	var block := block_of(yard.get_center())
	for i in rng.randi_range(2, 4):
		_add("bush" if i % 2 == 0 else "flowers", Vector2(
			rng.randf_range(yard.position.x + 16.0, yard.end.x - 16.0),
			rng.randf_range(yard.position.y + 16.0, yard.end.y - 16.0)), block)
