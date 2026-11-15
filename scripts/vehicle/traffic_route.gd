extends RefCounted
## Rotas do trânsito: carros andam entre cruzamentos da grade da cidade,
## sempre na faixa da direita, escolhendo uma direção a cada cruzamento.

const CityLayout := preload("res://scripts/world/city_layout.gd")

const LANE_OFFSET := 26.0
## Avenida: duas faixas por sentido (distância do eixo ao centro de cada uma).
const AVENUE_LANES := [28.0, 66.0]
const STRAIGHT_CHANCE := 0.6
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


## Cruzamentos navegáveis: 1..CELLS-1 (as ruas da borda do mapa são estreitas).
static func is_valid_node(node: Vector2i) -> bool:
	return node.x >= 1 and node.x <= CityLayout.CELLS - 1 and node.y >= 1 and node.y <= CityLayout.CELLS - 1


static func node_position(node: Vector2i) -> Vector2:
	return Vector2(node.x, node.y) * CityLayout.BLOCK


## Linha de rua (0..CELLS) percorrida por quem chega a `node` na direção `dir`.
static func line_of(node: Vector2i, dir: Vector2i) -> int:
	return node.y if dir.x != 0 else node.x


## Distância do eixo da rua ao centro da faixa. Na avenida há duas faixas por sentido:
## `lane` 0 é a de dentro e 1 a de fora; na rua comum só existe uma.
static func lane_offset(node: Vector2i, dir: Vector2i, lane := 0) -> float:
	if CityLayout.is_avenue(line_of(node, dir)):
		return AVENUE_LANES[clampi(lane, 0, AVENUE_LANES.size() - 1)]
	return LANE_OFFSET


## Ponto na faixa da direita de quem chega ao cruzamento andando na direção `dir`.
static func lane_point(node: Vector2i, dir: Vector2i, lane := 0) -> Vector2:
	return node_position(node) + Vector2(-dir.y, dir.x) * lane_offset(node, dir, lane)


## Ponto na faixa, `lookahead` px à frente da projeção de `pos` sobre a linha da faixa.
## Perseguir esse ponto mantém o carro na faixa da direita (e o traz de volta a ela).
static func lane_target(pos: Vector2, node: Vector2i, dir: Vector2i, lookahead: float, lane := 0) -> Vector2:
	var origin := lane_point(node, dir, lane)
	var d := Vector2(dir)
	return origin + d * ((pos - origin).dot(d) + lookahead)


## True quando `pos` está a menos de `margin` px do cruzamento (ou já o passou), na direção `dir`.
static func reached_node(pos: Vector2, node: Vector2i, dir: Vector2i, margin: float) -> bool:
	return (pos - lane_point(node, dir)).dot(Vector2(dir)) > -margin


## Direções possíveis a partir do cruzamento (sem voltar por onde veio).
static func choices(node: Vector2i, came_dir: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRS:
		if d == -came_dir:
			continue
		if is_valid_node(node + d):
			result.append(d)
	return result


static func next_dir(node: Vector2i, came_dir: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var options := choices(node, came_dir)
	if options.is_empty():
		return -came_dir  # beco sem saída: retorno
	if options.has(came_dir) and rng.randf() < STRAIGHT_CHANCE:
		return came_dir
	return options[rng.randi_range(0, options.size() - 1)]
