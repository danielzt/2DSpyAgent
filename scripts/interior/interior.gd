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
const SERVICE_TOAST_SECONDS := 7.0

var layout
var rng := RandomNumberGenerator.new()
## Céu atrás das janelas das plantas (recolorido a cada hora).
var _window_skies: Array[Sprite2D] = []
## Passagem secreta do QG (corpo sólido até abrir) e as sombras dos cômodos escondidos.
var secret_body: StaticBody2D
var _secret_open := false


func _ready() -> void:
	add_to_group(GameState.INTERIOR_GROUP)
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
		_add_solid(wall, "top")
	_add_wall_faces()
	for item in layout.items:
		if item.get("layer", "floor") != "on":
			_add_furniture(item)
	for item in layout.items:
		if item.get("layer", "floor") == "on":
			_add_furniture(item)   # depois dos móveis: fica por cima deles
	_add_exit_door()
	for z in layout.zones:
		_add_zone(z)
	_add_npcs()
	_add_secret_shadows()
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
	for sky in _window_skies:   # as janelas acompanham o céu
		sky.modulate = sky_color(WorldClock.hour())


## Semente do NPC da vaga `index` deste prédio.
static func npc_seed(building_id: int, index: int) -> int:
	return NPC_SEED_BASE + building_id * 131 + index * 7


## Cor do céu vista pelas janelas: o azul do dia tingido pela cor ambiente da hora.
static func sky_color(hour: float) -> Color:
	return Palette.get_color("sky") * DayCycle.ambient_color(hour)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	for part in layout.floor_rects:
		var r: Rect2 = part.rect
		draw_texture_rect(SpriteFactory.tile(part.floor), Rect2(r.position / TEXEL, r.size / TEXEL), true)
	_draw_doorways()
	var ink := Palette.get_color("ink")
	# Capacho e porta de saída.
	var door: Rect2 = layout.exit_door()
	var mat := Rect2(door.position.x / TEXEL, door.position.y / TEXEL - 8.0, door.size.x / TEXEL, 8.0)
	draw_rect(mat, Palette.get_color("red"))
	draw_rect(Rect2(mat.position.x, mat.position.y, mat.size.x, 1.0), Palette.get_color("wine"))
	draw_rect(Rect2(door.position / TEXEL, door.size / TEXEL), Palette.get_color("brown_dark"))
	draw_rect(Rect2(door.position.x / TEXEL, door.position.y / TEXEL, door.size.x / TEXEL, 1.0), ink)


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
	var tone: String = item.get("tone", "")
	var layer: String = item.get("layer", "floor")
	var texture := SpriteFactory.custom(FurnitureArt.cache_key(kind, w, h, tone),
		func() -> RefCounted: return FurnitureArt.canvas(kind, w, h, tone))
	var sprite := SpriteFactory.make_sprite(texture, rect.size / (2.0 * TEXEL))
	if layer == "wall":
		if kind == "window":
			_add_window_sky(rect)
		sprite.position = rect.get_center()
		sprite.z_index = FLOOR_ITEM_Z + 1
		sprite.add_to_group("wall_items")
		add_child(sprite)
		return
	if layer == "on":
		sprite.position = rect.get_center()
		sprite.z_index = SOLID_Z
		sprite.add_to_group("on_items")
		add_child(sprite)
		return
	if item.solid:
		var body := _make_body(rect)
		body.add_child(sprite)
		if item.get("secret", false):
			secret_body = body
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
	if material == "top":
		# topo de parede visto de cima (a altura aparece na face, logo abaixo)
		canvas.fill(Palette.get_color("shadow"))
		canvas.frame(0, 0, w, h, Palette.get_color("ink"))
		return canvas
	var tones: Array[Color] = Palette.ramp("wood") if material == "wood" else Palette.tone("gray")
	canvas.fill(tones[1])
	if h > 4 and w > 4:
		canvas.rect(1, 1, w - 2, 2, tones[2])
		canvas.rect(1, h - 4, w - 2, 3, tones[0])
	canvas.frame(0, 0, w, h, Palette.get_color("ink"))
	return canvas


## Faces das paredes (só visual, sem colisão): o padrão do cômodo repetido ao longo da parede.
func _add_wall_faces() -> void:
	for face in layout.wall_faces:
		var rect: Rect2 = face.rect
		var sprite := Sprite2D.new()
		sprite.texture = SpriteFactory.face(face.style)
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, rect.size / TEXEL)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.scale = Vector2(TEXEL, TEXEL)
		sprite.position = rect.position
		sprite.z_index = FLOOR_ITEM_Z
		sprite.add_to_group("wall_faces")
		add_child(sprite)


## Céu visto pela janela: fica atrás da moldura (o vidro da arte é transparente).
func _add_window_sky(rect: Rect2) -> void:
	var r := rect.grow(-TEXEL)
	var white := SpriteFactory.custom("interior/sky_px", func() -> RefCounted:
		var canvas: RefCounted = PixelCanvas.new(1, 1)
		canvas.fill(Palette.get_color("white"))
		return canvas)
	var sky := Sprite2D.new()
	sky.texture = white
	sky.centered = false
	sky.position = r.position
	sky.scale = r.size
	sky.modulate = sky_color(WorldClock.hour())   # tinta da hora, como o resto da iluminação
	sky.z_index = FLOOR_ITEM_Z + 1
	add_child(sky)
	_window_skies.append(sky)


## Sombra escura sobre cada cômodo escondido (a sala do QG) até a passagem abrir nesta visita.
func _add_secret_shadows() -> void:
	for rect in layout.hidden_rooms:
		var shade := Sprite2D.new()
		shade.texture = SpriteFactory.custom("interior/shadow_px", func() -> RefCounted:
			var canvas: RefCounted = PixelCanvas.new(1, 1)
			canvas.fill(Palette.get_color("ink"))
			return canvas)
		shade.centered = false
		shade.position = (rect as Rect2).position
		shade.scale = (rect as Rect2).size
		shade.z_index = 20   # acima de tudo dentro da sala, menos o HUD
		shade.add_to_group("secret_shadow")
		add_child(shade)


## Abre a passagem secreta: a máquina desliza (sem colisão) e a sala escondida aparece.
func open_secret() -> void:
	if _secret_open:
		return
	_secret_open = true
	if secret_body != null:
		(secret_body.get_child(0) as CollisionShape2D).set_deferred("disabled", true)
		secret_body.modulate = Color(1, 1, 1, 0.35)
	for shade in get_tree().get_nodes_in_group("secret_shadow"):
		shade.queue_free()


## Soleira nos vãos de porta internos das plantas.
func _draw_doorways() -> void:
	for door in layout.doors:
		var r := Rect2((door as Rect2).position / TEXEL, (door as Rect2).size / TEXEL)
		draw_rect(Rect2(r.position.x + 2.0, r.get_center().y - 1.0, r.size.x - 4.0, 2.0), Palette.get_color("brown_dark"))


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
	if id == "secret":
		open_secret()
		return {"result": "ok", "message": ""}
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
		npc.uniform_building = layout.type
		npc.uniform_staff = slot.staff
		npc.activity = slot.get("act", "post")
		npc.route = PackedVector2Array(slot.get("route", []))
		npc.facing = slot.get("facing", "down")
		npc.on_furniture = slot.get("on_item", false)
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
