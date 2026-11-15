extends CanvasLayer
## Camada de luz do mundo externo. O CanvasModulate do mundo escurece tudo o que está na
## mesma camada; por isso as luzes ficam aqui, em uma camada própria que acompanha a câmera
## e não é tingida. Brilho aditivo barato (funciona no GL Compatibility e no browser);
## nenhuma Light2D.
## Contém: um par de nós por quarteirão (LightChunk: emissivo e brilho) e os faróis,
## lanternas e halos que seguem carros e jogadores.

const CityLayout := preload("res://scripts/world/city_layout.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const LightChunk := preload("res://scripts/world/light_chunk.gd")
const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const LIGHT_LAYER := 1          # acima do mundo (0), abaixo do HUD (10)
const STEPS_PER_HOUR := 4       # as luzes são reavaliadas a cada 15 min de jogo
const BLINK_SECONDS := 0.5
const HEADLIGHT_REACH := 46.0
const HEADLIGHT_SCALE := Vector2(3.2, 2.0)
const HEADLIGHT_ALPHA := 0.5
const TAILLIGHT_BACK := 24.0
const TAILLIGHT_SCALE := Vector2(0.9, 1.3)
const TAILLIGHT_ALPHA := 0.7
const HALO_SCALE := 4.0
const HALO_ALPHA := 0.22

var layout
var props
var additive: CanvasItemMaterial
## Vector2i -> {emissive: LightChunk, glow: LightChunk}
var chunks := {}

var _step := -1
var _blink := true
var _blink_timer := 0.0
var _blinkers: Array = []
## nó (carro ou jogador) -> sprites que o seguem
var _followers := {}


func setup(world_layout: RefCounted, props_layout: RefCounted) -> void:
	layout = world_layout
	props = props_layout


func _ready() -> void:
	layer = LIGHT_LAYER
	follow_viewport_enabled = true
	additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if layout == null:
		return
	var by_block := {}
	for b in layout.city.buildings:
		var block := Vector2i(
			int(floor((b.rect as Rect2).get_center().x / CityLayout.BLOCK)),
			int(floor((b.rect as Rect2).get_center().y / CityLayout.BLOCK)))
		if not by_block.has(block):
			by_block[block] = []
		by_block[block].append(b)
	for cx in CityLayout.CELLS:
		for cy in CityLayout.CELLS:
			var block := Vector2i(cx, cy)
			var pair := {}
			for mode in ["glow", "emissive"]:
				var chunk := Node2D.new()
				chunk.set_script(LightChunk)
				chunk.mode = mode
				chunk.buildings = by_block.get(block, [])
				chunk.props = props.for_block(block) if props != null else []
				if mode == "glow":
					chunk.material = additive
				chunk.add_to_group("light_chunks")
				add_child(chunk)
				pair[mode] = chunk
			chunks[block] = pair
			if pair["emissive"].has_blinker():
				_blinkers.append(pair)
	refresh(WorldClock.hour())


func _process(delta: float) -> void:
	var hour: float = WorldClock.hour()
	var step := int(hour * STEPS_PER_HOUR)
	if step != _step:
		refresh(hour)
	_blink_timer += delta
	if _blink_timer >= BLINK_SECONDS:
		_blink_timer = 0.0
		_blink = not _blink
		for pair in _blinkers:
			for mode in pair:
				pair[mode].refresh(hour, _blink)
	_update_followers(hour)


## Reavalia todas as luzes para a hora dada.
func refresh(hour: float) -> void:
	_step = int(hour * STEPS_PER_HOUR)
	for block in chunks:
		for mode in chunks[block]:
			chunks[block][mode].refresh(hour, _blink)


## Faróis e lanternas nos carros em movimento; halo fraco nos jogadores.
func _update_followers(hour: float) -> void:
	var headlights := DayCycle.light_on("headlight", hour)
	var halo := DayCycle.light_on("player", hour)
	for node in _followers.keys():
		if not is_instance_valid(node):
			for sprite in _followers[node]:
				sprite.queue_free()
			_followers.erase(node)
	if headlights:
		for car in get_tree().get_nodes_in_group("vehicles"):
			var sprites: Array = _sprites_for(car, 2)
			var on: bool = car.ai_controlled or is_instance_valid(car.driver)
			var forward := Vector2.RIGHT.rotated(car.global_rotation)
			_place(sprites[0], on, car.global_position + forward * HEADLIGHT_REACH, car.global_rotation, HEADLIGHT_SCALE, "cream", HEADLIGHT_ALPHA)
			_place(sprites[1], on, car.global_position - forward * TAILLIGHT_BACK, car.global_rotation, TAILLIGHT_SCALE, "red", TAILLIGHT_ALPHA)
	if halo:
		for player in get_tree().get_nodes_in_group("players"):
			var sprites: Array = _sprites_for(player, 1)
			_place(sprites[0], player.visible, player.global_position, 0.0, Vector2(HALO_SCALE, HALO_SCALE), "ice", HALO_ALPHA)
	for node in _followers:
		var is_car: bool = node.is_in_group("vehicles")
		if (is_car and not headlights) or (not is_car and not halo):
			for sprite in _followers[node]:
				sprite.visible = false


func _sprites_for(node: Node, count: int) -> Array:
	if not _followers.has(node):
		var list: Array = []
		for i in count:
			var sprite := Sprite2D.new()
			sprite.texture = SpriteFactory.custom("light/glow", func() -> RefCounted: return LightChunk.glow_canvas())
			sprite.material = additive
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.add_to_group("follow_lights")
			add_child(sprite)
			list.append(sprite)
		_followers[node] = list
	return _followers[node]


func _place(sprite: Sprite2D, on: bool, pos: Vector2, angle: float, size: Vector2, color_name: String, alpha: float) -> void:
	sprite.visible = on
	if not on:
		return
	sprite.global_position = pos
	sprite.rotation = angle
	sprite.scale = size
	var c := Palette.get_color(color_name)
	sprite.modulate = Color(c.r, c.g, c.b, alpha)


## Sprites de luz que seguem um nó (para testes).
func follower_sprites(node: Node) -> Array:
	return _followers.get(node, [])
