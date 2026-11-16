extends RefCounted
## Layout lógico de um interior (sem nós), lido da planta em mapa de texto do tipo de prédio
## (`plans/<tipo>.gd`, formato em `plan_parser.gd`). A seed do id do prédio decide espelhamento,
## variante de cores e itens e pessoas opcionais. Tipo sem planta usa a planta da casa.

const Services := preload("res://scripts/interior/services.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")
const PlanParser := preload("res://scripts/interior/plan_parser.gd")

const DEFAULT_TYPE := "house"
const ZONE_DEPTH := 90.0      # profundidade da zona de compra em frente ao balcão da loja
const GRID := 32.0            # grade da validação de caminho
const BODY := 24.0            # lado da colisão do jogador

var building_id: int
var type: String
## Tipo cuja planta foi usada (o próprio tipo ou a casa, para tipos sem planta).
var template: String
var size_class: String
var size: Vector2
var mirrored := false
var base_floor: String
## Loja deste interior ("" se não for loja) e o balcão dela.
var shop := ""
var is_shop := false
var counter := Rect2()
## Cômodos: {name, rect, floor, wall}
var rooms: Array[Dictionary] = []
## Paredes (sólidas), inclusive a borda.
var walls: Array[Rect2] = []
## Móveis e itens: {kind, rect, solid, layer ("floor", "on", "wall"), tone[, secret]}
var items: Array[Dictionary] = []
## Retângulos dos móveis sólidos (atalho para colisão e testes; a passagem secreta não entra).
var furniture: Array[Rect2] = []
## Vagas de NPC: {role, position, staff, act, route, facing}
var npc_slots: Array[Dictionary] = []
## Zonas de serviço: {id, rect, verb}
var zones: Array[Dictionary] = []
## Sempre verdadeiro (todo interior vem de uma planta); mantido para quem consulta.
var planned := true
## Pisos por trecho {rect, floor}, faces de parede {rect, style}, vãos de porta e a variante sorteada.
var floor_rects: Array = []
var wall_faces: Array = []
var doors: Array = []
var variant := 0
## Passagem secreta (QG): móvel que bloqueia até o jogador abrir com E; cômodos escondidos até lá.
var secret_door := Rect2()
var hidden_rooms: Array = []
var _exit := Rect2()
var _spawn := Vector2.ZERO


func _init(p_building_id: int = 0, p_type := "", _facade_width := 240.0) -> void:
	building_id = p_building_id
	type = p_type
	template = plan_type(p_type)
	shop = BuildingDefs.shop_of(p_type) if BuildingDefs.exists(p_type) else (p_type if ShopDefs.exists(p_type) else "")
	is_shop = shop != ""
	_load_plan(Plans.data(template))


func _load_plan(plan: Dictionary) -> void:
	var parsed := PlanParser.parse(plan, building_id)
	size_class = parsed.size_class
	size = parsed.size
	mirrored = parsed.mirrored
	variant = parsed.variant
	for room in parsed.rooms:
		rooms.append(room)
	for wall in parsed.walls:
		walls.append(wall)
	for item in parsed.items:
		items.append(item)
	for slot in parsed.npc_slots:
		npc_slots.append(slot)
	for z in parsed.zones:
		z.verb = z.verb if z.verb != "" else Services.verb(z.id)
		zones.append(z)
	floor_rects = parsed.floor_rects
	wall_faces = parsed.wall_faces
	doors = parsed.doors
	secret_door = parsed.secret_door
	hidden_rooms = parsed.hidden
	_exit = parsed.exit
	_spawn = parsed.spawn
	base_floor = floor_rects[0].floor if not floor_rects.is_empty() else "floor/wood"
	if is_shop and parsed.counter.size.x > 0.0:
		# loja: o vendedor atrás do balcão é a primeira vaga; a zona de compra fica logo à frente
		counter = parsed.counter
		var shop_label: String = ShopDefs.shop_name(shop) if shop != "" else "loja"
		zones.append({"id": "shop", "rect": counter_zone(), "verb": "comprar: %s" % shop_label})
		npc_slots.insert(0, {"role": _role(0), "position": merchant_position(), "staff": true, "act": "post",
				"route": [], "facing": "down"})
	_refresh_furniture()


# --- consultas ---

## Tipo cuja planta vale para `p_type` (a casa, se o tipo não tiver planta).
static func plan_type(p_type: String) -> String:
	return p_type if Plans.has(p_type) else DEFAULT_TYPE


