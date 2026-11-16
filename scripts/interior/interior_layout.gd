extends RefCounted
## Layout lógico de um interior (sem nós), gerado pela seed do id do prédio.
## Cada tipo de prédio usa um modelo de planta: cômodos com piso próprio, paredes internas
## com vãos de porta, móveis reconhecíveis, vagas de NPC com papel e zonas de serviço.
## A escala interna é bem maior que a externa (três tamanhos: P, M e G).
## Variação por seed: espelhamento horizontal e quantidade de mesas, quartos, prateleiras etc.

const Services := preload("res://scripts/interior/services.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const Plans := preload("res://scripts/interior/plans/plans.gd")
const PlanParser := preload("res://scripts/interior/plan_parser.gd")

const SIZES := {"P": Vector2(1280, 800), "M": Vector2(1920, 1200), "G": Vector2(2560, 1440)}
const SIZE_ORDER := ["P", "M", "G"]
## Fachada mais estreita que NARROW desce um tamanho; a partir de WIDE sobe um.
const NARROW_FACADE := 180.0
const WIDE_FACADE := 280.0
const DEFAULT_FACADE := 240.0

const EXIT_WIDTH := 80.0
const EXIT_DEPTH := 12.0
const WALL_T := 16.0          # espessura das paredes internas
const GAP := 112.0            # largura dos vãos de porta
const ZONE_DEPTH := 90.0      # profundidade da zona em frente a um balcão
const GRID := 32.0            # grade da validação de caminho
const BODY := 24.0            # lado da colisão do jogador

## Modelo de planta por tipo de prédio.
const TEMPLATES := {
	"armory": "shop", "pharmacy": "shop", "agent_store": "shop", "market": "shop", "gas_station": "shop",
	"farm_store": "shop", "hotel": "hotel", "restaurant": "restaurant", "diner": "restaurant", "bar": "bar",
	"club": "club", "bank": "bank", "police": "police", "hospital": "hospital", "workshop": "workshop",
	"cinema": "cinema", "gym": "gym", "office": "office", "newspaper": "office", "apartment": "home",
	"house": "home", "farm": "home", "warehouse": "warehouse", "hq": "hq", "agent_home": "agent_home",
}
const DEFAULT_TEMPLATE := "home"
## Tamanho base e piso de cada modelo.
const BASE_SIZE := {
	"shop": "P", "hotel": "G", "restaurant": "M", "bar": "M", "club": "G", "bank": "M", "police": "M",
	"hospital": "M", "workshop": "M", "cinema": "G", "gym": "M", "office": "M", "home": "P",
	"warehouse": "G", "hq": "G", "agent_home": "M",
}
const FLOORS := {
	"shop": "floor/tile", "hotel": "floor/carpet", "restaurant": "floor/wood", "bar": "floor/wood",
	"club": "floor/concrete", "bank": "floor/marble", "police": "floor/tile", "hospital": "floor/marble",
	"workshop": "floor/concrete", "cinema": "floor/carpet", "gym": "floor/wood", "office": "floor/tile",
	"home": "floor/wood", "warehouse": "floor/concrete", "hq": "floor/tile", "agent_home": "floor/wood",
}
## Decoração que enche o espaço livre, por modelo: [móvel, largura, altura, mín., máx.].
const DECOR := {
	"shop": [["plant", 44, 44, 1, 2], ["trash", 32, 32, 1, 1]],
	"hotel": [["plant", 44, 44, 2, 4], ["vending", 56, 64, 1, 1], ["sofa", 176, 64, 1, 2], ["trash", 32, 32, 1, 2]],
	"restaurant": [["plant", 44, 44, 2, 3], ["trash", 32, 32, 1, 2]],
	"bar": [["plant", 44, 44, 1, 2], ["speaker", 48, 72, 1, 2], ["trash", 32, 32, 1, 2]],
	"club": [["speaker", 48, 72, 2, 4], ["plant", 44, 44, 1, 2]],
	"bank": [["plant", 44, 44, 2, 3], ["file_cabinet", 48, 64, 2, 3]],
	"police": [["trash", 32, 32, 1, 2]],
	"hospital": [["plant", 44, 44, 2, 3], ["cart", 56, 44, 1, 2]],
	"workshop": [["toolbox", 48, 32, 2, 3], ["tires", 56, 56, 1, 2]],
	"cinema": [["plant", 44, 44, 2, 3], ["vending", 56, 64, 1, 1], ["trash", 32, 32, 1, 2]],
	"gym": [["water_cooler", 40, 52, 1, 2], ["weights", 96, 40, 1, 2], ["plant", 44, 44, 1, 2]],
	"office": [["plant", 44, 44, 2, 3], ["file_cabinet", 48, 64, 2, 3], ["water_cooler", 40, 52, 1, 1], ["bookshelf", 56, 150, 1, 1]],
	"home": [["plant", 44, 44, 1, 2], ["trash", 32, 32, 0, 1]],
	"agent_home": [["plant", 44, 44, 1, 2]],
	"warehouse": [["crates", 72, 56, 3, 5], ["pallet", 72, 56, 2, 3]],
	"hq": [["plant", 44, 44, 1, 2], ["file_cabinet", 48, 64, 1, 2]],
}
## O ponto está longe de móveis sólidos e paredes (cabe uma pessoa)?
func _clear_of_solids(p: Vector2) -> bool:
	var probe := Rect2(p - Vector2(24, 24), Vector2(48, 48))
	for wall in walls:
		if probe.intersects(wall):
			return false
	for item in items:
		if item.solid and probe.intersects(item.rect):
			return false
	return true


## O móvel cairia em cima de uma vaga de NPC ou de uma zona de serviço?
func _blocks_people_or_services(rect: Rect2) -> bool:
	for slot in npc_slots:
		if rect.grow(30.0).has_point(slot.position):
			return true
	for z in zones:
		if rect.intersects(z.rect):
			return true
	return false


## Gente mínima por tamanho de interior (funcionários, clientes e moradores contam) e o papel
## dos visitantes que completam o mínimo.
const MIN_PEOPLE := {"P": 4, "M": 8, "G": 12}
const GUEST_ROLES := {
	"shop": ["cliente"], "hotel": ["hóspede"], "restaurant": ["cliente"], "bar": ["frequentador"],
	"club": ["dançarino"], "bank": ["cliente"], "police": ["visitante"], "hospital": ["paciente", "acompanhante"],
	"workshop": ["cliente"], "cinema": ["espectador"], "gym": ["aluno"], "office": ["visitante"],
	"home": ["morador"], "agent_home": ["visitante"], "warehouse": ["estoquista"], "hq": ["cliente"],
}
## Modelos densos que nunca passam de certo tamanho, mesmo com fachada larga (o espaço fica cheio).
const MAX_SIZE := {"police": "M", "hospital": "M"}
const MIN_SIZE := {"police": "M", "hospital": "M", "agent_home": "M"}
## Tipos que usam o modelo num tamanho menor que o base.
const SMALLER := ["diner"]

var building_id: int
var type: String
var template: String
var size_class: String
var size: Vector2
var mirrored := false
var base_floor: String
## Loja deste interior ("" se não for loja) e o balcão dela.
var shop := ""
var is_shop := false
var counter := Rect2()
## Cômodos: {name:String, rect:Rect2, floor:String}
var rooms: Array[Dictionary] = []
## Paredes internas (sólidas).
var walls: Array[Rect2] = []
## Móveis: {kind:String, rect:Rect2, solid:bool}
var items: Array[Dictionary] = []
## Retângulos dos móveis sólidos (atalho para colisão e testes).
var furniture: Array[Rect2] = []
## Vagas de NPC: {role:String, position:Vector2, staff:bool}
var npc_slots: Array[Dictionary] = []
## Zonas de serviço: {id:String, rect:Rect2, verb:String}
var zones: Array[Dictionary] = []
## Interior lido de uma planta em mapa de texto (Plans)? Os demais usam os construtores abaixo.
var planned := false
## Só nas plantas: pisos por trecho {rect, floor}, faces de parede {rect, style}, vãos de porta
## e a variante de cores sorteada.
var floor_rects: Array = []
var wall_faces: Array = []
var doors: Array = []
var variant := 0
var _exit := Rect2()
var _spawn := Vector2.ZERO

var _rng := RandomNumberGenerator.new()


func _init(p_building_id: int = 0, p_type := "", facade_width := DEFAULT_FACADE) -> void:
	building_id = p_building_id
	type = p_type
	template = template_of(p_type)
	size_class = size_class_for(p_type, facade_width)
	size = SIZES[size_class]
	base_floor = FLOORS[template]
	shop = BuildingDefs.shop_of(p_type) if BuildingDefs.exists(p_type) else (p_type if ShopDefs.exists(p_type) else "")
	is_shop = shop != ""
	if Plans.has(p_type):
		_load_plan(Plans.data(p_type))
		return
	_rng.seed = p_building_id * 7919 + 13
	mirrored = _rng.randf() < 0.5
	match template:
		"shop":
			_build_shop()
		"hotel":
			_build_hotel()
		"restaurant":
			_build_restaurant()
		"bar":
			_build_bar()
		"club":
			_build_club()
		"bank":
			_build_bank()
		"police":
			_build_police()
		"hospital":
			_build_hospital()
		"workshop":
			_build_workshop()
		"cinema":
			_build_cinema()
		"gym":
			_build_gym()
		"office":
			_build_office()
		"warehouse":
			_build_warehouse()
		"hq":
			_build_hq()
		"agent_home":
			_build_agent_home()
		_:
			_build_home()
	if mirrored:
		_mirror()
	_refresh_furniture()
	# a decoração e a gente extra entram depois do espelhamento: a validação de alcance usa a
	# planta final (a grade de 32 px não é simétrica ao espelhar)
	_dress()


## Monta o interior a partir da planta (sem decoração sorteada nem gente extra).
func _load_plan(plan: Dictionary) -> void:
	var parsed := PlanParser.parse(plan, building_id)
	planned = true
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
	_exit = parsed.exit
	_spawn = parsed.spawn
	if not floor_rects.is_empty():
		base_floor = floor_rects[0].floor
	_refresh_furniture()


# --- consultas ---

static func is_planned(p_type: String) -> bool:
	return Plans.has(p_type)


static func template_of(p_type: String) -> String:
	return TEMPLATES.get(p_type, DEFAULT_TEMPLATE)


## Tamanho do interior: o base do modelo, ajustado pela largura da fachada.
static func size_class_for(p_type: String, facade_width := DEFAULT_FACADE) -> String:
	if Plans.has(p_type):
		return Plans.data(p_type).size
	var index := SIZE_ORDER.find(BASE_SIZE[template_of(p_type)])
	if SMALLER.has(p_type):
		index -= 1
	var cap := SIZE_ORDER.find(MAX_SIZE.get(template_of(p_type), "G"))
	if facade_width < NARROW_FACADE:
		index -= 1
	elif facade_width >= WIDE_FACADE:
		index += 1
	var floor_index := SIZE_ORDER.find(MIN_SIZE.get(template_of(p_type), "P"))
	return SIZE_ORDER[clampi(index, floor_index, cap)]


func room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func exit_door() -> Rect2:
	if planned:
		return _exit
	return Rect2(size.x / 2.0 - EXIT_WIDTH / 2.0, size.y - EXIT_DEPTH, EXIT_WIDTH, EXIT_DEPTH)


func spawn_point() -> Vector2:
	if planned:
		return _spawn
	return Vector2(size.x / 2.0, size.y - 80.0)


## Área em frente à saída que fica sempre livre de móveis e paredes.
func clear_zone() -> Rect2:
	if planned:
		return Rect2(_exit.position.x, size.y - 3.0 * PlanParser.CELL, _exit.size.x, 3.0 * PlanParser.CELL)
	return Rect2(size.x / 2.0 - 160.0, size.y - 260.0, 320.0, 260.0)


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


## Tudo o que é sólido: paredes internas e móveis sólidos.
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


# --- ajudantes de construção ---

func _room(room_name: String, rect: Rect2, room_floor: String) -> void:
	rooms.append({"name": room_name, "rect": rect, "floor": room_floor})


## Parede horizontal em `y`, de x0 a x1, com vãos de porta centrados em cada valor de `gaps`.
func _wall_h(y: float, x0: float, x1: float, gaps := []) -> void:
	for span in _split(x0, x1, gaps):
		walls.append(Rect2(span[0], y, span[1] - span[0], WALL_T))


func _wall_v(x: float, y0: float, y1: float, gaps := []) -> void:
	for span in _split(y0, y1, gaps):
		walls.append(Rect2(x, span[0], WALL_T, span[1] - span[0]))


static func _split(from: float, to: float, gaps: Array) -> Array:
	var sorted := gaps.duplicate()
	sorted.sort()
	var spans := []
	var cursor := from
	for g in sorted:
		var a: float = float(g) - GAP / 2.0
		var b: float = float(g) + GAP / 2.0
		if a - cursor > 1.0:
			spans.append([cursor, a])
		cursor = maxf(cursor, b)
	if to - cursor > 1.0:
		spans.append([cursor, to])
	return spans


## Coloca um móvel. Recusa (e devolve false) o que sai da sala, invade a área da saída ou
## encosta em outro móvel sólido ou em parede.
func _put(kind: String, rect: Rect2, solid := true) -> bool:
	rect = Rect2(snappedf(rect.position.x, 2.0), snappedf(rect.position.y, 2.0), snappedf(rect.size.x, 2.0), snappedf(rect.size.y, 2.0))
	if not room_rect().encloses(rect):
		return false
	if solid:
		if rect.intersects(clear_zone()) or rect.intersects(_mirror_rect(clear_zone())):
			return false
		for wall in walls:
			if rect.intersects(wall):
				return false
		for item in items:
			if item.solid and rect.intersects(item.rect):
				return false
	items.append({"kind": kind, "rect": rect, "solid": solid, "layer": "floor", "tone": ""})
	return true


func _slot(role: String, position: Vector2, staff := true) -> void:
	npc_slots.append({"role": role, "position": position, "staff": staff, "act": "post", "route": [], "facing": "down"})


func _zone(id: String, rect: Rect2, verb := "") -> void:
	zones.append({"id": id, "rect": rect, "verb": verb if verb != "" else Services.verb(id)})


## Balcão com atendente atrás (ao norte) e zona de serviço na frente (ao sul).
func _service_counter(rect: Rect2, role: String, zone_id := "", verb := "") -> void:
	_put("counter", rect)
	_slot(role, Vector2(rect.get_center().x, rect.position.y - 30.0))
	if zone_id != "":
		_zone(zone_id, Rect2(rect.position.x, rect.end.y, rect.size.x, ZONE_DEPTH), verb)


## Papel do funcionário `index` deste tipo de prédio.
func _role(index := 0) -> String:
	var staff: Array = BuildingDefs.staff_of(type)
	if staff.is_empty():
		return "atendente"
	return staff[index % staff.size()]


## Vagas de clientes: sorteia `count` pontos da lista (sem repetir).
func _guests(role: String, points: Array, min_count: int, max_count: int) -> void:
	var pool: Array = []
	for point in points:
		if _clear_of_solids(point):
			pool.append(point)
	var count := mini(_rng.randi_range(min_count, max_count), pool.size())
	for i in count:
		var pick := _rng.randi_range(0, pool.size() - 1)
		_slot(role, pool[pick], false)
		pool.remove_at(pick)


func _mirror_rect(rect: Rect2) -> Rect2:
	return Rect2(size.x - rect.end.x, rect.position.y, rect.size.x, rect.size.y)


func _mirror() -> void:
	for i in walls.size():
		walls[i] = _mirror_rect(walls[i])
	for item in items:
		item.rect = _mirror_rect(item.rect)
	for room in rooms:
		room.rect = _mirror_rect(room.rect)
	for z in zones:
		z.rect = _mirror_rect(z.rect)
	for slot in npc_slots:
		slot.position = Vector2(size.x - slot.position.x, slot.position.y)
	if counter.size.x > 0.0:
		counter = _mirror_rect(counter)


# --- modelos ---

## Loja: depósito ao fundo, balcão com vendedor e prateleiras em fileiras.
func _build_shop() -> void:
	var w := size.x
	var h := size.y
	_room("Depósito", Rect2(0, 0, w, 120), "floor/concrete")
	_wall_h(120.0, 0.0, w, [w * 0.84])
	_put("crate", Rect2(80, 24, 96, 72))
	_put("crate", Rect2(200, 24, 96, 72))
	_put("crate", Rect2(w * 0.5, 24, 96, 72))
	counter = Rect2(w / 2.0 - 180.0, 220.0, 360.0, 48.0)
	_put("counter", counter)
	_slot(_role(), merchant_position())
	var shop_label: String = ShopDefs.shop_name(shop) if shop != "" else "loja"
	_zone("shop", counter_zone(), "comprar: %s" % shop_label)
	var rows := _rng.randi_range(2, 3)
	var aisles: Array = []
	for row in rows:
		var y := 400.0 + row * 120.0
		if y + 40.0 > h - 60.0:
			break
		for x in [80.0, 280.0, w - 440.0, w - 240.0]:
			_put("shelf", Rect2(x, y, 160.0, 40.0))
		aisles.append(Vector2(260.0, y + 80.0))
		aisles.append(Vector2(w - 260.0, y + 80.0))
	_put("plant", Rect2(40, h - 110, 44, 44))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))
	_guests("cliente", aisles, 0, 2)


