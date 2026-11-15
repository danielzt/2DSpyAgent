extends RefCounted
## Bairros da cidade (lógica pura): cada quarteirão da grade pertence a um de seis bairros.
## O Centro nasce nas quatro quadras do meio; os outros cinco partem de pontos em setores
## ao redor, embaralhados pela seed, e crescem quarteirão a quarteirão até a cota de cada um.
## Crescer sempre por um vizinho garante bairros contíguos.

const CELLS := 12
const BLOCK := 560.0
## Menor bairro aceito; abaixo disso a geração repete com a seed derivada seguinte.
const MIN_CELLS := 10
const MAX_ATTEMPTS := 20

const IDS := ["center", "residential", "nightlife", "industrial", "upscale", "civic"]

## Por bairro: nomes possíveis, fração dos quarteirões, chance de parque, pesos do formato
## do lote [prédio único, dois prédios, prédio com quintal], andares [mín, máx], telhados e paredes.
const DISTRICTS := {
	"center": {
		"label": "Centro comercial",
		"names": ["Centro Velho", "Centro Novo de Novo", "Miolo da Cidade"],
		"share": 0.22, "park": 0.05, "shapes": [45, 50, 5], "floors": [3, 6],
		"roofs": ["roof/slab", "roof/slab_light", "roof/tar"],
		"walls": ["wall/concrete", "wall/white", "wall/blue", "wall/wine", "wall/brick"],
	},
	"residential": {
		"label": "Residencial",
		"names": ["Vila Sossego", "Vila do Vizinho Curioso", "Parque das Cortinas"],
		"share": 0.28, "park": 0.15, "shapes": [10, 40, 50], "floors": [1, 2],
		"roofs": ["roof/tile", "roof/tile_red", "roof/tile_brown"],
		"walls": ["wall/cream", "wall/clay", "wall/teal", "wall/pink"],
	},
	"nightlife": {
		"label": "Vida noturna",
		"names": ["Baixo Neon", "Alto Volume", "Beco da Saideira"],
		"share": 0.12, "park": 0.05, "shapes": [30, 65, 5], "floors": [2, 3],
		"roofs": ["roof/slab", "roof/tar"],
		"walls": ["wall/purple", "wall/navy", "wall/wine", "wall/gray"],
	},
	"industrial": {
		"label": "Industrial",
		"names": ["Distrito das Chaminés", "Doca Seca", "Vila Ferrugem"],
		"share": 0.16, "park": 0.0, "shapes": [75, 20, 5], "floors": [1, 2],
		"roofs": ["roof/zinc", "roof/zinc", "roof/tar"],
		"walls": ["wall/silver", "wall/gray", "wall/brown", "wall/concrete", "wall/brick"],
	},
	"upscale": {
		"label": "Bairro nobre",
		"names": ["Jardim Grã-Fino", "Alto do Caviar", "Recanto do Iate"],
		"share": 0.14, "park": 0.20, "shapes": [15, 15, 70], "floors": [1, 3],
		"roofs": ["roof/tile", "roof/tile_red", "roof/tile_brown"],
		"walls": ["wall/snow", "wall/cream", "wall/ice", "wall/sand"],
	},
	"civic": {
		"label": "Cívico",
		"names": ["Praça dos Três Carimbos", "Largo do Protocolo", "Esplanada da Fila"],
		"share": 0.08, "park": 0.10, "shapes": [70, 25, 5], "floors": [2, 4],
		"roofs": ["roof/slab", "roof/slab_light"],
		"walls": ["wall/white", "wall/snow", "wall/concrete"],
	},
}

var world_seed: int
## Vector2i(cx, cy) -> id do bairro.
var cells := {}
## id do bairro -> nome sorteado.
var names := {}
## id do bairro -> quarteirão inicial.
var seeds := {}


func _init(p_seed: int = 2024) -> void:
	world_seed = p_seed
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = p_seed * 7919 + 13 + attempt * 104729
		_generate(rng)
		if smallest_count() >= MIN_CELLS:
			break
	var name_rng := RandomNumberGenerator.new()
	name_rng.seed = p_seed * 31 + 5
	for id in IDS:
		var options: Array = DISTRICTS[id].names
		names[id] = options[name_rng.randi_range(0, options.size() - 1)]


static func params(id: String) -> Dictionary:
	return DISTRICTS.get(id, {})


## Quantos quarteirões cada bairro deve ter (soma CELLS * CELLS).
static func targets() -> Dictionary:
	var total := CELLS * CELLS
	var result := {}
	var assigned := 0
	for id in IDS:
		result[id] = int(floor(DISTRICTS[id].share * total))
		assigned += result[id]
	# A sobra do arredondamento vai para os maiores bairros, um quarteirão por vez.
	var order := IDS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return DISTRICTS[a].share > DISTRICTS[b].share)
	var i := 0
	while assigned < total:
		result[order[i % order.size()]] += 1
		assigned += 1
		i += 1
	return result


