extends "res://tests/base_test.gd"
## Visual do mundo montado de verdade: chão por pedaços, prédios, personagens, carros,
## itens e HUD usando sprites da fábrica de arte (sem retângulos provisórios).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const BuildingArt := preload("res://scripts/art/building_art.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const PickupScript := preload("res://scripts/items/pickup.gd")
const BulletScript := preload("res://scripts/combat/bullet.gd")
const PixelLabel := preload("res://scripts/ui/pixel_label.gd")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	Input.action_release("p1_right")
	GameState.building_id = -1
	GameState.building_shop = ""
	GameState.has_return = false
	await wait_frames(2)


func _add(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func _start_main() -> Node:
	var main := _add(MAIN_SCENE.instantiate())
	for n in tree.get_nodes_in_group("npcs") + tree.get_nodes_in_group("traffic"):
		n.queue_free()
	await wait_physics_frames(2)
	return main


func _count_color_rects(node: Node) -> int:
	var total := 1 if node is ColorRect else 0
	for child in node.get_children():
		total += _count_color_rects(child)
	return total


# --- mundo ---

func test_ground_is_split_in_chunks_covering_the_world() -> void:
	var main := await _start_main()
	var size := WorldLayout.world_size()
	var expected := int(ceil(size.x / CityLayout.BLOCK)) * int(ceil(size.y / CityLayout.BLOCK))
	var chunks := tree.get_nodes_in_group("ground_chunks")
	assert_eq(chunks.size(), expected)
	var city_chunks := 0
	for c in chunks:
		if c.is_city():
			city_chunks += 1
			assert_true(c.chunk.x < CityLayout.CELLS and c.chunk.y < CityLayout.CELLS)
	assert_eq(city_chunks, CityLayout.CELLS * CityLayout.CELLS)
	assert_true(is_instance_valid(main))


func test_world_has_no_placeholder_rectangles() -> void:
	var main := await _start_main()
	assert_eq(_count_color_rects(main.get_node("World")), 0, "sobrou ColorRect no mundo")


func test_every_building_has_a_pixel_art_texture_of_its_size() -> void:
	await _start_main()
	var layout := WorldLayout.new()
	var bodies := tree.get_nodes_in_group("buildings")
	assert_eq(bodies.size(), layout.buildings().size())
	var by_center := {}
	for b in layout.buildings():
		by_center[(b.rect as Rect2).get_center()] = b
	for body in bodies:
		var visual: Sprite2D = body.get_node("Visual")
		assert_true(visual.texture != null)
		var b: Dictionary = by_center[body.position]
		assert_eq(Vector2i(visual.texture.get_size()), BuildingArt.canvas_size((b.rect as Rect2).size))
		assert_eq(visual.scale, Vector2(2, 2))
		# o canto da textura coincide com o canto do retângulo de colisão
		assert_eq(body.position + visual.offset * visual.scale, (b.rect as Rect2).position)


func test_building_textures_are_reused_between_scene_loads() -> void:
	var first := await _start_main()
	var texture: Texture2D = tree.get_nodes_in_group("buildings")[0].get_node("Visual").texture
	first.queue_free()
	await wait_frames(3)
	var builds := SpriteFactory.build_count()
	await _start_main()
	assert_eq(tree.get_nodes_in_group("buildings")[0].get_node("Visual").texture, texture)
	assert_eq(SpriteFactory.build_count(), builds, "recarregar o mundo não refaz texturas")


func test_agency_cars_look_different_from_traffic() -> void:
	var main := _add(MAIN_SCENE.instantiate())
	await wait_physics_frames(1)
	var layout := WorldLayout.new()
	var agency := 0
	for car in tree.get_nodes_in_group("vehicles"):
		assert_true(CarSprites.MODELS.has(car.model))
		if car.ai_controlled:
			assert_ne(car.model, "agent", "trânsito não usa o carro da agência")
		else:
			assert_eq(car.model, "agent")
			agency += 1
	assert_eq(agency, layout.vehicle_spawns().size())
	assert_true(is_instance_valid(main))


func test_draw_order_keeps_actors_above_buildings_and_under_treetops() -> void:
	await _start_main()
	var player = tree.get_nodes_in_group("players")[0]
	var building = tree.get_nodes_in_group("buildings")[0]
	var chunk = tree.get_nodes_in_group("ground_chunks")[0]
	assert_gt(player.z_index, building.z_index)
	assert_gt(building.z_index, chunk.z_index)
	assert_gt(chunk.get_child(0).z_index, player.z_index, "copas e postes ficam por cima")


# --- personagens ---

func test_player_uses_the_agent_sprite_and_turns_with_the_aim() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	assert_eq(player.get_node("Camera2D").get_class(), "Camera2D")
	assert_true(player._sprite.texture != null)
	assert_eq(Vector2i(player._sprite.texture.get_size()), CharacterSprites.CANVAS)
	player.face(Vector2.RIGHT)
	await wait_frames(2)
	assert_eq(player.sprite_direction(), "right")
	var right_texture: Texture2D = player._sprite.texture
	player.face(Vector2.UP)
	await wait_frames(2)
	assert_eq(player.sprite_direction(), "up")
	assert_ne(player._sprite.texture, right_texture)
	assert_eq(player._look.kind, "agent")


func test_player_sprite_feet_match_the_collision_box() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(1)
	# base do personagem (fileira 17 da tela) alinhada com a base da colisão de 24 px
	var feet_y: float = (float(CharacterSprites.ORIGIN.y + CharacterSprites.HEIGHT) + player._sprite.offset.y) * player._sprite.scale.y
	assert_almost_eq(feet_y, 12.0)
	assert_almost_eq(float(CharacterSprites.WIDTH) * player._sprite.scale.x, 24.0)


func test_player_walk_animation_runs_only_while_moving() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_physics_frames(2)
	assert_eq(player.sprite_frame(), 0)
	Input.action_press("p1_right")
	var frames := {}
	for i in 40:
		await wait_physics_frames(1)
		await wait_frames(1)
		frames[player.sprite_frame()] = true
	Input.action_release("p1_right")
	assert_true(frames.has(1) and frames.has(2), "os dois quadros de passo aparecem")
	await wait_physics_frames(3)
	await wait_frames(1)
	assert_eq(player.sprite_frame(), 0)


func test_aim_marker_shows_gun_only_with_a_weapon() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	assert_eq(player._aim_sprite.texture, SpriteFactory.prop("gun_hand"), "o agente começa com pistola")
	for hand in ["left", "right"]:
		player.inventory.unequip(hand)
	await wait_frames(2)
	assert_eq(player._aim_sprite.texture, SpriteFactory.prop("aim"))


func test_npc_look_follows_kind_and_identity() -> void:
	var a = NPC_SCENE.instantiate()
	a.ai_seed = 50
	_add(a)
	var b = NPC_SCENE.instantiate()
	b.ai_seed = 50
	_add(b)
	var criminal = NPC_SCENE.instantiate()
	criminal.kind = "criminal"
	criminal.ai_seed = 51
	_add(criminal)
	await wait_frames(1)
	assert_eq(a.look(), b.look(), "mesma identidade, mesma aparência")
	assert_eq(a.look().kind, "innocent")
	assert_eq(criminal.look().kind, "criminal")
	assert_true(a._sprite.texture != null)
	assert_ne(criminal._sprite.texture, a._sprite.texture)


func test_npc_faces_where_it_walks() -> void:
	var npc = NPC_SCENE.instantiate()
	npc.ai_seed = 60
	_add(npc)
	await wait_frames(1)
	npc.velocity = Vector2(-60, 0)
	npc._update_sprite(0.1)
	assert_eq(npc.sprite_direction(), "left")
	npc.velocity = Vector2(0, 60)
	npc._update_sprite(0.1)
	assert_eq(npc.sprite_direction(), "down")
	npc.velocity = Vector2.ZERO
	npc._update_sprite(0.1)
	assert_eq(npc.sprite_direction(), "down", "parado, mantém a última direção")


func test_stunned_npc_is_tinted() -> void:
	var npc = NPC_SCENE.instantiate()
	npc.ai_seed = 61
	_add(npc)
	await wait_frames(1)
	assert_eq(npc._sprite.modulate, Color.WHITE)
	npc.stun(2.0)
	npc._update_sprite(0.0)
	assert_ne(npc._sprite.modulate, Color.WHITE)


# --- carros, itens, tiros ---

func test_car_sprite_snaps_to_pregenerated_directions() -> void:
	var car = CAR_SCENE.instantiate()
	car.model = "van"
	car.tone = "green"
	_add(car)
	await wait_frames(1)
	assert_eq(car.sprite_direction(), 0)
	assert_eq(car._sprite.texture, SpriteFactory.car("van", "green", 0))
	car.rotation = PI / 2.0
	car._update_sprite()
	assert_eq(car.sprite_direction(), CarSprites.DIRECTIONS / 4)
	assert_almost_eq(car._sprite.global_rotation, 0.0, 0.001, "o sprite não gira; troca de quadro")
	car.rotation = PI / 2.0 + 0.02
	car._update_sprite()
	assert_eq(car.sprite_direction(), CarSprites.DIRECTIONS / 4, "variação pequena mantém o quadro")


func test_pickups_and_bullets_draw_sprites() -> void:
	var cash = PickupScript.spawn(tree.root, Vector2(5000, 5000), "cash", 10)
	_nodes.append(cash)
	var odd = PickupScript.spawn(tree.root, Vector2(5100, 5000), "coisa_estranha", 1)
	_nodes.append(odd)
	assert_eq(cash.sprite_id(), "cash")
	assert_eq(odd.sprite_id(), "item")
	for id in PickupScript.SPRITES:
		assert_true(SpriteFactory.prop(id) != null)
	var bullet = BulletScript.fire(tree.root, Vector2(5000, 5200), Vector2.RIGHT, null, "npcs")
	_nodes.append(bullet)
	assert_gt(bullet.z_index, cash.z_index)


# --- interior ---

func test_interior_has_no_placeholder_rectangles() -> void:
	GameState.set_inside(3, Vector2.ZERO, "armory")
	var interior := _add(INTERIOR_SCENE.instantiate())
	await wait_frames(2)
	assert_eq(_count_color_rects(interior), 0)
	assert_true(interior.get_node("ShopSign").texture != null)
	GameState.set_outside()


# --- HUD ---

func test_hud_labels_are_pixel_labels_with_plate() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	var hud = player.hud
	for label in [hud._region, hud._score, hud._health, hud._level, hud._hands, hud._money, hud._prompt, hud._toast]:
		assert_true(label.get_script() == PixelLabel)
	assert_gt(hud._score.plate_size().x, 40.0)
	assert_eq(hud._score.size, hud._score.plate_size())


func test_hud_right_side_labels_stay_inside_the_screen() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	var hud = player.hud
	for label in [hud._score, hud._money, hud._health]:
		assert_almost_eq(label.offset_right, -16.0, 0.01, "margem direita")
		assert_eq(label.anchor_left, 1.0)
	Score.register_incident(123456)
	await wait_frames(1)
	assert_almost_eq(hud._score.offset_right, -16.0, 0.01, "texto maior cresce para a esquerda")
	assert_almost_eq(hud._score.offset_right - hud._score.offset_left, hud._score.plate_size().x)


func test_hud_place_and_clock_are_hidden_until_set() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	var hud = player.hud
	assert_eq(hud.place_text(), "")
	assert_eq(hud.clock_text(), "")
	assert_eq(hud._place.plate_size(), Vector2.ZERO, "vazio não desenha placa")
	hud.set_place("Centro Velho — Rua do Disfarce")
	hud.set_clock("08:00")
	assert_eq(hud.place_text(), "Centro Velho — Rua do Disfarce")
	assert_eq(hud.clock_text(), "08:00")
	assert_gt(hud._clock.plate_size().x, 0.0)


func test_hud_health_bar_follows_health() -> void:
	var player = _add(PLAYER_SCENE.instantiate())
	await wait_frames(2)
	var hud = player.hud
	hud.set_health(10, 10)
	assert_almost_eq(hud._health.bar_ratio, 1.0)
	hud.set_health(4, 10)
	assert_almost_eq(hud._health.bar_ratio, 0.4)
	hud.set_health(0, 0)
	assert_almost_eq(hud._health.bar_ratio, 0.0)