## Hotel: saguão ao sul, corredor central e quartos dos dois lados.
func _build_hotel() -> void:
	var w := size.x
	var h := size.y
	var lobby_y := snappedf(h * 0.58, 2.0)
	var left := w / 2.0 - 116.0     # parede esquerda do corredor
	var right := w / 2.0 + 100.0    # parede direita do corredor
	_room("Saguão", Rect2(0, lobby_y, w, h - lobby_y), "floor/marble")
	_room("Corredor", Rect2(left + WALL_T, 0, right - left - WALL_T, lobby_y), "floor/wood")
	_wall_h(lobby_y, 0.0, w, [w / 2.0])
	var per_side := _rng.randi_range(2, 3)
	var room_h := lobby_y / per_side
	var doors: Array = []
	var beds: Array = []
	for k in per_side:
		doors.append(k * room_h + room_h / 2.0)
		if k > 0:
			_wall_h(k * room_h, 0.0, left)
			_wall_h(k * room_h, right + WALL_T, w)
	_wall_v(left, 0.0, lobby_y, doors)
	_wall_v(right, 0.0, lobby_y, doors)
	for k in per_side:
		var top := k * room_h + 36.0
		_put("bed", Rect2(60, top, 128, 88))
		_put("nightstand", Rect2(200, top, 40, 40))
		_put("rug", Rect2(260, top + 60, 120, 72), false)
		_put("bed", Rect2(w - 188, top, 128, 88))
		_put("nightstand", Rect2(w - 240, top, 40, 40))
		_put("rug", Rect2(w - 380, top + 60, 120, 72), false)
		beds.append(Vector2(330, top + 150))
		beds.append(Vector2(w - 330, top + 150))
	_service_counter(Rect2(w * 0.63, lobby_y + 130.0, 320, 48), _role(), "sleep")
	_put("sofa", Rect2(w * 0.12, lobby_y + 140.0, 176, 64))
	_put("sofa", Rect2(w * 0.12, lobby_y + 300.0, 176, 64))
	_put("table", Rect2(w * 0.12 + 32.0, lobby_y + 226.0, 112, 56))
	_put("plant", Rect2(40, h - 110, 44, 44))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))
	_put("rug", Rect2(w / 2.0 - 120.0, lobby_y + 60.0, 240, 120), false)
	_guests("hóspede", beds, 1, 3)