func district_of_cell(cell: Vector2i) -> String:
	return cells.get(cell, "")


## Quarteirão que contém o ponto (as ruas pertencem ao quarteirão à direita e abaixo).
static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(point.x / BLOCK)), 0, CELLS - 1),
		clampi(int(floor(point.y / BLOCK)), 0, CELLS - 1))


## Id do bairro do ponto ("" fora da cidade).
func district_at(point: Vector2) -> String:
	var size := CELLS * BLOCK
	if point.x < 0.0 or point.y < 0.0 or point.x >= size or point.y >= size:
		return ""
	return district_of_cell(cell_of(point))


func name_of(id: String) -> String:
	return names.get(id, "")


func name_at(point: Vector2) -> String:
	return name_of(district_at(point))


func count(id: String) -> int:
	var total := 0
	for cell in cells:
		if cells[cell] == id:
			total += 1
	return total


func smallest_count() -> int:
	var smallest := CELLS * CELLS
	for id in IDS:
		smallest = mini(smallest, count(id))
	return smallest


## True se todos os quarteirões do bairro se ligam por vizinhos de lado.
func is_contiguous(id: String) -> bool:
	var mine: Array[Vector2i] = []
	for cell in cells:
		if cells[cell] == id:
			mine.append(cell)
	if mine.is_empty():
		return false
	var seen := {mine[0]: true}
	var queue: Array[Vector2i] = [mine[0]]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for n in _neighbors(cell):
			if cells.get(n, "") == id and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == mine.size()


func _generate(rng: RandomNumberGenerator) -> void:
	cells.clear()
	seeds.clear()
	var want := targets()
	var have := {}
	for id in IDS:
		have[id] = 0

	# Centro: as quatro quadras do meio.
	var mid := CELLS / 2
	seeds["center"] = Vector2i(mid, mid)
	for cell in [Vector2i(mid - 1, mid - 1), Vector2i(mid, mid - 1), Vector2i(mid - 1, mid), Vector2i(mid, mid)]:
		cells[cell] = "center"
		have["center"] += 1

	# Os outros cinco: um ponto por setor em volta do centro, em ordem embaralhada.
	var others: Array = IDS.slice(1)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: String = others[i]
		others[i] = others[j]
		others[j] = swap
	var turn := rng.randf() * TAU
	for i in others.size():
		var angle := turn + TAU * float(i) / float(others.size())
		var radius := rng.randf_range(3.6, 4.6)
		var cell := Vector2i(
			clampi(int(round(mid - 0.5 + cos(angle) * radius)), 0, CELLS - 1),
			clampi(int(round(mid - 0.5 + sin(angle) * radius)), 0, CELLS - 1))
		while cells.has(cell):
			cell = Vector2i((cell.x + 1) % CELLS, cell.y)
		seeds[others[i]] = cell
		cells[cell] = others[i]
		have[others[i]] += 1

	# Crescimento: a cada volta, o bairro mais atrasado em relação à cota pega o
	# quarteirão livre vizinho mais próximo do seu ponto inicial.
	var growing := true
	while growing:
		growing = false
		var order := IDS.duplicate()
		order.sort_custom(func(a: String, b: String) -> bool:
			var ra := float(have[a]) / float(want[a])
			var rb := float(have[b]) / float(want[b])
			return ra < rb if ra != rb else IDS.find(a) < IDS.find(b))
		for id in order:
			if have[id] >= want[id]:
				continue
			var pick := _nearest_free_neighbor(id)
			if pick.x < 0:
				continue
			cells[pick] = id
			have[id] += 1
			growing = true
			break

	# Sobras (quarteirões cercados por bairros já cheios): vão para um vizinho.
	var pending := true
	while pending:
		pending = false
		for cx in CELLS:
			for cy in CELLS:
				var cell := Vector2i(cx, cy)
				if cells.has(cell):
					continue
				var best := ""
				for n in _neighbors(cell):
					var id: String = cells.get(n, "")
					if id != "" and (best == "" or have[id] < have[best]):
						best = id
				if best != "":
					cells[cell] = best
					have[best] += 1
					pending = true


func _nearest_free_neighbor(id: String) -> Vector2i:
	var origin: Vector2i = seeds[id]
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cx in CELLS:
		for cy in CELLS:
			var cell := Vector2i(cx, cy)
			if cells.has(cell):
				continue
			var touches := false
			for n in _neighbors(cell):
				if cells.get(n, "") == id:
					touches = true
					break
			if not touches:
				continue
			var d := (cell - origin).length_squared()
			if d < best_d:
				best_d = d
				best = cell
	return best


static func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if n.x >= 0 and n.x < CELLS and n.y >= 0 and n.y < CELLS:
			result.append(n)
	return result
