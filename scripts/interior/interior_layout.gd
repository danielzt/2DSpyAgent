extends RefCounted
## Layout lógico de um interior (sem nós), gerado pela seed do id do prédio.
## Cada tipo de prédio usa um modelo de planta: cômodos com piso próprio, paredes internas
## com vãos de porta, móveis reconhecíveis, vagas de NPC com papel e zonas de serviço.
## A escala interna é bem maior que a externa (três tamanhos: P, M e G).
## Variação por seed: espelhamento horizontal e quantidade de mesas, quartos, prateleiras etc.

const Services := preload("res://scripts/interior/services.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")

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
	"house": "home", "farm": "home", "warehouse": "warehouse", "hq": "hq",
}
const DEFAULT_TEMPLATE := "home"
## Tamanho base e piso de cada modelo.
const BASE_SIZE := {
	"shop": "P", "hotel": "G", "restaurant": "M", "bar": "M", "club": "G", "bank": "M", "police": "G",
	"hospital": "G", "workshop": "M", "cinema": "G", "gym": "M", "office": "M", "home": "P",
	"warehouse": "G", "hq": "G",
}
const FLOORS := {
	"shop": "floor/tile", "hotel": "floor/carpet", "restaurant": "floor/wood", "bar": "floor/wood",
	"club": "floor/concrete", "bank": "floor/marble", "police": "floor/tile", "hospital": "floor/marble",
	"workshop": "floor/concrete", "cinema": "floor/carpet", "gym": "floor/wood", "office": "floor/tile",
	"home": "floor/wood", "warehouse": "floor/concrete", "hq": "floor/tile",
}
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
		_:
			_build_home()
	if mirrored:
		_mirror()
	for item in items:
		if item.solid:
			furniture.append(item.rect)


# --- consultas ---

static func template_of(p_type: String) -> String:
	return TEMPLATES.get(p_type, DEFAULT_TEMPLATE)


## Tamanho do interior: o base do modelo, ajustado pela largura da fachada.
static func size_class_for(p_type: String, facade_width := DEFAULT_FACADE) -> String:
	var index := SIZE_ORDER.find(BASE_SIZE[template_of(p_type)])
	if SMALLER.has(p_type):
		index -= 1
	if facade_width < NARROW_FACADE:
		index -= 1
	elif facade_width >= WIDE_FACADE:
		index += 1
	return SIZE_ORDER[clampi(index, 0, SIZE_ORDER.size() - 1)]


func room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func exit_door() -> Rect2:
	return Rect2(size.x / 2.0 - EXIT_WIDTH / 2.0, size.y - EXIT_DEPTH, EXIT_WIDTH, EXIT_DEPTH)


func spawn_point() -> Vector2:
	return Vector2(size.x / 2.0, size.y - 80.0)


## Área em frente à saída que fica sempre livre de móveis e paredes.
func clear_zone() -> Rect2:
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
	items.append({"kind": kind, "rect": rect, "solid": solid})
	return true


func _slot(role: String, position: Vector2, staff := true) -> void:
	npc_slots.append({"role": role, "position": position, "staff": staff})


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
	var pool := points.duplicate()
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


## Delegacia: recepção ao sul, sala dos agentes e celas ao norte.
func _build_police() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.45, 2.0)
	var cells_x := snappedf(w * 0.36, 2.0)
	var bars_y := snappedf(h * 0.24, 2.0)
	_room("Celas", Rect2(0, 0, cells_x, back), "floor/concrete")
	_room("Sala dos agentes", Rect2(cells_x + WALL_T, 0, w - cells_x - WALL_T, back), "floor/wood")
	_wall_h(back, 0.0, w, [w * 0.62])
	_wall_v(cells_x, 0.0, back, [h * 0.35])
	_put("cell_bars", Rect2(0, bars_y, cells_x, WALL_T))
	var cell_w := cells_x / 3.0
	for i in 3:
		if i > 0:
			_wall_v(i * cell_w, 0.0, bars_y)
		_put("bunk", Rect2(i * cell_w + 40.0, 30, 96, 56))
	var desks: Array = []
	for ix in 3:
		for iy in 2:
			var d := Rect2(w * 0.44 + ix * 260.0, 70.0 + iy * 200.0, 128, 64)
			if _put("desk", d):
				desks.append(Vector2(d.get_center().x, d.end.y + 30.0))
	_put("locker", Rect2(w - 90.0, 40, 48, 240))
	_slot(_role(0), desks[0])
	_slot(_role(1), desks[3 % desks.size()])
	_service_counter(Rect2(w * 0.62, back + 130.0, 320, 48), _role(2), "deliver")
	_put("board", Rect2(w * 0.18, back + WALL_T, 200, 24), false)
	_put("bench", Rect2(120, h * 0.7, 176, 56))
	_put("bench", Rect2(120, h * 0.82, 176, 56))
	_put("plant", Rect2(w - 84, h - 110, 44, 44))