## Restaurante e lanchonete: cozinha ao norte, balcão de passagem e mesas no salão.
func _build_restaurant() -> void:
	var w := size.x
	var h := size.y
	_room("Cozinha", Rect2(0, 0, w, 200), "floor/tile")
	_wall_h(200.0, 0.0, w, [w * 0.16])
	_put("stove", Rect2(w * 0.4, 30, 120, 60))
	_put("stove", Rect2(w * 0.4 + 140.0, 30, 120, 60))
	_put("fridge", Rect2(w * 0.72, 24, 64, 88))
	_put("shelf", Rect2(w * 0.8, 30, 160, 40))
	_slot(_role(2 if type == "restaurant" else 1), Vector2(w * 0.5, 140.0))
	_service_counter(Rect2(w / 2.0 - 180.0, 300.0, 360, 48), _role(1 if type == "restaurant" else 0),
		"meal" if type == "restaurant" else "snack")
	var seats: Array = []
	var y := 480.0
	while y + 72.0 < h - 60.0:
		for x in [w * 0.08, w * 0.26, w * 0.66, w * 0.84]:
			if _put("table", Rect2(x, y, 112, 72)):
				seats.append(Vector2(x + 56.0, y + 104.0))
		y += 176.0
	_put("plant", Rect2(40, 240, 44, 44))
	_put("plant", Rect2(w - 84, 240, 44, 44))
	_guests("cliente", seats, 2, 5)


