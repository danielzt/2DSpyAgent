extends RefCounted
## Layout lógico da região Cidade (sem nós): ruas e avenidas com calçadas, bairros, lotes
## com prédios de formas variadas, parques e o tipo de cada prédio. Determinístico por seed.
## A cidade ocupa o canto (0, 0) do mundo; as ruas são centradas em múltiplos de BLOCK.
## As duas linhas AVENUE_LINE (uma vertical e uma horizontal) são avenidas, mais largas.

const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const BuildingStyle := preload("res://scripts/world/building_style.gd")
const NameGenerator := preload("res://scripts/world/name_generator.gd")

const CELLS := 12            # quarteirões por lado
const BLOCK := 560.0         # distância entre ruas (px)
const ROAD := 200.0          # corredor da rua comum: asfalto + duas calçadas
const ASPHALT := 140.0       # largura do asfalto da rua comum
const SIDEWALK := 30.0       # largura de cada calçada
const LOT := BLOCK - ROAD    # lado de um lote entre ruas comuns (360)
const AVENUE_LINE := 6       # linha (vertical e horizontal) que é avenida
const AVENUE_ASPHALT := 180.0
const AVENUE_ROAD := AVENUE_ASPHALT + SIDEWALK * 2.0   # corredor da avenida (240)
const CURB_PARKING := 16.0   # do meio-fio ao centro de um carro estacionado
const DOOR_WIDTH := 56.0
const DOOR_DEPTH := 12.0
const EXIT_SPAWN_OFFSET := 40.0  # distância abaixo da porta onde o jogador reaparece
const MIN_BUILDING := 120.0
const PARK_OFFSET := ASPHALT / 2.0 - CURB_PARKING   # rua comum: carro rente ao meio-fio (54)
## Quarteirões com um carro da agência estacionado na rua da esquerda (nenhum em avenida).
const PARKED_CELLS := [Vector2i(1, 0), Vector2i(3, 2), Vector2i(5, 1), Vector2i(2, 4), Vector2i(7, 5), Vector2i(4, 3)]

var world_seed: int
## Cada prédio: {id:int, rect:Rect2, color:Color, door:Rect2, exit_spawn:Vector2, shop:String,
## roof:Array[Rect2], district:String, floors:int, wall:String, roof_kind:String, type:String, name:String}
var buildings: Array[Dictionary] = []
var lots: Array[Rect2] = []
var parks: Array[Rect2] = []
## Árvores de parques e quintais (troncos sólidos).
var trees: Array[Vector2] = []
## Quintais (área gramada ao lado de um prédio que não ocupa o lote todo).
var yards: Array[Rect2] = []
## Bairros (DistrictLayout).
var districts
## Nomes das linhas de rua: {"v": [...], "h": [...]} (NameGenerator.street_names).
var street_names := {}


func _init(p_seed: int = 2024) -> void:
	world_seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	districts = DistrictLayout.new(p_seed)
	street_names = NameGenerator.street_names(p_seed)
	for cx in CELLS:
		for cy in CELLS:
			var lot := lot_rect(cx, cy)
			lots.append(lot)
			_fill_lot(lot, rng, districts.district_of_cell(Vector2i(cx, cy)))
	BuildingDefs.assign(buildings, rng)
	for b in buildings:
		b.color = BuildingStyle.wall_color(b.wall)


## Lado da região (a cidade é quadrada), em px.
static func city_size() -> float:
	return CELLS * BLOCK


static func is_avenue(line: int) -> bool:
	return line == AVENUE_LINE


## Largura do asfalto da linha de rua `line` (0..CELLS), igual nos dois eixos.
static func asphalt(line: int) -> float:
	return AVENUE_ASPHALT if is_avenue(line) else ASPHALT


## Largura do corredor (asfalto + duas calçadas) da linha `line`.
static func corridor(line: int) -> float:
	return asphalt(line) + SIDEWALK * 2.0


## Lote do quarteirão (cx, cy): o que sobra entre os corredores das quatro ruas em volta.
static func lot_rect(cx: int, cy: int) -> Rect2:
	var left := cx * BLOCK + corridor(cx) / 2.0
	var top := cy * BLOCK + corridor(cy) / 2.0
	return Rect2(left, top,
		(cx + 1) * BLOCK - corridor(cx + 1) / 2.0 - left,
		(cy + 1) * BLOCK - corridor(cy + 1) / 2.0 - top)


## Distância do eixo da rua ao centro de um carro estacionado rente ao meio-fio.
static func park_offset(line: int) -> float:
	return asphalt(line) / 2.0 - CURB_PARKING