static func is_planned(p_type: String) -> bool:
	return Plans.has(p_type)


## Classe de tamanho da planta do tipo (a largura da fachada não muda nada).
static func size_class_for(p_type: String, _facade_width := 240.0) -> String:
	return Plans.data(plan_type(p_type)).size


func room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func exit_door() -> Rect2:
	return _exit


func spawn_point() -> Vector2:
	return _spawn


## Área em frente à saída que fica sempre livre de móveis e paredes.
func clear_zone() -> Rect2:
	return Rect2(_exit.position.x, size.y - 3.0 * PlanParser.CELL, _exit.size.x, 3.0 * PlanParser.CELL)


## Posição do vendedor (atrás do balcão). Só faz sentido em lojas.
func merchant_position() -> Vector2:
	return Vector2(counter.get_center().x, counter.position.y - 30.0)


## Área onde o jogador pode falar com o vendedor (em frente ao balcão).
func counter_zone() -> Rect2:
	return Rect2(counter.position.x, counter.end.y, counter.size.x, ZONE_DEPTH)


func zone(id: String) -> Dictionary:
	for z in zones:
		if z.id == id:
			return z
	return {}


## Tudo o que é sólido: paredes e móveis sólidos.
func solids() -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.append_array(walls)
	result.append_array(furniture)
	return result


## Nomes do que o jogador não consegue alcançar a partir da entrada: zonas de serviço e a
## saída. Vazio = interior válido. Preenchimento em grade de 32 px, com a colisão do jogador.
func unreachable() -> Array[String]:
	var cols := int(size.x / GRID)
	var rows := int(size.y / GRID)
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	var half := BODY / 2.0
	for solid in solids():
		var grown := solid.grow(half)
		var x0 := maxi(int(floor((grown.position.x - GRID / 2.0) / GRID)), 0)
		var x1 := mini(int(ceil((grown.end.x - GRID / 2.0) / GRID)), cols - 1)
		var y0 := maxi(int(floor((grown.position.y - GRID / 2.0) / GRID)), 0)
		var y1 := mini(int(ceil((grown.end.y - GRID / 2.0) / GRID)), rows - 1)
		for cx in range(x0, x1 + 1):
			for cy in range(y0, y1 + 1):
				var center := Vector2(cx * GRID + GRID / 2.0, cy * GRID + GRID / 2.0)
				if center.x > grown.position.x and center.x < grown.end.x and center.y > grown.position.y and center.y < grown.end.y:
					blocked[cy * cols + cx] = 1
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var start := spawn_point()
	var sx := clampi(int(start.x / GRID), 0, cols - 1)
	var sy := clampi(int(start.y / GRID), 0, rows - 1)
	var queue: Array[int] = [sy * cols + sx]
	seen[sy * cols + sx] = 1
	while not queue.is_empty():
		var index: int = queue.pop_back()
		var cx := index % cols
		var cy := index / cols
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var n := ny * cols + nx
			if seen[n] == 0 and blocked[n] == 0:
				seen[n] = 1
				queue.append(n)
	var missing: Array[String] = []
	var targets := {"saída": exit_door().grow(GRID)}
	for z in zones:
		targets["zona %s" % z.id] = z.rect
	for room in rooms:
		targets["cômodo %s" % room.name] = room.rect
	for target_name in targets:
		var rect: Rect2 = targets[target_name]
		var reached := false
		for cx in range(maxi(int(rect.position.x / GRID), 0), mini(int(rect.end.x / GRID), cols - 1) + 1):
			for cy in range(maxi(int(rect.position.y / GRID), 0), mini(int(rect.end.y / GRID), rows - 1) + 1):
				if seen[cy * cols + cx] == 1 and rect.has_point(Vector2(cx * GRID + GRID / 2.0, cy * GRID + GRID / 2.0)):
					reached = true
		if not reached:
			missing.append(target_name)
	return missing


## Papel do funcionário `index` deste tipo de prédio.
func _role(index := 0) -> String:
	var staff: Array = BuildingDefs.staff_of(type)
	if staff.is_empty():
		return "atendente"
	return staff[index % staff.size()]


func _refresh_furniture() -> void:
	furniture.clear()
	for item in items:
		if item.solid and not item.get("secret", false):
			furniture.append(item.rect)   # a passagem secreta abre: não fecha caminho para sempre