## Bar: balcão comprido com banquetas, mesas, sinuca e jukebox.
func _build_bar() -> void:
	var w := size.x
	var h := size.y
	_put("bottle_shelf", Rect2(w * 0.25, 0, w * 0.5, 40))
	var bar := Rect2(w * 0.2, 230.0, w * 0.6, 48)
	_put("counter", bar)
	_slot(_role(0), Vector2(w / 2.0, bar.position.y - 30.0))
	_slot(_role(1), Vector2(w * 0.3, bar.position.y - 30.0))
	_zone("rumor", Rect2(w / 2.0 - 180.0, bar.end.y, 360, ZONE_DEPTH))
	var stools: Array = []
	var x := bar.position.x + 40.0
	while x < bar.end.x - 40.0:
		if absf(x - w / 2.0) > 200.0:
			_put("stool", Rect2(x - 16.0, bar.end.y + 12.0, 32, 32), false)
			stools.append(Vector2(x, bar.end.y + 60.0))
		x += 96.0
	_put("pool_table", Rect2(w * 0.72, h * 0.52, 176, 104))
	_put("jukebox", Rect2(w - 96.0, 340, 56, 72))
	var seats: Array = []
	for i in _rng.randi_range(2, 4):
		var tx := w * 0.08 + (i % 2) * 220.0
		var ty := h * 0.48 + (i / 2) * 190.0
		if _put("table", Rect2(tx, ty, 112, 72)):
			seats.append(Vector2(tx + 56.0, ty + 104.0))
	seats.append_array(stools)
	_guests("cliente", seats, 2, 5)


## Boate: pista de luzes, cabine do DJ, bar lateral e camarote com o informante.
func _build_club() -> void:
	var w := size.x
	var h := size.y
	var dance := Rect2(w * 0.3, h * 0.24, w * 0.4, h * 0.44)
	_room("Pista", dance, "floor/dance")
	_put("dj_booth", Rect2(w / 2.0 - 120.0, 64, 240, 72))
	_slot(_role(0), Vector2(w / 2.0, 34.0))
	_put("speaker", Rect2(dance.position.x - 80.0, 70, 64, 96))
	_put("speaker", Rect2(dance.end.x + 16.0, 70, 64, 96))
	_put("counter", Rect2(110, h * 0.32, 48, 320))
	_slot(_role(1), Vector2(64.0, h * 0.32 + 160.0))
	for i in 3:
		_put("stool", Rect2(176, h * 0.32 + 40.0 + i * 110.0, 32, 32), false)
	# Camarote à direita, fechado por paredes com um vão.
	var box_x := w * 0.8
	_room("Camarote", Rect2(box_x, h * 0.12, w - box_x, h * 0.5), "floor/carpet")
	_wall_h(h * 0.12, box_x, w)
	_wall_v(box_x, h * 0.12, h * 0.62, [h * 0.4])
	_wall_h(h * 0.62, box_x, w)
	_put("sofa", Rect2(w - 220.0, h * 0.18, 176, 64))
	_put("table", Rect2(w - 200.0, h * 0.3, 112, 72))
	_slot("informante", Vector2(w * 0.9, h * 0.46))
	_zone("informant", Rect2(w * 0.9 - 110.0, h * 0.46 + 24.0, 220, 100))
	_slot(_role(2), Vector2(w / 2.0 + 230.0, h - 130.0))
	var floor_points: Array = []
	for ix in 4:
		for iy in 3:
			floor_points.append(dance.position + Vector2(dance.size.x * (0.15 + ix * 0.23), dance.size.y * (0.2 + iy * 0.3)))
	_guests("cliente", floor_points, 4, 8)


## Banco: salão com guichês e cofre ao fundo.
func _build_bank() -> void:
	var w := size.x
	var h := size.y
	_room("Cofre", Rect2(0, 0, w, 180), "floor/concrete")
	_wall_h(180.0, 0.0, w, [w * 0.86])
	_put("vault", Rect2(w / 2.0 - 90.0, 20, 180, 120))
	_put("crate", Rect2(w * 0.2, 40, 96, 72))
	var desk := Rect2(w * 0.2, 300.0, w * 0.6, 48)
	_put("counter", desk)
	_slot(_role(0), Vector2(w * 0.35, desk.position.y - 30.0))
	_slot(_role(0), Vector2(w * 0.65, desk.position.y - 30.0))
	_zone("deposit", Rect2(w * 0.35 - 120.0, desk.end.y, 240, ZONE_DEPTH))
	_zone("withdraw", Rect2(w * 0.65 - 120.0, desk.end.y, 240, ZONE_DEPTH))
	_put("rope", Rect2(w * 0.5 - 8.0, desk.end.y + 100.0, 16, 160), false)
	_put("bench", Rect2(80, h * 0.5, 64, 176))
	_put("bench", Rect2(w - 144.0, h * 0.5, 64, 176))
	_put("plant", Rect2(40, 220, 44, 44))
	_put("plant", Rect2(w - 84, 220, 44, 44))
	_slot(_role(2), Vector2(w / 2.0 - 240.0, h - 130.0))
	_guests("cliente", [Vector2(w * 0.3, h * 0.6), Vector2(w * 0.7, h * 0.6), Vector2(w * 0.5, h * 0.52)], 1, 3)


## Delegacia: celas ao norte-oeste, sala dos agentes, sala do delegado, sala de provas e a
## recepção com o balcão ao sul.
func _build_police() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.46, 2.0)
	var cells_x := snappedf(w * 0.34, 2.0)
	var boss_x := snappedf(w * 0.76, 2.0)
	var bars_y := snappedf(h * 0.26, 2.0)
	var evidence_y := snappedf(h * 0.66, 2.0)
	var evidence_x := snappedf(w * 0.22, 2.0)
	_room("Celas", Rect2(0, 0, cells_x, back), "floor/concrete")
	_room("Sala dos agentes", Rect2(cells_x + WALL_T, 0, boss_x - cells_x - WALL_T, back), "floor/wood")
	_room("Delegado", Rect2(boss_x + WALL_T, 0, w - boss_x - WALL_T, back), "floor/carpet")
	_room("Provas", Rect2(0, evidence_y + WALL_T, evidence_x, h - evidence_y - WALL_T), "floor/concrete")
	_wall_h(back, 0.0, w, [w * 0.2, w * 0.55, w * 0.88])
	_wall_v(cells_x, 0.0, back, [h * 0.36])
	_wall_v(boss_x, 0.0, back, [h * 0.3])
	_wall_h(evidence_y, 0.0, evidence_x, [evidence_x * 0.5])
	_wall_v(evidence_x, evidence_y, h, [h * 0.84])
	# celas: grade, três beliches, privadas e presos
	_put("cell_bars", Rect2(0, bars_y, cells_x, WALL_T))
	var cell_w := cells_x / 3.0
	var prisoners: Array = []
	for i in 3:
		if i > 0:
			_wall_v(i * cell_w, 0.0, bars_y)
		_put("bunk", Rect2(i * cell_w + 28.0, 28, 96, 56))
		_put("toilet", Rect2(i * cell_w + cell_w - 56.0, 36, 28, 32))
		prisoners.append(Vector2(i * cell_w + cell_w * 0.5, bars_y - 56.0))
	_guests("preso", prisoners, 1, 3)
	# sala dos agentes: seis mesas com computador, quadro de casos e armários
	var desks: Array = []
	for ix in 3:
		for iy in 2:
			var d := Rect2(cells_x + 90.0 + ix * 250.0, 70.0 + iy * 190.0, 128, 64)
			if _put("desk", d):
				_put("computer", Rect2(d.position.x + 10.0, d.position.y + 8.0, 44, 32), false)
				desks.append(Vector2(d.get_center().x, d.end.y + 30.0))
	_put("board", Rect2(cells_x + 120.0, WALL_T, 240, 28), false)
	_put("file_cabinet", Rect2(boss_x - 70.0, 40, 48, 120))
	_put("water_cooler", Rect2(boss_x - 70.0, back - 100.0, 40, 52))
	_put("trash", Rect2(cells_x + 40.0, back - 72.0, 32, 32))
	_slot(_role(0), desks[0])
	_slot(_role(0), desks[2 % desks.size()])
	_slot(_role(1), desks[3 % desks.size()])
	_slot(_role(0), desks[5 % desks.size()])
	# sala do delegado
	var bx := boss_x + WALL_T
	var bw := w - bx
	_put("desk", Rect2(bx + bw * 0.2, 90, 200, 72))
	_put("computer", Rect2(bx + bw * 0.2 + 12.0, 98, 48, 36), false)
	_put("bookshelf", Rect2(bx + 24.0, 24, 140, 36))
	_put("file_cabinet", Rect2(w - 72.0, 40, 48, 120))
	_put("sofa", Rect2(bx + 30.0, back - 110.0, 144, 56))
	_put("plant", Rect2(w - 76.0, back - 80.0, 44, 44))
	_slot(_role(3), Vector2(bx + bw * 0.2 + 100.0, 200.0))
	# provas
	_put("locker", Rect2(24, evidence_y + 48.0, 48, 160))
	_put("shelf", Rect2(evidence_x - 72.0, evidence_y + 48.0, 40, 200))
	_put("crates", Rect2(110, h - 130.0, 72, 56))
	_slot(_role(4), Vector2(evidence_x * 0.5, evidence_y + 100.0))
	# recepção: balcão com policial, bancos, vitrine de avisos
	_service_counter(Rect2(w * 0.6, back + 130.0, 320, 48), _role(2), "deliver")
	_put("board", Rect2(w * 0.3, back + WALL_T, 220, 24), false)
	_put("bench", Rect2(w * 0.28, h * 0.72, 176, 56))
	_put("bench", Rect2(w * 0.28, h * 0.84, 176, 56))
	_put("bench", Rect2(w * 0.7, h * 0.78, 176, 56))
	_put("vending", Rect2(w - 100.0, back + 40.0, 56, 64))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))
	_put("plant", Rect2(evidence_x + 60.0, h - 110.0, 44, 44))
	_guests("visitante", [Vector2(w * 0.28 + 88.0, h * 0.72 + 90.0), Vector2(w * 0.7 + 88.0, h * 0.78 + 90.0)], 1, 2)