## Linha de rua mais próxima de uma coordenada (0..CELLS).
static func nearest_line(coordinate: float) -> int:
	return clampi(roundi(coordinate / BLOCK), 0, CELLS)


## Ponto de início: cruzamento de ruas dentro do mapa.
static func spawn_point() -> Vector2:
	return Vector2(BLOCK, BLOCK)


## Posições de carros estacionados rente ao meio-fio, no meio de trechos de rua, apontando para baixo.
static func vehicle_spawns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in PARKED_CELLS:
		result.append({"position": Vector2(cell.x * BLOCK + park_offset(cell.x), cell.y * BLOCK + BLOCK / 2.0), "rotation": PI / 2.0})
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


## Nome da rua onde o ponto está (ou da mais próxima); nos cruzamentos, as duas.
func street_name_at(point: Vector2) -> String:
	if street_names.is_empty():
		return ""
	var vx := nearest_line(point.x)
	var hy := nearest_line(point.y)
	var dx := absf(point.x - vx * BLOCK) - corridor(vx) / 2.0
	var dy := absf(point.y - hy * BLOCK) - corridor(hy) / 2.0
	var v_name: String = street_names.v[vx]
	var h_name: String = street_names.h[hy]
	if dx <= 0.0 and dy <= 0.0:
		return "%s × %s" % [h_name, v_name]
	return v_name if dx < dy else h_name


## Preenche o lote conforme o bairro: chance de parque e pesos do formato
## (prédio único, dois prédios, prédio com quintal).
func _fill_lot(lot: Rect2, rng: RandomNumberGenerator, district: String) -> void:
	var params: Dictionary = DistrictLayout.params(district)
	var shapes: Array = params.shapes
	var width := lot.size.x
	var height := lot.size.y
	if rng.randf() < params.park:
		_make_park(lot, rng)
		return
	var roll := rng.randf() * float(shapes[0] + shapes[1] + shapes[2])
	if roll < shapes[0]:
		var left := rng.randf_range(0.0, 60.0)
		var right := rng.randf_range(0.0, 60.0)
		var top := rng.randf_range(0.0, 60.0)
		var bottom := rng.randf_range(0.0, 30.0)
		_add_building(Rect2(lot.position.x + left, lot.position.y + top, width - left - right, height - top - bottom), rng, district)
	elif roll < shapes[0] + shapes[1]:
		var ratio := rng.randf_range(0.42, 0.58)
		var gap := rng.randf_range(24.0, 48.0)
		var usable := width - gap
		var width_a := usable * ratio
		var width_b := usable - width_a
		for side in 2:
			var top := rng.randf_range(0.0, 60.0)
			var bottom := rng.randf_range(0.0, 30.0)
			var x := lot.position.x if side == 0 else lot.position.x + width_a + gap
			var w := width_a if side == 0 else width_b
			_add_building(Rect2(x, lot.position.y + top, w, height - top - bottom), rng, district)
	else:
		var w := rng.randf_range(0.5, 0.8) * width
		var on_left := rng.randf() < 0.5
		var top := rng.randf_range(0.0, 40.0)
		var bottom := rng.randf_range(0.0, 30.0)
		var x := lot.position.x if on_left else lot.end.x - w
		_add_building(Rect2(x, lot.position.y + top, w, height - top - bottom), rng, district)
		# Quintal ao lado: algumas árvores.
		var yard := Rect2(lot.position.x + (w if on_left else 0.0), lot.position.y, width - w, height)
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


## Cria o prédio com a aparência do bairro (andares, parede, telhado); o tipo vem depois.
func _add_building(raw: Rect2, rng: RandomNumberGenerator, district: String) -> void:
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
	var params: Dictionary = DistrictLayout.params(district)
	var floors := BuildingStyle.clamp_floors(rng.randi_range(params.floors[0], params.floors[1]), rect.size.y)
	var walls: Array = params.walls
	var roofs: Array = params.roofs
	var roof_kind: String = roofs[rng.randi_range(0, roofs.size() - 1)]
	if roof_kind.begins_with("roof/tile") and floors > BuildingStyle.TILE_ROOF_MAX_FLOORS:
		roof_kind = "roof/slab_light"
	buildings.append({
		"id": buildings.size(),
		"rect": rect,
		"color": Color.WHITE,
		"door": door,
		"exit_spawn": Vector2(door.get_center().x, door.end.y + EXIT_SPAWN_OFFSET),
		"shop": "",
		"roof": roof,
		"district": district,
		"floors": floors,
		"wall": walls[rng.randi_range(0, walls.size() - 1)],
		"roof_kind": roof_kind,
		"type": "",
		"name": "",
	})
