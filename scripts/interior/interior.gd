extends Node2D
## Cena de interior de prédio. Monta os nós a partir do InteriorLayout do tipo do prédio:
## cômodos com piso próprio, paredes internas, móveis, NPCs com papel, zonas de serviço e a
## porta de saída. Os interiores têm iluminação própria (não escurecem com a noite); as
## janelas da parede norte mostram a cor do céu lá fora.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const Services := preload("res://scripts/interior/services.gd")
const DOOR_SCRIPT := preload("res://scripts/world/door.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
const CrimeProfiles := preload("res://scripts/crime/crime_profiles.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const ZONE_SCRIPT := preload("res://scripts/interaction/interact_zone.gd")
const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const FurnitureArt := preload("res://scripts/art/furniture_art.gd")

const WALL := 40.0
const TEXEL := 2.0
const FLOOR_ITEM_Z := 1
const SOLID_Z := 2
const NPC_SEED_BASE := 50000
const WINDOW_STEP := 420.0
const WINDOW_SIZE := Vector2(96.0, 14.0)
const SERVICE_TOAST_SECONDS := 7.0

var layout
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var id := maxi(GameState.building_id, 0)
	var type: String = GameState.building_type
	if type == "" and GameState.building_shop != "":
		type = GameState.building_shop   # chamada antiga: só o id da loja
	layout = InteriorLayout.new(id, type, GameState.building_width)
	rng.seed = id * 977 + 3
	var s: Vector2 = layout.size
	_add_solid(Rect2(-WALL, -WALL, s.x + WALL * 2.0, WALL), "wall")
	_add_solid(Rect2(-WALL, s.y, s.x + WALL * 2.0, WALL), "wall")
	_add_solid(Rect2(-WALL, 0, WALL, s.y), "wall")
	_add_solid(Rect2(s.x, 0, WALL, s.y), "wall")
	for wall in layout.walls:
		_add_solid(wall, "wall")
	for item in layout.items:
		_add_furniture(item)
	_add_exit_door()
	for z in layout.zones:
		_add_zone(z)
	_add_npcs()
	if layout.is_shop:
		_add_shop_sign()

	var player := PLAYER_SCENE.instantiate()
	player.player_index = 1
	player.region_name = "Interior"
	player.place_name = GameState.building_name
	player.position = layout.spawn_point()
	add_child(player)
	player.set_camera_limits(Rect2(Vector2.ZERO, s))
	WorldClock.hour_changed.connect(_on_hour_changed)
	queue_redraw()


func _exit_tree() -> void:
	if WorldClock.hour_changed.is_connected(_on_hour_changed):
		WorldClock.hour_changed.disconnect(_on_hour_changed)


func _on_hour_changed(_hour: int) -> void:
	queue_redraw()   # as janelas acompanham o céu


## Semente do NPC da vaga `index` deste prédio.
static func npc_seed(building_id: int, index: int) -> int:
	return NPC_SEED_BASE + building_id * 131 + index * 7


## Cor do céu vista pelas janelas: o azul do dia tingido pela cor ambiente da hora.
static func sky_color(hour: float) -> Color:
	return Palette.get_color("sky") * DayCycle.ambient_color(hour)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	var s: Vector2 = layout.size / TEXEL
	draw_texture_rect(SpriteFactory.tile(layout.base_floor), Rect2(Vector2.ZERO, s), true)
	for room in layout.rooms:
		var rect: Rect2 = room.rect
		draw_texture_rect(SpriteFactory.tile(room.floor), Rect2(rect.position / TEXEL, rect.size / TEXEL), true)
	# Rodapé escuro junto às paredes e janelas na parede norte.
	var ink := Palette.get_color("ink")
	draw_rect(Rect2(0, 0, s.x, 2), Palette.cast_shadow())
	draw_rect(Rect2(0, 0, 2, s.y), Palette.cast_shadow())
	var sky := sky_color(WorldClock.hour())
	for rect in window_rects():
		var r := Rect2(rect.position / TEXEL, rect.size / TEXEL)
		draw_rect(r, ink)
		draw_rect(r.grow(-1.0), sky)
		draw_rect(Rect2(r.get_center().x, r.position.y, 1.0, r.size.y), ink)
	# Capacho e porta de saída.
	var door: Rect2 = layout.exit_door()
	var mat := Rect2(door.position.x / TEXEL, door.position.y / TEXEL - 8.0, door.size.x / TEXEL, 8.0)
	draw_rect(mat, Palette.get_color("red"))
	draw_rect(Rect2(mat.position.x, mat.position.y, mat.size.x, 1.0), Palette.get_color("wine"))
	draw_rect(Rect2(door.position / TEXEL, door.size / TEXEL), Palette.get_color("brown_dark"))
	draw_rect(Rect2(door.position.x / TEXEL, door.position.y / TEXEL, door.size.x / TEXEL, 1.0), ink)


## Janelas ao longo da parede norte (px do interior), fora de móveis encostados nela.
func window_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var x := WINDOW_STEP / 2.0
	while x + WINDOW_SIZE.x < layout.size.x:
		var rect := Rect2(Vector2(x, 0.0), WINDOW_SIZE)
		var free := true
		for solid in layout.solids():
			if (solid as Rect2).intersects(rect):
				free = false
		if free:
			result.append(rect)
		x += WINDOW_STEP
	return result


## Corpo sólido com visual da fábrica de arte (parede).
func _add_solid(rect: Rect2, material: String) -> StaticBody2D:
	var body := _make_body(rect)
	var texture := SpriteFactory.custom("interior/%s/%dx%d" % [material, int(rect.size.x), int(rect.size.y)],
		func() -> RefCounted: return _block_canvas(rect.size, material))
	body.add_child(SpriteFactory.make_sprite(texture, rect.size / (2.0 * TEXEL)))
	body.z_index = SOLID_Z
	add_child(body)
	return body


func _make_body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.add_child(shape)
	return body


## Móvel: sólido (com colisão) ou só desenho no chão (tapete, banqueta, mancha).
func _add_furniture(item: Dictionary) -> void:
	var rect: Rect2 = item.rect
	var w := int(rect.size.x / TEXEL)
	var h := int(rect.size.y / TEXEL)
	var kind: String = item.kind
	var texture := SpriteFactory.custom(FurnitureArt.cache_key(kind, w, h),
		func() -> RefCounted: return FurnitureArt.canvas(kind, w, h))
	var sprite := SpriteFactory.make_sprite(texture, rect.size / (2.0 * TEXEL))
	if item.solid:
		var body := _make_body(rect)
		body.add_child(sprite)
		body.z_index = SOLID_Z
		body.add_to_group("furniture")
		body.set_meta("kind", kind)
		add_child(body)
	else:
		sprite.position = rect.get_center()
		sprite.z_index = FLOOR_ITEM_Z
		sprite.add_to_group("floor_items")
		add_child(sprite)


## Bloco com contorno, luz em cima e sombra embaixo (parede).
static func _block_canvas(size: Vector2, material: String) -> RefCounted:
	var w := maxi(int(size.x / TEXEL), 2)
	var h := maxi(int(size.y / TEXEL), 2)
	var canvas: RefCounted = PixelCanvas.new(w, h)
	var tones: Array[Color] = Palette.ramp("wood") if material == "wood" else Palette.tone("gray")
	canvas.fill(tones[1])
	if h > 4 and w > 4:
		canvas.rect(1, 1, w - 2, 2, tones[2])
		canvas.rect(1, h - 4, w - 2, 3, tones[0])
	canvas.frame(0, 0, w, h, Palette.get_color("ink"))
	return canvas


func _add_exit_door() -> void:
	var rect: Rect2 = layout.exit_door()
	var door := Area2D.new()
	door.set_script(DOOR_SCRIPT)
	door.exits = true
	door.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	door.add_child(shape)
	door.add_to_group("exit_doors")
	add_child(door)


## Zona de serviço: mostra o verbo no HUD e só age com a ação de interação.
func _add_zone(z: Dictionary) -> void:
	var rect: Rect2 = z.rect
	var zone := Area2D.new()
	zone.set_script(ZONE_SCRIPT)
	zone.verb = z.verb
	zone.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	zone.add_child(shape)
	zone.set_meta("service", z.id)
	zone.add_to_group("service_zones")
	var id: String = z.id
	if id == "shop":
		zone.verb = "comprar na %s" % ShopDefs.shop_name(layout.shop)
		zone.add_to_group("shop_zones")
	zone.interacted.connect(func(player: Node): use_service(id, player))
	add_child(zone)


## Executa o serviço da zona para o jogador e mostra o resultado no HUD.
func use_service(id: String, player: Node) -> Dictionary:
	if id == "shop":
		player.open_shop(layout.shop)
		return {"result": "ok", "message": ""}
	var result := Services.use(id, player, world_context())
	if result.message != "":
		player.notify(result.message, SERVICE_TOAST_SECONDS)
	return result


## O que os serviços precisam do mundo: relógio, estado global, pontuação e pistas.
func world_context() -> Dictionary:
	return {"clock": WorldClock, "state": GameState, "score": Score, "tip_provider": Callable(self, "_make_tip")}


func _make_tip() -> Dictionary:
	return CrimeProfiles.make_tip(GameState.world_layout(), rng, GameState.return_position, WorldClock.is_night())


## NPCs do interior: funcionários com o papel do tipo de prédio, moradores e clientes.
func _add_npcs() -> void:
	for i in layout.npc_slots.size():
		var slot: Dictionary = layout.npc_slots[i]
		var npc := NPC_SCENE.instantiate()
		npc.kind = "innocent"
		npc.ai_seed = npc_seed(layout.building_id, i)
		npc.stationary = true
		npc.uniform_role = slot.role
		npc.context = context_for(slot)
		npc.position = slot.position
		npc.set_meta("role", slot.role)
		npc.add_to_group("interior_npcs")
		add_child(npc)


## Contexto de identidade de quem ocupa a vaga: quem trabalha aqui diz onde trabalha;
## quem mora aqui diz onde mora.
func context_for(slot: Dictionary) -> Dictionary:
	var place: String = GameState.building_name
	if place == "":
		return {}
	if slot.staff:
		return {"role": slot.role, "work_name": place, "work_id": layout.building_id, "work_type": layout.type}
	if slot.role == "morador":
		return {"home_name": place, "home_id": layout.building_id}
	return {}


## Placa com o nome da loja e do vendedor, acima do balcão.
func _add_shop_sign() -> void:
	var merchant := NpcIdentity.generate(npc_seed(layout.building_id, 0))
	var sign := SpriteFactory.make_sprite(
		SpriteFactory.text("%s — %s" % [ShopDefs.shop_name(layout.shop), merchant.name], "cream"), Vector2.ZERO)
	var counter: Rect2 = layout.counter
	sign.position = Vector2(counter.get_center().x - sign.texture.get_width(), counter.position.y - 84.0)
	sign.z_index = 4
	sign.name = "ShopSign"
	add_child(sign)