## Hospital completo: enfermaria, UTI e dois consultórios ao norte; recepção com balcão ao sul,
## farmácia e sala de raio-X nos cantos. Equipe de branco e pacientes de camisola.
func _build_hospital() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.46, 2.0)
	var ward_x := snappedf(w * 0.42, 2.0)
	var icu_x := snappedf(w * 0.66, 2.0)
	var half := snappedf(back * 0.5, 2.0)
	var shop_y := snappedf(h * 0.66, 2.0)
	var pharm_x := snappedf(w * 0.2, 2.0)
	var xray_x := snappedf(w * 0.78, 2.0)
	_room("Enfermaria", Rect2(0, 0, ward_x, back), "floor/tile")
	_room("UTI", Rect2(ward_x + WALL_T, 0, icu_x - ward_x - WALL_T, back), "floor/marble")
	_room("Consultório 1", Rect2(icu_x + WALL_T, 0, w - icu_x - WALL_T, half), "floor/wood")
	_room("Consultório 2", Rect2(icu_x + WALL_T, half + WALL_T, w - icu_x - WALL_T, back - half - WALL_T), "floor/wood")
	_room("Farmácia", Rect2(0, shop_y + WALL_T, pharm_x, h - shop_y - WALL_T), "floor/tile")
	_room("Raio-X", Rect2(xray_x + WALL_T, shop_y + WALL_T, w - xray_x - WALL_T, h - shop_y - WALL_T), "floor/marble")
	_wall_h(back, 0.0, w, [w * 0.18, w * 0.54, w * 0.86])
	_wall_v(ward_x, 0.0, back, [back * 0.6])
	_wall_v(icu_x, 0.0, back, [back * 0.28])
	_wall_h(half, icu_x, w, [w * 0.83])
	_wall_h(shop_y, 0.0, pharm_x, [pharm_x * 0.5])
	_wall_v(pharm_x, shop_y, h, [h * 0.85])
	_wall_h(shop_y, xray_x, w, [xray_x + (w - xray_x) * 0.5])
	_wall_v(xray_x, shop_y, h, [h * 0.85])
	# enfermaria: duas fileiras de leitos com cortinas, carrinho e equipe
	var bedsides: Array = []
	var x := 70.0
	while x + 90.0 < ward_x - 60.0:
		if _put("hospital_bed", Rect2(x, 36, 80, 136)):
			bedsides.append(Vector2(x + 40.0, 214.0))
		_put("screen_divider", Rect2(x + 100.0, 36, 16, 120))
		if _put("hospital_bed", Rect2(x, back - 176.0, 80, 136)):
			bedsides.append(Vector2(x + 40.0, back - 214.0))
		_put("screen_divider", Rect2(x + 100.0, back - 160.0, 16, 120))
		x += 210.0
	_put("cart", Rect2(ward_x - 90.0, back * 0.5 - 20.0, 56, 44))
	_put("sink", Rect2(ward_x - 70.0, 40, 40, 36))
	_slot(_role(1), Vector2(ward_x * 0.5, back * 0.5))
	_slot(_role(5), Vector2(ward_x * 0.3, back * 0.5 + 10.0))
	# UTI: leitos com monitores
	var icu_w := icu_x - ward_x - WALL_T
	for i in 3:
		var bx := ward_x + WALL_T + 50.0 + i * (icu_w - 100.0) / 3.0
		if _put("hospital_bed", Rect2(bx, 60, 80, 136)):
			_put("monitor", Rect2(bx + 90.0, 60, 40, 40))
			bedsides.append(Vector2(bx + 40.0, 236.0))
	_put("cart", Rect2(ward_x + WALL_T + 40.0, back - 100.0, 56, 44))
	_slot(_role(0), Vector2(ward_x + WALL_T + icu_w * 0.5, back - 90.0))
	# consultórios: mesa com computador, maca, armários
	for i in 2:
		var top := 0.0 if i == 0 else half + WALL_T
		var room_h := half if i == 0 else back - half - WALL_T
		var rx := icu_x + WALL_T
		_put("desk", Rect2(rx + 40.0, top + room_h * 0.4, 150, 60))
		_put("computer", Rect2(rx + 52.0, top + room_h * 0.4 + 8.0, 44, 32), false)
		_put("hospital_bed", Rect2(w - 120.0, top + 40.0, 80, 120))
		_put("file_cabinet", Rect2(rx + 20.0, top + 24.0, 48, 60))
		_put("cabinet", Rect2(w - 90.0, top + room_h - 100.0, 64, 80))
		_slot(_role(0), Vector2(rx + 115.0, top + room_h * 0.4 + 100.0))
	# recepção
	var desk_y := snappedf(h * 0.68, 2.0)
	_service_counter(Rect2(w * 0.58, desk_y, 320, 48), _role(2), "heal")
	_put("computer", Rect2(w * 0.58 + 20.0, desk_y + 8.0, 44, 32), false)
	var seats: Array = []
	for row in 3:
		for col in 2:
			var bench := Rect2(w * 0.26 + col * 240.0, h * (0.68 + row * 0.1), 176, 56)
			if _put("bench", bench):
				seats.append(bench.get_center() + Vector2(0, 56.0))
	_put("vending", Rect2(w * 0.78 - 140.0, back + 40.0, 56, 64))
	_put("water_cooler", Rect2(w * 0.78 - 70.0, back + 40.0, 40, 52))
	_put("plant", Rect2(w * 0.24, back + 40.0, 44, 44))
	_put("plant", Rect2(w * 0.74, h * 0.9, 44, 44))
	_put("trash", Rect2(w * 0.74, h * 0.8, 32, 32))
	# farmácia: balcão, prateleiras de remédios
	_put("counter", Rect2(pharm_x * 0.2, shop_y + 90.0, pharm_x * 0.6, 44))
	_put("bottle_shelf", Rect2(24, shop_y + 40.0, 40, 130))
	_slot(_role(3), Vector2(pharm_x * 0.5, shop_y + 62.0))
	# raio-X
	_put("xray", Rect2(xray_x + 60.0, shop_y + 50.0, 130, 100))
	_put("hospital_bed", Rect2(w - 120.0, shop_y + 50.0, 80, 130))
	_put("monitor", Rect2(xray_x + 60.0, h - 110.0, 40, 40))
	_slot(_role(4), Vector2(xray_x + 120.0, shop_y + 200.0))
	_guests("paciente", bedsides, 2, 5)
	_guests("paciente", seats, 1, 3)


