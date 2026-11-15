extends RefCounted
## Grafo das calçadas: cada cruzamento interno (cx, cy) tem 4 cantos (qx, qy ∈ {-1, +1}).
## Um nó é Vector4i(cx, cy, qx, qy). Arestas: seguir pela calçada até o canto do próximo
## cruzamento, ou atravessar a rua pela faixa de pedestres (inverter qx ou qy).

const CityLayout := preload("res://scripts/world/city_layout.gd")

const ALONG_WEIGHT := 3.0
const CROSS_WEIGHT := 1.0


## Distância do centro da rua ao meio da calçada.
static func half() -> float:
	return CityLayout.ASPHALT / 2.0 + CityLayout.SIDEWALK / 2.0


static func is_valid(n: Vector4i) -> bool:
	return n.x >= 1 and n.x <= CityLayout.CELLS - 1 and n.y >= 1 and n.y <= CityLayout.CELLS - 1 \
		and (n.z == 1 or n.z == -1) and (n.w == 1 or n.w == -1)


static func position(n: Vector4i) -> Vector2:
	return Vector2(n.x * CityLayout.BLOCK + n.z * half(), n.y * CityLayout.BLOCK + n.w * half())


## Vizinhos pela calçada (mesma rua, próximo cruzamento).
static func along_neighbors(n: Vector4i) -> Array[Vector4i]:
	var result: Array[Vector4i] = []
	for candidate in [Vector4i(n.x + n.z, n.y, -n.z, n.w), Vector4i(n.x, n.y + n.w, n.z, -n.w)]:
		if is_valid(candidate):
			result.append(candidate)
	return result


## Vizinhos pela faixa de pedestres (atravessando uma das ruas do cruzamento).
static func cross_neighbors(n: Vector4i) -> Array[Vector4i]:
	var result: Array[Vector4i] = []
	for candidate in [Vector4i(n.x, n.y, -n.z, n.w), Vector4i(n.x, n.y, n.z, -n.w)]:
		if is_valid(candidate):
			result.append(candidate)
	return result


static func neighbors(n: Vector4i) -> Array[Vector4i]:
	var result := along_neighbors(n)
	result.append_array(cross_neighbors(n))
	return result


## Próximo nó do passeio, sem voltar para `came_from` (a menos que não haja outra saída).
static func next_node(n: Vector4i, came_from: Vector4i, rng: RandomNumberGenerator) -> Vector4i:
	var options: Array[Vector4i] = []
	var weights: Array[float] = []
	var total := 0.0
	for c in along_neighbors(n):
		if c != came_from:
			options.append(c)
			weights.append(ALONG_WEIGHT)
			total += ALONG_WEIGHT
	for c in cross_neighbors(n):
		if c != came_from:
			options.append(c)
			weights.append(CROSS_WEIGHT)
			total += CROSS_WEIGHT
	if options.is_empty():
		return came_from
	var roll := rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]


## Vizinho que mais afasta de `threat` (fuga pela calçada).
static func farthest_neighbor(n: Vector4i, threat: Vector2, came_from: Vector4i) -> Vector4i:
	var best := came_from
	var best_dist := -1.0
	for c in neighbors(n):
		if c == came_from:
			continue
		var d := position(c).distance_to(threat)
		if d > best_dist:
			best_dist = d
			best = c
	return best


## Nó mais próximo de um ponto (qualquer lugar do mapa).
static func nearest_node(point: Vector2) -> Vector4i:
	var cx := clampi(roundi(point.x / CityLayout.BLOCK), 1, CityLayout.CELLS - 1)
	var cy := clampi(roundi(point.y / CityLayout.BLOCK), 1, CityLayout.CELLS - 1)
	var qx := 1 if point.x >= cx * CityLayout.BLOCK else -1
	var qy := 1 if point.y >= cy * CityLayout.BLOCK else -1
	return Vector4i(cx, cy, qx, qy)


## Ponto aleatório sobre uma calçada: {from:Vector4i, to:Vector4i, position:Vector2}.
static func random_sidewalk_point(rng: RandomNumberGenerator) -> Dictionary:
	while true:
		var n := Vector4i(
			rng.randi_range(1, CityLayout.CELLS - 1), rng.randi_range(1, CityLayout.CELLS - 1),
			1 if rng.randf() < 0.5 else -1, 1 if rng.randf() < 0.5 else -1)
		var along := along_neighbors(n)
		if along.is_empty():
			continue
		var to: Vector4i = along[rng.randi_range(0, along.size() - 1)]
		return {"from": n, "to": to, "position": position(n).lerp(position(to), rng.randf())}
	return {}
