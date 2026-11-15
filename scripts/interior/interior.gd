extends Node2D
## Cena de interior de prédio: sala grande com móveis e porta de saída.
## Visual provisório no estilo novo (piso e móveis da fábrica de arte); os interiores
## por tipo de prédio chegam na Fase 3.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const DOOR_SCRIPT := preload("res://scripts/world/door.gd")
const WALL := 40.0
const TEXEL := 2.0
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
const ZONE_SCRIPT := preload("res://scripts/interaction/interact_zone.gd")
const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")

var layout


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var shop_id: String = GameState.building_shop
	layout = InteriorLayout.new(maxi(GameState.building_id, 0), shop_id != "")
	for rect in layout.furniture:
		_add_solid(rect, "wood")
	var s := InteriorLayout.SIZE
	_add_solid(Rect2(-WALL, -WALL, s.x + WALL * 2.0, WALL), "wall")
	_add_solid(Rect2(-WALL, s.y, s.x + WALL * 2.0, WALL), "wall")
	_add_solid(Rect2(-WALL, 0, WALL, s.y), "wall")
	_add_solid(Rect2(s.x, 0, WALL, s.y), "wall")
	_add_exit_door()
	if shop_id != "":
		_add_shop(shop_id)

	var player := PLAYER_SCENE.instantiate()
	player.player_index = 1
	player.region_name = "Interior"
	player.place_name = GameState.building_name
	player.position = InteriorLayout.spawn_point()
	add_child(player)
	player.set_camera_limits(Rect2(Vector2.ZERO, s))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	var s := InteriorLayout.SIZE / TEXEL
	var shop := GameState.building_shop != ""
	draw_texture_rect(SpriteFactory.tile("floor/tile" if shop else "floor/wood"), Rect2(Vector2.ZERO, s), true)
	# Rodapé escuro junto às paredes e capacho na saída.
	var ink := Palette.get_color("ink")
	draw_rect(Rect2(0, 0, s.x, 2), Palette.cast_shadow())
	draw_rect(Rect2(0, 0, 2, s.y), Palette.cast_shadow())
	var door := InteriorLayout.exit_door()
	var mat := Rect2(door.position.x / TEXEL, door.position.y / TEXEL - 8.0, door.size.x / TEXEL, 8.0)
	draw_rect(mat, Palette.get_color("red"))
	draw_rect(Rect2(mat.position.x, mat.position.y, mat.size.x, 1.0), Palette.get_color("wine"))
	draw_rect(Rect2(door.position / TEXEL, door.size / TEXEL), Palette.get_color("brown_dark"))
	draw_rect(Rect2(door.position.x / TEXEL, door.position.y / TEXEL, door.size.x / TEXEL, 1.0), ink)
	if shop:
		# Vendedor atrás do balcão.
		var look := CharacterSprites.civilian_look(GameState.building_id * 31 + 7)
		var texture := SpriteFactory.character(look, "down", 0)
		draw_texture(texture, InteriorLayout.merchant_position() / TEXEL - Vector2(CharacterSprites.PIVOT))


## Corpo sólido com visual da fábrica de arte. `material`: "wood" (móvel) ou "wall".
func _add_solid(rect: Rect2, material: String) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	body.add_child(shape)
	var texture := SpriteFactory.custom("interior/%s/%dx%d" % [material, int(rect.size.x), int(rect.size.y)],
		func() -> RefCounted: return _block_canvas(rect.size, material))
	body.add_child(SpriteFactory.make_sprite(texture, rect.size / (2.0 * TEXEL)))
	body.z_index = 2
	add_child(body)


## Bloco com contorno, luz em cima e sombra embaixo (móvel de madeira ou parede).
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
	var rect := InteriorLayout.exit_door()
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


## Balcão, vendedor e zona de compra.
func _add_shop(shop_id: String) -> void:
	_add_solid(InteriorLayout.COUNTER, "wood")
	var merchant := NpcIdentity.generate(GameState.building_id * 31 + 7)
	var sign := SpriteFactory.make_sprite(
		SpriteFactory.text("%s — %s" % [ShopDefs.shop_name(shop_id), merchant.name], "cream"), Vector2.ZERO)
	sign.position = Vector2(InteriorLayout.SIZE.x / 2.0 - sign.texture.get_width(), 96.0)
	sign.name = "ShopSign"
	add_child(sign)
	var zone_rect := InteriorLayout.counter_zone()
	var zone := Area2D.new()
	zone.set_script(ZONE_SCRIPT)
	zone.verb = "comprar na %s" % ShopDefs.shop_name(shop_id)
	zone.position = zone_rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = zone_rect.size
	shape.shape = rs
	zone.add_child(shape)
	zone.add_to_group("shop_zones")
	zone.interacted.connect(func(player: Node): player.open_shop(shop_id))
	add_child(zone)