## Oficina: baia única com elevador, bancada, pneus e ferramentas.
func _build_workshop() -> void:
	var w := size.x
	var h := size.y
	_put("car_lift", Rect2(w / 2.0 - 96.0, 130, 192, 320))
	_put("workbench", Rect2(60, 80, 64, 380))
	_put("tires", Rect2(w - 170.0, 80, 104, 104))
	_put("tires", Rect2(w - 170.0, 200, 104, 104))
	_put("toolbox", Rect2(w * 0.3, 60, 88, 56))
	_put("crate", Rect2(w * 0.68, 60, 96, 72))
	_service_counter(Rect2(w * 0.68, h * 0.52, 300, 48), _role(0), "paint")
	_slot(_role(1), Vector2(170.0, h * 0.35))
	_put("oil_stain", Rect2(w * 0.3, h * 0.6, 96, 64), false)
	_put("oil_stain", Rect2(w / 2.0 - 40.0, 480, 80, 48), false)


## Cinema: bilheteria no saguão e sala com poltronas e tela.
func _build_cinema() -> void:
	var w := size.x
	var h := size.y
	var lobby_y := snappedf(h * 0.62, 2.0)
	_room("Sala de exibição", Rect2(0, 0, w, lobby_y), "floor/concrete")
	_wall_h(lobby_y, 0.0, w, [w / 2.0])
	_put("movie_screen", Rect2(w * 0.2, 0, w * 0.6, 32))
	var aisle_points: Array = []
	var y := 170.0
	while y + 48.0 < lobby_y - 90.0:
		_put("seats", Rect2(w * 0.12, y, w * 0.3, 48))
		_put("seats", Rect2(w * 0.58, y, w * 0.3, 48))
		aisle_points.append(Vector2(w * 0.06, y + 24.0))
		aisle_points.append(Vector2(w * 0.94, y + 24.0))
		y += 112.0
	_service_counter(Rect2(w * 0.63, lobby_y + 120.0, 320, 48), _role(0), "movie")
	_put("popcorn", Rect2(w * 0.2, lobby_y + 90.0, 64, 88))
	_put("bench", Rect2(w * 0.1, h - 150.0, 176, 56))
	_put("poster", Rect2(w * 0.3, lobby_y + WALL_T, 96, 24), false)
	_put("poster", Rect2(w * 0.76, lobby_y + WALL_T, 96, 24), false)
	_slot(_role(1), Vector2(w / 2.0 + 120.0, lobby_y - 60.0))
	_guests("espectador", aisle_points, 2, 6)


## Academia: salão com ringue e aparelhos, vestiário ao lado.
func _build_gym() -> void:
	var w := size.x
	var h := size.y
	var split := snappedf(w * 0.78, 2.0)
	_room("Vestiário", Rect2(split + WALL_T, 0, w - split - WALL_T, h), "floor/tile")
	_wall_v(split, 0.0, h, [h * 0.35])
	_put("locker", Rect2(w - 80.0, 60, 48, 420))
	_put("bench", Rect2(split + 80.0, h * 0.6, 64, 176))
	_put("ring", Rect2(w * 0.07, 90, 300, 300))
	var spots: Array = []
	var count := _rng.randi_range(2, 4)
	for i in count:
		var t := Rect2(w * 0.4 + i * 110.0, 70, 72, 140)
		if _put("treadmill", t):
			spots.append(Vector2(t.get_center().x, t.end.y + 40.0))
	_put("weights", Rect2(w * 0.4, 420, 220, 56))
	_put("weights", Rect2(w * 0.4, 540, 220, 56))
	spots.append(Vector2(w * 0.4 + 110.0, 500.0))
	spots.append(Vector2(w * 0.07 + 150.0, 430.0))
	_service_counter(Rect2(w * 0.1, h * 0.68, 300, 48), _role(0), "train")
	_slot(_role(1), Vector2(w * 0.62, h * 0.72))
	_guests("aluno", spots, 1, 4)


## Escritório: recepção ao sul, baias e sala do chefe ao norte.
func _build_office() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.5, 2.0)
	var boss_x := snappedf(w * 0.72, 2.0)
	_room("Baias", Rect2(0, 0, boss_x, back), "floor/carpet")
	_room("Sala do chefe", Rect2(boss_x + WALL_T, 0, w - boss_x - WALL_T, back), "floor/wood")
	_wall_h(back, 0.0, w, [w * 0.5])
	_wall_v(boss_x, 0.0, back, [h * 0.32])
	_put("desk", Rect2(w * 0.8, 100, 180, 72))
	_put("cabinet", Rect2(w - 110.0, 240, 64, 104))
	_put("plant", Rect2(boss_x + 40.0, 30, 44, 44))
	_slot(_role(2), Vector2(w * 0.8 + 90.0, 70.0))
	var seats: Array = []
	var y := 70.0
	while y + 64.0 < back - 110.0:
		var x := 70.0
		while x + 128.0 < boss_x - 60.0:
			if _put("desk", Rect2(x, y, 128, 64)):
				seats.append(Vector2(x + 64.0, y + 94.0))
			x += 230.0
		y += 170.0
	_put("cabinet", Rect2(boss_x - 90.0, back - 130.0, 64, 104))
	_service_counter(Rect2(w * 0.62, back + 130.0, 300, 48), _role(1))
	_put("sofa", Rect2(100, back + 140.0, 176, 64))
	_put("water_cooler", Rect2(100, back + 40.0, 40, 48))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))
	_guests(_role(0), seats, 2, 5)
	for slot in npc_slots:
		slot.staff = true


