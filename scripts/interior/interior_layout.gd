extends RefCounted
## Layout lógico de um interior (sem nós). A escala interna é bem maior que a externa.

const SIZE := Vector2(1920, 1200)
const EXIT_WIDTH := 80.0
const EXIT_DEPTH := 12.0
const FURNITURE_COUNT := 10
const SHOP_FURNITURE_COUNT := 4
const SHOP_ZONE := Rect2(SIZE.x / 2.0 - 260.0, 80.0, 520.0, 300.0)  # balcão e vendedor
const COUNTER := Rect2(SIZE.x / 2.0 - 180.0, 200.0, 360.0, 48.0)
const MARGIN := 100.0
const CLEAR_ZONE := Rect2(SIZE.x / 2.0 - 160.0, SIZE.y - 260.0, 320.0, 260.0)

var building_id: int
var is_shop := false
var furniture: Array[Rect2] = []


func _init(p_building_id: int = 0, p_shop := false) -> void:
	building_id = p_building_id
	is_shop = p_shop
	var rng := RandomNumberGenerator.new()
	rng.seed = p_building_id * 7919 + 13
	var attempts := 0
	var wanted := SHOP_FURNITURE_COUNT if p_shop else FURNITURE_COUNT
	while furniture.size() < wanted and attempts < 500:
		attempts += 1
		var size := Vector2(rng.randi_range(4, 10) * 16, rng.randi_range(3, 6) * 16)
		var pos := Vector2(
			snappedf(rng.randf_range(MARGIN, SIZE.x - MARGIN - size.x), 16.0),
			snappedf(rng.randf_range(MARGIN, SIZE.y - MARGIN - size.y), 16.0))
		var rect := Rect2(pos, size)
		if rect.intersects(CLEAR_ZONE) or (p_shop and rect.intersects(SHOP_ZONE)):
			continue
		var overlaps := false
		for other in furniture:
			if rect.grow(32.0).intersects(other):
				overlaps = true
				break
		if not overlaps:
			furniture.append(rect)


static func exit_door() -> Rect2:
	return Rect2(SIZE.x / 2.0 - EXIT_WIDTH / 2.0, SIZE.y - EXIT_DEPTH, EXIT_WIDTH, EXIT_DEPTH)


static func spawn_point() -> Vector2:
	return Vector2(SIZE.x / 2.0, SIZE.y - 80.0)


## Posição do vendedor (atrás do balcão).
static func merchant_position() -> Vector2:
	return Vector2(SIZE.x / 2.0, COUNTER.position.y - 30.0)


## Área onde o jogador pode falar com o vendedor (em frente ao balcão).
static func counter_zone() -> Rect2:
	return Rect2(COUNTER.position.x, COUNTER.end.y, COUNTER.size.x, 90.0)