## Hospital: recepção ao sul, enfermaria e consultório ao norte.
func _build_hospital() -> void:
	var w := size.x
	var h := size.y
	var back := snappedf(h * 0.45, 2.0)
	var split := snappedf(w * 0.58, 2.0)
	_room("Enfermaria", Rect2(0, 0, split, back), "floor/tile")
	_room("Consultório", Rect2(split + WALL_T, 0, w - split - WALL_T, back), "floor/wood")
	_wall_h(back, 0.0, w, [w * 0.3, w * 0.78])
	_wall_v(split, 0.0, back)
	var bedsides: Array = []
	var x := 80.0
	while x + 80.0 < split - 80.0:
		_put("hospital_bed", Rect2(x, 40, 80, 136))
		_put("screen_divider", Rect2(x + 110.0, 40, 16, 120))
		bedsides.append(Vector2(x + 40.0, 220.0))
		x += 230.0
	_put("desk", Rect2(w * 0.7, 90, 160, 64))
	_put("cabinet", Rect2(w - 110.0, 40, 64, 104))
	_put("hospital_bed", Rect2(split + 60.0, 60, 80, 136))
	_slot(_role(0), Vector2(w * 0.73, 190.0))
	_slot(_role(1), Vector2(split * 0.5, back - 80.0))
	_service_counter(Rect2(w * 0.6, back + 130.0, 320, 48), _role(2), "heal")
	_put("bench", Rect2(120, h * 0.68, 176, 56))
	_put("bench", Rect2(120, h * 0.82, 176, 56))
	_put("plant", Rect2(40, back + 40.0, 44, 44))
	_guests("paciente", bedsides, 1, 3)


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


## Moradia: sala, cozinha e quarto.
func _build_home() -> void:
	var w := size.x
	var h := size.y
	var split := snappedf(w * 0.66, 2.0)
	var mid := snappedf(h * 0.52, 2.0)
	_room("Quarto", Rect2(split + WALL_T, 0, w - split - WALL_T, mid), "floor/carpet")
	_room("Cozinha", Rect2(split + WALL_T, mid + WALL_T, w - split - WALL_T, h - mid - WALL_T), "floor/tile")
	_wall_v(split, 0.0, mid, [mid * 0.55])
	_wall_h(mid, split, w, [split + (w - split) * 0.3])
	_wall_v(split, mid, h, [mid + (h - mid) * 0.45])
	_put("bed", Rect2(w - 200.0, 40, 128, 88))
	_put("wardrobe", Rect2(split + 40.0, 24, 112, 48))
	_put("nightstand", Rect2(w - 250.0, 40, 40, 40))
	_put("rug", Rect2(split + 110.0, mid * 0.5, 140, 80), false)
	_put("tv", Rect2(160, 24, 112, 40))
	_put("sofa", Rect2(128, 250, 176, 64))
	_put("rug", Rect2(140, 110, 152, 110), false)
	_put("table", Rect2(split * 0.52, 140, 112, 72))
	_put("plant", Rect2(40, 40, 44, 44))
	_put("shelf", Rect2(40, h * 0.6, 40, 160))
	_put("stove", Rect2(w - 150.0, mid + 50.0, 104, 56))
	_put("fridge", Rect2(w - 110.0, mid + 140.0, 64, 88))
	_put("table", Rect2(split + 90.0, h - 190.0, 112, 72))
	_guests("morador", [Vector2(split * 0.4, 380.0), Vector2(split + 180.0, mid * 0.8), Vector2(split * 0.75, 300.0)], 0, 2)


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