## Moradia: sala, quarto, banheiro e cozinha.
func _build_home() -> void:
	var w := size.x
	var h := size.y
	var split := snappedf(w * 0.68, 2.0)
	var bed_y := snappedf(h * 0.4, 2.0)
	var bath_y := snappedf(h * 0.62, 2.0)
	var rx := split + WALL_T
	_room("Sala", Rect2(0, 0, split, h), "floor/wood")
	_room("Quarto", Rect2(rx, 0, w - rx, bed_y), "floor/carpet")
	_room("Banheiro", Rect2(rx, bed_y + WALL_T, w - rx, bath_y - bed_y - WALL_T), "floor/tile")
	_room("Cozinha", Rect2(rx, bath_y + WALL_T, w - rx, h - bath_y - WALL_T), "floor/tile")
	_wall_v(split, 0.0, h, [bed_y * 0.55, bed_y + (bath_y - bed_y) * 0.5, bath_y + (h - bath_y) * 0.5])
	_wall_h(bed_y, rx, w)
	_wall_h(bath_y, rx, w)
	# quarto
	_put("bed", Rect2(w - 200.0, 36, 128, 96))
	_put("nightstand", Rect2(w - 250.0, 36, 40, 40))
	_put("wardrobe", Rect2(rx + 24.0, 24, 112, 48))
	_put("rug", Rect2(rx + 90.0, bed_y * 0.45, 140, 80), false)
	_put("desk", Rect2(rx + 24.0, bed_y - 84.0, 96, 48))
	_put("computer", Rect2(rx + 30.0, bed_y - 78.0, 40, 28), false)
	# banheiro
	_put("toilet", Rect2(w - 70.0, bed_y + 40.0, 28, 36))
	_put("bathtub", Rect2(rx + 20.0, bed_y + 40.0, 96, 56))
	_put("sink", Rect2(w - 110.0, bath_y - 64.0, 40, 36))
	# cozinha
	_put("stove", Rect2(w - 150.0, bath_y + 50.0, 104, 56))
	_put("fridge", Rect2(rx + 20.0, bath_y + 50.0, 64, 88))
	_put("sink", Rect2(rx + 100.0, bath_y + 50.0, 56, 40))
	_put("table", Rect2(rx + 80.0, h - 150.0, 112, 72))
	_put("trash", Rect2(w - 70.0, h - 70.0, 32, 32))
	# sala
	_put("tv", Rect2(160, 24, 112, 40))
	_put("rug", Rect2(130, 110, 170, 120), false)
	_put("sofa", Rect2(128, 250, 176, 64))
	_put("table", Rect2(split * 0.58, 150, 112, 72))
	_put("bookshelf", Rect2(split - 80.0, 24, 56, 150))
	_put("plant", Rect2(40, 40, 44, 44))
	_put("plant", Rect2(split - 84.0, h * 0.5, 44, 44))
	_put("shelf", Rect2(40, h * 0.5, 40, 160))
	_put("coat_rack", Rect2(split - 80.0, h - 150.0, 36, 56))
	_guests("morador", [Vector2(split * 0.4, 380.0), Vector2(rx + 180.0, bed_y * 0.8), Vector2(split * 0.7, 300.0),
			Vector2(rx + 120.0, h - 80.0)], 1, 2)


## Casa do agente: sala com mural de casos, escritório com o baú de equipamento, quarto com a
## cama (dormir), cozinha e banheiro. É o refúgio do jogador.
func _build_agent_home() -> void:
	var w := size.x
	var h := size.y
	var mid_x := snappedf(w * 0.5, 2.0)
	var hall_y := snappedf(h * 0.72, 2.0)
	var office_y := snappedf(h * 0.36, 2.0)
	var bath_x := snappedf(w * 0.78, 2.0)
	_room("Sala", Rect2(0, 0, mid_x, hall_y), "floor/wood")
	_room("Escritório", Rect2(mid_x + WALL_T, 0, w - mid_x - WALL_T, office_y), "floor/carpet")
	_room("Quarto", Rect2(mid_x + WALL_T, office_y + WALL_T, w - mid_x - WALL_T, hall_y - office_y - WALL_T), "floor/carpet")
	_room("Cozinha", Rect2(0, hall_y + WALL_T, bath_x, h - hall_y - WALL_T), "floor/tile")
	_room("Banheiro", Rect2(bath_x + WALL_T, hall_y + WALL_T, w - bath_x - WALL_T, h - hall_y - WALL_T), "floor/tile")
	_wall_v(mid_x, 0.0, hall_y, [office_y * 0.6, office_y + (hall_y - office_y) * 0.5])
	_wall_h(office_y, mid_x, w, [mid_x + (w - mid_x) * 0.5])
	_wall_h(hall_y, 0.0, w, [mid_x * 0.5, mid_x + (w - mid_x) * 0.5])
	_wall_v(bath_x, hall_y, h, [hall_y + (h - hall_y) * 0.5])
	# sala: sofá, TV, mural de casos e estantes
	_put("tv", Rect2(mid_x * 0.35, 24, 140, 44))
	_put("rug", Rect2(mid_x * 0.25, 130, 280, 160), false)
	_put("sofa", Rect2(mid_x * 0.3, 330, 200, 64))
	_put("table", Rect2(mid_x * 0.3 + 40.0, 220, 120, 70))
	_put("board", Rect2(40, WALL_T, 220, 28), false)
	_put("bookshelf", Rect2(24, 80, 56, 200))
	_put("bookshelf", Rect2(mid_x - 84.0, 80, 56, 200))
	_put("plant", Rect2(40, hall_y - 90.0, 44, 44))
	_put("plant", Rect2(mid_x - 90.0, hall_y - 90.0, 44, 44))
	_put("coat_rack", Rect2(mid_x - 90.0, 330, 36, 56))
	# escritório: mesa de trabalho com dois monitores, arquivos e o baú
	var ox := mid_x + WALL_T
	_put("desk", Rect2(ox + 80.0, 90, 220, 72))
	_put("monitor", Rect2(ox + 96.0, 96, 40, 40), false)
	_put("monitor", Rect2(ox + 150.0, 96, 40, 40), false)
	_put("file_cabinet", Rect2(ox + 24.0, 24, 48, 120))
	_put("file_cabinet", Rect2(w - 72.0, 24, 48, 120))
	_put("chest", Rect2(w - 150.0, office_y - 90.0, 100, 56))
	_zone("stash", Rect2(w - 170.0, office_y - 90.0 + 56.0, 140, 70))
	_put("board", Rect2(ox + 340.0, WALL_T, 200, 28), false)
	# quarto: cama, criados-mudos, armários e tapete
	_put("bed", Rect2(w - 250.0, office_y + 70.0, 150, 110))
	_put("nightstand", Rect2(w - 296.0, office_y + 70.0, 40, 40))
	_put("nightstand", Rect2(w - 96.0, office_y + 70.0, 40, 40))
	_put("wardrobe", Rect2(ox + 24.0, office_y + 40.0, 120, 48))
	_put("wardrobe", Rect2(ox + 160.0, office_y + 40.0, 120, 48))
	_put("rug", Rect2(w - 300.0, office_y + 200.0, 220, 100), false)
	_zone("rest", Rect2(w - 270.0, office_y + 70.0 + 110.0, 190, 70))
	# cozinha
	_put("stove", Rect2(40, hall_y + 50.0, 104, 56))
	_put("fridge", Rect2(160, hall_y + 50.0, 64, 88))
	_put("sink", Rect2(240, hall_y + 50.0, 56, 40))
	_put("table", Rect2(60, h - 130.0, 130, 72))
	_put("trash", Rect2(320, hall_y + 50.0, 32, 32))
	_put("counter", Rect2(400, hall_y + 130.0, 360, 48))
	_put("rug", Rect2(mid_x * 0.62, h - 170.0, 300, 120), false)
	_put("table", Rect2(mid_x * 0.62 + 30.0, h - 150.0, 240, 80))
	_put("stool", Rect2(mid_x * 0.62 + 40.0, h - 190.0, 36, 36))
	_put("stool", Rect2(mid_x * 0.62 + 200.0, h - 190.0, 36, 36))
	_put("plant", Rect2(bath_x - 90.0, h - 90.0, 44, 44))
	_put("bookshelf", Rect2(bath_x - 90.0, hall_y + 36.0, 56, 100))
	# banheiro
	_put("bathtub", Rect2(bath_x + 40.0, hall_y + 40.0, 110, 60))
	_put("toilet", Rect2(w - 70.0, hall_y + 50.0, 28, 36))
	_put("sink", Rect2(w - 100.0, h - 70.0, 40, 36))


