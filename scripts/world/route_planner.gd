extends RefCounted
## Rota pelas ruas até um ponto (lógica pura): a cidade é uma grade de ruas retas (linhas de
## 0 a CELLS nos dois eixos) e a estrada do campo continua a rua do meio para o leste. O
## caminho sai do ponto de partida até a rua mais perto, segue pelas ruas (menos curvas
## possível não é garantido, só o menor caminho) e entra até o destino.

const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")

const BLOCK := CityLayout.BLOCK
const CELLS := CityLayout.CELLS
## Linha horizontal da estrada do campo e quantos cruzamentos a mais ela tem para o leste.
const ROAD_LINE := 6
const COUNTRY_NODES := 12

static var _edges: Array = []


## Os cruzamentos vizinhos de um cruzamento (i, j).
static func neighbors(node: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = node + d
		if is_node_valid(n):
			result.append(n)
	return result


static func is_node_valid(n: Vector2i) -> bool:
	if n.x < 0 or n.y < 0 or n.y > CELLS:
		return false
	if n.x <= CELLS:
		return true
	return n.y == ROAD_LINE and n.x <= CELLS + COUNTRY_NODES


static func position_of(node: Vector2i) -> Vector2:
	return Vector2(node.x, node.y) * BLOCK


## Trechos de rua: pares de cruzamentos vizinhos (cada trecho uma vez).
static func edges() -> Array:
	if _edges.is_empty():
		for i in CELLS + COUNTRY_NODES + 1:
			for j in CELLS + 1:
				var node := Vector2i(i, j)
				if not is_node_valid(node):
					continue
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					if is_node_valid(node + d):
						_edges.append([node, node + d])
	return _edges


## Ponto de uma rua mais perto de `point`: {pos, edge} (edge = índice em `edges()`).
static func snap(point: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	var list := edges()
	for index in list.size():
		var a := position_of(list[index][0])
		var b := position_of(list[index][1])
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var d := point.distance_to(closest)
		if d < best_d:
			best_d = d
			best = {"pos": closest, "edge": index}
	return best


## Menor caminho entre dois cruzamentos (busca em largura; todos os trechos pesam o mesmo).
static func node_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if current == to:
			break
		for n in neighbors(current):
			if not came.has(n):
				came[n] = current
				queue.append(n)
	var path: Array[Vector2i] = []
	if not came.has(to):
		return path
	var cursor := to
	while cursor != from:
		path.push_front(cursor)
		cursor = came[cursor]
	path.push_front(from)
	return path


static func _length(points: Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += (points[i - 1] as Vector2).distance_to(points[i])
	return total


## Rota de `from` até `to`: lista de pontos do mundo (começa em `from`, termina em `to`).
static func plan(from: Vector2, to: Vector2) -> Array[Vector2]:
	var s := snap(from)
	var t := snap(to)
	var edge_list := edges()
	var best: Array[Vector2] = []
	var best_len := INF
	if s.edge == t.edge:
		best = [from, s.pos, t.pos, to]
		return best
	for a in edge_list[s.edge]:
		for b in edge_list[t.edge]:
			var nodes := node_path(a, b)
			if nodes.is_empty():
				continue
			var points: Array[Vector2] = [from, s.pos]
			for n in nodes:
				points.append(position_of(n))
			points.append(t.pos)
			points.append(to)
			var length := _length(points)
			if length < best_len:
				best_len = length
				best = points
	return _simplified(best)


## Tira pontos repetidos e os do meio de trechos retos.
static func _simplified(points: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for p in points:
		if not result.is_empty() and result[result.size() - 1].distance_to(p) < 0.5:
			continue
		if result.size() >= 2:
			var a := result[result.size() - 2]
			var b := result[result.size() - 1]
			if absf((b - a).normalized().cross((p - b).normalized())) < 0.001 and (b - a).dot(p - b) > 0.0:
				result[result.size() - 1] = p
				continue
		result.append(p)
	return result


static func length_of(points: Array) -> float:
	return _length(points)


## Pontos espaçados de `spacing` px ao longo da rota (para desenhar a trilha pontilhada).
static func dots(points: Array, spacing: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var carry := 0.0
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var segment := a.distance_to(b)
		var at := carry
		while at < segment:
			result.append(a.lerp(b, at / segment))
			at += spacing
		carry = at - segment
	return result
