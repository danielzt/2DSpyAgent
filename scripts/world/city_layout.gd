extends RefCounted
## Layout lógico da região Cidade (sem nós): ruas com calçadas, lotes com prédios de
## formas variadas, parques e lojas. Determinístico por seed.
## A cidade ocupa o canto (0, 0) do mundo; as ruas são centradas em múltiplos de BLOCK.

const CELLS := 12            # quarteirões por lado
const BLOCK := 560.0         # distância entre ruas (px)
const ROAD := 200.0          # corredor da rua: asfalto + duas calçadas
const ASPHALT := 140.0       # largura do asfalto
const SIDEWALK := 30.0       # largura de cada calçada
const LOT := BLOCK - ROAD    # lado de cada lote (360)
const DOOR_WIDTH := 56.0
const DOOR_DEPTH := 12.0
const EXIT_SPAWN_OFFSET := 40.0  # distância abaixo da porta onde o jogador reaparece
const MIN_BUILDING := 120.0
const PARK_OFFSET := 54.0        # carros estacionados ficam rente ao meio-fio

## Lojas sorteadas entre os prédios: [tipo, quantidade]
const SHOP_PLAN := [["armory", 2], ["pharmacy", 3], ["agent_store", 2]]

var world_seed: int
## Cada prédio: {id:int, rect:Rect2, color:Color, door:Rect2, exit_spawn:Vector2, shop:String, roof:Array[Rect2]}
var buildings: Array[Dictionary] = []
var lots: Array[Rect2] = []
var parks: Array[Rect2] = []
## Árvores de parques e quintais (troncos sólidos).
var trees: Array[Vector2] = []
## Quintais (área gramada ao lado de um prédio que não ocupa o lote todo).
var yards: Array[Rect2] = []


func _init(p_seed: int = 2024) -> void:
	world_seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for cx in CELLS:
		for cy in CELLS:
			var lot := Rect2(cx * BLOCK + ROAD / 2.0, cy * BLOCK + ROAD / 2.0, LOT, LOT)
			lots.append(lot)
			_fill_lot(lot, rng)
	_assign_shops(rng)


## Lado da região (a cidade é quadrada), em px.
static func city_size() -> float:
	return CELLS * BLOCK


## Ponto de início: cruzamento de ruas dentro do mapa.
static func spawn_point() -> Vector2:
	return Vector2(BLOCK, BLOCK)


## Posições de carros estacionados rente ao meio-fio, no meio de trechos de rua, apontando para baixo.
static func vehicle_spawns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in [Vector2i(1, 0), Vector2i(3, 2), Vector2i(5, 1), Vector2i(2, 4), Vector2i(6, 5), Vector2i(4, 3)]:
		result.append({"position": Vector2(cell.x * BLOCK + PARK_OFFSET, cell.y * BLOCK + BLOCK / 2.0), "rotation": PI / 2.0})
	return result


## Retorna o id do prédio que contém o ponto, ou -1.
func building_at(point: Vector2) -> int:
	for b in buildings:
		if (b.rect as Rect2).has_point(point):
			return b.id
	return -1


func building_by_id(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


func _fill_lot(lot: Rect2, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.10:
		_make_park(lot, rng)
	elif roll < 0.38:
		var left := rng.randf_range(0.0, 60.0)
		var right := rng.randf_range(0.0, 60.0)
		var top := rng.randf_range(0.0, 60.0)
		var bottom := rng.randf_range(0.0, 30.0)
		_add_building(Rect2(lot.position.x + left, lot.position.y + top, LOT - left - right, LOT - top - bottom), rng)
	elif roll < 0.72:
		var ratio := rng.randf_range(0.42, 0.58)
		var gap := rng.randf_range(24.0, 48.0)
		var usable := LOT - gap
		var width_a := usable * ratio
		var width_b := usable - width_a
		for side in 2:
			var top := rng.randf_range(0.0, 60.0)
			var bottom := rng.randf_range(0.0, 30.0)
			var x := lot.position.x if side == 0 else lot.position.x + width_a + gap
			var w := width_a if side == 0 else width_b
			_add_building(Rect2(x, lot.position.y + top, w, LOT - top - bottom), rng)
	else:
		var w := rng.randf_range(0.5, 0.8) * LOT
		var on_left := rng.randf() < 0.5
		var top := rng.randf_range(0.0, 40.0)
		var bottom := rng.randf_range(0.0, 30.0)
		var x := lot.position.x if on_left else lot.end.x - w
		_add_building(Rect2(x, lot.position.y + top, w, LOT - top - bottom), rng)
		# Quintal ao lado: algumas árvores.
		var yard := Rect2(lot.position.x + (w if on_left else 0.0), lot.position.y, LOT - w, LOT)
		if yard.size.x > 90.0:
			yards.append(yard)
			for i in rng.randi_range(1, 2):
				trees.append(Vector2(
					rng.randf_range(yard.position.x + 35.0, yard.end.x - 35.0),
					rng.randf_range(yard.position.y + 35.0, yard.end.y - 35.0)))


func _make_park(lot: Rect2, rng: RandomNumberGenerator) -> void:
	parks.append(lot)
	var placed: Array[Vector2] = []
	var attempts := 0
	var wanted := rng.randi_range(4, 7)
	while placed.size() < wanted and attempts < 60:
		attempts += 1
		var p := Vector2(
			rng.randf_range(lot.position.x + 45.0, lot.end.x - 45.0),
			rng.randf_range(lot.position.y + 45.0, lot.end.y - 45.0))
		var ok := true
		for q in placed:
			if q.distance_to(p) < 80.0:
				ok = false
				break
		if ok:
			placed.append(p)
	trees.append_array(placed)


func _add_building(raw: Rect2, rng: RandomNumberGenerator) -> void:
	var rect := Rect2(
		snappedf(raw.position.x, 4.0), snappedf(raw.position.y, 4.0),
		snappedf(raw.size.x, 4.0), snappedf(raw.size.y, 4.0))
	var margin := DOOR_WIDTH / 2.0 + 16.0
	var door_x := lerpf(rect.position.x + margin, rect.end.x - margin, rng.randf())
	var door := Rect2(snappedf(door_x - DOOR_WIDTH / 2.0, 2.0), rect.end.y, DOOR_WIDTH, DOOR_DEPTH)
	var roof: Array[Rect2] = []
	for i in rng.randi_range(0, 3):
		var size := Vector2(rng.randf_range(18.0, 44.0), rng.randf_range(18.0, 44.0))
		roof.append(Rect2(
			Vector2(rng.randf_range(rect.position.x + 14.0, rect.end.x - 14.0 - size.x),
					rng.randf_range(rect.position.y + 14.0, rect.end.y - 14.0 - size.y)), size))
	buildings.append({
		"id": buildings.size(),
		"rect": rect,
		"color": Color.from_hsv(rng.randf(), 0.35, rng.randf_range(0.45, 0.8)),
		"door": door,
		"exit_spawn": Vector2(door.get_center().x, door.end.y + EXIT_SPAWN_OFFSET),
		"shop": "",
		"roof": roof,
	})


func _assign_shops(rng: RandomNumberGenerator) -> void:
	var candidates: Array[int] = []
	for b in buildings:
		if (b.rect as Rect2).size.x >= 160.0 and (b.rect as Rect2).size.y >= 160.0:
			candidates.append(b.id)
	for plan in SHOP_PLAN:
		for i in plan[1]:
			if candidates.is_empty():
				return
			var pick := rng.randi_range(0, candidates.size() - 1)
			buildings[candidates[pick]].shop = plan[0]
			candidates.remove_at(pick)