## Gentes extras e decoração: enche o espaço que os modelos deixam livre (parede a parede) e
## garante um mínimo de gente por tamanho de interior. Nada disso fecha um caminho: se a
## validação de alcance falhar, a decoração do lote é retirada (por inteiro ou pela metade).
func _dress() -> void:
	var decor: Array = DECOR.get(template, [])
	var items_before := items.size()
	var tries := [1.0, 0.5, 0.25]
	for share in tries:
		items.resize(items_before)
		_place_decor(decor, share)
		_refresh_furniture()
		if unreachable().is_empty():
			break
		items.resize(items_before)
	_refresh_furniture()
	if not unreachable().is_empty():
		items.resize(items_before)
		_refresh_furniture()
	_fill_to_minimum()


func _refresh_furniture() -> void:
	furniture.clear()
	for item in items:
		if item.solid:
			furniture.append(item.rect)


## Põe cada móvel da tabela de decoração rente a uma parede de algum cômodo.
func _place_decor(decor: Array, share: float) -> void:
	if rooms.is_empty():
		return
	for entry in decor:
		var count := roundi(_rng.randi_range(entry[3], entry[4]) * share)
		var placed := 0
		var attempts := 0
		while placed < count and attempts < 30:
			attempts += 1
			var room: Dictionary = rooms[_rng.randi_range(0, rooms.size() - 1)]
			var r: Rect2 = room.rect
			var item_w: float = entry[1]
			var item_h: float = entry[2]
			if r.size.x < item_w + 60.0 or r.size.y < item_h + 60.0:
				continue
			var spot := Vector2.ZERO
			match _rng.randi_range(0, 3):
				0:
					spot = Vector2(_rng.randf_range(r.position.x + 20.0, r.end.x - item_w - 20.0), r.position.y + 12.0)
				1:
					spot = Vector2(r.position.x + 12.0, _rng.randf_range(r.position.y + 20.0, r.end.y - item_h - 20.0))
				2:
					spot = Vector2(r.end.x - item_w - 12.0, _rng.randf_range(r.position.y + 20.0, r.end.y - item_h - 20.0))
				_:
					spot = Vector2(_rng.randf_range(r.position.x + 20.0, r.end.x - item_w - 20.0), r.end.y - item_h - 12.0)
			var rect := Rect2(spot, Vector2(item_w, item_h))
			if _blocks_people_or_services(rect):
				continue
			if _put(entry[0], rect):
				placed += 1


## Gente mínima por tamanho: o que o modelo não povoou é completado com visitantes em pontos livres.
func _fill_to_minimum() -> void:
	if template == "agent_home":
		return  # a casa do agente não recebe estranhos
	var minimum: int = MIN_PEOPLE[size_class]
	var attempts := 0
	while npc_slots.size() < minimum and attempts < 500:
		attempts += 1
		var p := Vector2(_rng.randf_range(80.0, size.x - 80.0), _rng.randf_range(80.0, size.y - 220.0))
		if _is_free_spot(p):
			_slot(_guest_role(), p, false)


func _guest_role() -> String:
	var roles: Array = GUEST_ROLES.get(template, ["visitante"])
	return roles[_rng.randi_range(0, roles.size() - 1)]


## O ponto está livre (fora de móveis, paredes, da saída e de outros NPCs) e dentro de um cômodo?
func _is_free_spot(p: Vector2) -> bool:
	var probe := Rect2(p - Vector2(22, 22), Vector2(44, 44))
	for wall in walls:
		if probe.intersects(wall):
			return false
	for item in items:
		if item.solid and probe.intersects(item.rect):
			return false
	if probe.intersects(clear_zone()) or probe.intersects(_mirror_rect(clear_zone())):
		return false
	for slot in npc_slots:
		if (slot.position as Vector2).distance_to(p) < 70.0:
			return false
	for z in zones:
		if probe.intersects(z.rect):
			return false
	for room in rooms:
		if (room.rect as Rect2).has_point(p):
			return true
	return rooms.is_empty()


## Armazém: galpão com pilhas de caixas, paletes e empilhadeira.
func _build_warehouse() -> void:
	var w := size.x
	var h := size.y
	var spots: Array = []
	var y := 110.0
	while y + 140.0 < h - 280.0:
		var x := 150.0
		while x + 160.0 < w - 120.0:
			if _rng.randf() < 0.75:
				_put("crates", Rect2(x, y, 160, 140))
			else:
				_put("pallet", Rect2(x + 16.0, y + 20.0, 128, 96), false)
				spots.append(Vector2(x + 80.0, y + 70.0))
			x += 330.0
		y += 290.0
	_put("forklift", Rect2(w * 0.8, h - 250.0, 96, 144))
	_put("crate", Rect2(80, h - 160.0, 96, 72))
	_put("crate", Rect2(190, h - 160.0, 96, 72))
	spots.append(Vector2(w * 0.3, h - 200.0))
	_guests(_role(0), spots, 0, 2)
	for slot in npc_slots:
		slot.staff = true


## QG: lavanderia na frente; a sala secreta fica atrás de uma máquina de lavar.
func _build_hq() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.5, 2.0)
	var secret := snappedf(w * 0.22, 2.0)
	_room("Sala secreta", Rect2(0, 0, w, back), "floor/concrete")
	_wall_h(back, 0.0, w, [secret])
	# A máquina que esconde a passagem não é sólida: o agente passa por ela.
	_put("washer_secret", Rect2(secret - GAP / 2.0, back - 28.0, GAP, 60), false)
	var x := secret + 140.0
	while x + 72.0 < w - 100.0:
		_put("washer", Rect2(x, back + WALL_T, 72, 72))
		x += 104.0
	_service_counter(Rect2(w * 0.63, back + 210.0, 320, 48), _role(0))
	_put("bench", Rect2(120, h * 0.72, 176, 56))
	_put("basket", Rect2(340, h * 0.72, 56, 56))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))
	_guests("cliente", [Vector2(w * 0.3, h * 0.82), Vector2(w * 0.8, h * 0.85)], 0, 1)
	# Sala secreta: mesa de briefing, telão, armários de equipamento e baú.
	_put("wall_screen", Rect2(w / 2.0 - 220.0, 0, 440, 32))
	var table := Rect2(w / 2.0 - 170.0, h * 0.2, 340, 120)
	_put("briefing_table", table)
	_slot("chefe da agência", Vector2(w / 2.0, table.position.y - 34.0))
	_zone("briefing", Rect2(table.position.x, table.end.y, table.size.x, ZONE_DEPTH))
	_put("locker", Rect2(60, 60, 48, 300))
	_put("chest", Rect2(w * 0.84, 70, 88, 60))
	_put("desk", Rect2(w * 0.7, back - 190.0, 160, 64))
	_put("rug", Rect2(w / 2.0 - 200.0, table.end.y + 10.0, 400, 110), false)
