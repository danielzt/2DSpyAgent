extends "res://tests/base_test.gd"
## Sprites e tiles gerados por código: personagens, carros, objetos, tiles e o cache.

const Palette := preload("res://scripts/art/palette.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")


func _looks() -> Array:
	var looks := [CharacterSprites.agent_look(1), CharacterSprites.agent_look(2), CharacterSprites.criminal_look(5)]
	for i in 12:
		looks.append(CharacterSprites.civilian_look(i))
	for style in CharacterSprites.HAIR_STYLES:
		var look := CharacterSprites.civilian_look(1)
		look.hair_style = style
		looks.append(look)
	return looks


# --- personagens ---

func test_character_rows_are_12_by_16_in_every_variation() -> void:
	for look in _looks():
		for direction in CharacterSprites.DIRECTIONS:
			for frame in CharacterSprites.FRAMES:
				var rows: Array = CharacterSprites.rows_for(look, direction, frame)
				assert_eq(rows.size(), CharacterSprites.HEIGHT)
				for row in rows:
					assert_eq((row as String).length(), CharacterSprites.WIDTH,
						"%s %s %d: '%s'" % [look.kind, direction, frame, row])


func test_character_frames_use_only_palette_colors() -> void:
	for look in _looks():
		for direction in CharacterSprites.DIRECTIONS:
			var canvas: RefCounted = CharacterSprites.build(look, direction, 1)
			assert_eq(Vector2i(canvas.width, canvas.height), CharacterSprites.CANVAS)
			assert_true(canvas.only_palette_colors(), "%s %s" % [look.kind, direction])
			assert_gt(canvas.opaque_count(), 80.0)


func test_walking_frames_differ_from_idle() -> void:
	var look := CharacterSprites.civilian_look(3)
	for direction in CharacterSprites.DIRECTIONS:
		var idle: PackedByteArray = CharacterSprites.body(look, direction, 0).image.get_data()
		var step_a: PackedByteArray = CharacterSprites.body(look, direction, 1).image.get_data()
		var step_b: PackedByteArray = CharacterSprites.body(look, direction, 2).image.get_data()
		assert_ne(idle, step_a, direction)
		assert_ne(step_a, step_b, direction)


func test_left_is_the_mirror_of_right() -> void:
	var look := CharacterSprites.civilian_look(8)
	var right: RefCounted = CharacterSprites.body(look, "right", 0)
	var left: RefCounted = CharacterSprites.body(look, "left", 0)
	assert_eq(left.image.get_data(), right.flipped_h().image.get_data())
	assert_ne(left.image.get_data(), right.image.get_data())


func test_looks_are_deterministic_and_varied() -> void:
	assert_eq(CharacterSprites.civilian_look(42), CharacterSprites.civilian_look(42))
	var keys := {}
	for i in 60:
		keys[CharacterSprites.look_key(CharacterSprites.civilian_look(i))] = true
	assert_gt(keys.size(), 30.0, "civis parecidos demais")


## Jogador, inocente e criminoso se distinguem pela silhueta/detalhes, não só pela cor.
func test_kinds_are_distinguishable_by_shape() -> void:
	var civilian := CharacterSprites.civilian_look(4)
	civilian.hair_style = "short"
	var agent: Array = CharacterSprites.rows_for(CharacterSprites.agent_look(1), "down", 0)
	var criminal: Array = CharacterSprites.rows_for(CharacterSprites.criminal_look(4), "down", 0)
	var innocent: Array = CharacterSprites.rows_for(civilian, "down", 0)
	assert_ne(agent[4], innocent[4], "óculos escuros do agente")
	assert_ne(criminal[4], innocent[4], "máscara do criminoso")
	assert_ne(criminal[4], agent[4])
	assert_true((agent[8] as String).contains("r"), "gravata")
	assert_ne(criminal[8], innocent[8], "camisa listrada")
	assert_eq(CharacterSprites.look_for("criminal", 9).kind, "criminal")
	assert_eq(CharacterSprites.look_for("innocent", 9).kind, "innocent")


func test_player_ring_marks_the_player_only() -> void:
	assert_eq(CharacterSprites.agent_look(1).ring, "blue")
	assert_eq(CharacterSprites.agent_look(2).ring, "orange")
	assert_eq(CharacterSprites.civilian_look(1).ring, "")
	var with_ring: RefCounted = CharacterSprites.build(CharacterSprites.agent_look(1), "down", 0)
	var colors: Array[Color] = with_ring.used_colors()
	assert_true(colors.has(Color(Palette.get_color("blue").to_html(false))))


func test_direction_of_picks_the_dominant_axis() -> void:
	assert_eq(CharacterSprites.direction_of(Vector2(1, 0.2)), "right")
	assert_eq(CharacterSprites.direction_of(Vector2(-1, 0.2)), "left")
	assert_eq(CharacterSprites.direction_of(Vector2(0.2, -1)), "up")
	assert_eq(CharacterSprites.direction_of(Vector2(0.2, 1)), "down")
	assert_eq(CharacterSprites.direction_of(Vector2.ZERO), "down")


# --- carros ---

func test_every_car_model_builds_with_palette_colors() -> void:
	for model in CarSprites.MODELS:
		assert_true(CarSprites.PARTS.has(model), model)
		var base: RefCounted = CarSprites.base(model, "red")
		assert_eq(Vector2i(base.width, base.height), Vector2i(CarSprites.LENGTH, CarSprites.WIDTH))
		assert_true(base.only_palette_colors(), model)
		var frame: RefCounted = CarSprites.frame(model, "red", 0)
		assert_eq(frame.width, CarSprites.FRAME_SIDE)
		assert_true(frame.only_palette_colors(), model)


func test_car_matches_the_collision_box() -> void:
	# 26x13 texels = 52x26 px, a caixa de colisão do carro.
	assert_eq(CarSprites.LENGTH * SpriteFactory.TEXEL, 52)
	assert_eq(CarSprites.WIDTH * SpriteFactory.TEXEL, 26)


func test_car_tones_and_fixed_colors() -> void:
	for tone in CarSprites.TONES:
		assert_true(Palette.TONES.has(tone), tone)
	assert_eq(CarSprites.tone_of("taxi", "red"), "yellow")
	assert_eq(CarSprites.tone_of("police", "red"), "white")
	assert_eq(CarSprites.tone_of("agent", "red"), "black")
	assert_eq(CarSprites.tone_of("sedan", "red"), "red")
	assert_ne(CarSprites.base("sedan", "red").image.get_data(), CarSprites.base("sedan", "blue").image.get_data())


func test_car_direction_index_wraps_around() -> void:
	assert_eq(CarSprites.direction_index(0.0), 0)
	assert_eq(CarSprites.direction_index(PI / 2.0), CarSprites.DIRECTIONS / 4)
	assert_eq(CarSprites.direction_index(PI), CarSprites.DIRECTIONS / 2)
	assert_eq(CarSprites.direction_index(-PI / 2.0), CarSprites.DIRECTIONS * 3 / 4)
	assert_eq(CarSprites.direction_index(TAU), 0)
	assert_eq(CarSprites.direction_index(TAU * 5.0 + 0.01), 0)


func test_car_rotation_frames_keep_the_car_whole() -> void:
	var base_count: int = CarSprites.frame("sedan", "blue", 0).opaque_count()
	for direction in [3, 8, 13, 16, 27]:
		var count: int = CarSprites.frame("sedan", "blue", direction).opaque_count()
		assert_true(absi(count - base_count) < base_count / 4, "direção %d: %d x %d" % [direction, count, base_count])
	# virado para baixo, o carro fica mais alto que largo
	var down: RefCounted = CarSprites.frame("sedan", "blue", CarSprites.DIRECTIONS / 4)
	assert_true(down.is_empty_at(2, CarSprites.FRAME_SIDE / 2))
	assert_false(down.is_empty_at(CarSprites.FRAME_SIDE / 2, 6))


func test_traffic_variants_are_deterministic_and_varied() -> void:
	assert_eq(CarSprites.variant_for(3), CarSprites.variant_for(3))
	var seen := {}
	for i in 10:
		var v := CarSprites.variant_for(i)
		assert_true(CarSprites.MODELS.has(v.model))
		assert_true(CarSprites.TONES.has(v.tone))
		seen["%s/%s" % [v.model, v.tone]] = true
	assert_gt(seen.size(), 6.0)


# --- objetos ---

func test_text_sprites_have_uniform_rows_and_known_letters() -> void:
	var legend := Palette.legend()
	for id in PropSprites.TEXT_SPRITES:
		var rows: Array = PropSprites.TEXT_SPRITES[id]
		var width := (rows[0] as String).length()
		for row in rows:
			assert_eq((row as String).length(), width, id)
			for letter in row:
				assert_true(letter == "." or legend.has(letter), "%s: letra '%s'" % [id, letter])


func test_every_prop_builds_with_palette_colors() -> void:
	for id in PropSprites.ids():
		var canvas: RefCounted = PropSprites.canvas(id)
		assert_gt(canvas.opaque_count(), 3.0, id)
		assert_true(canvas.only_palette_colors(), id)
	assert_true(PropSprites.has_sprite("lamp"))
	assert_false(PropSprites.has_sprite("nao_existe"))


func test_props_needed_by_the_street_exist() -> void:
	for id in ["lamp", "traffic_light", "bench", "bin", "hydrant", "bus_stop", "small_tree", "newsstand",
			"manhole", "bush", "flowers", "tree/0", "trunk", "tree_shadow", "fence_h", "fence_v",
			"roof_tank", "roof_ac", "roof_skylight", "roof_chimney", "roof_antenna",
			"cash", "medkit", "pistol", "shotgun", "taser", "shield", "item", "bullet", "bullet_stun"]:
		assert_true(PropSprites.has_sprite(id), id)


# --- tiles ---

func test_every_tile_builds_with_palette_colors() -> void:
	for id in TileFactory.IDS:
		var canvas: RefCounted = TileFactory.canvas(id)
		assert_true(canvas.only_palette_colors(), id)
		if not (id.begins_with("dash") or id.begins_with("cross")):
			assert_eq(Vector2i(canvas.width, canvas.height), Vector2i(TileFactory.SIZE, TileFactory.SIZE), id)
			assert_eq(canvas.opaque_count(), TileFactory.SIZE * TileFactory.SIZE, "%s tem buracos" % id)


func test_wall_tiles_exist_for_every_tone() -> void:
	for tone in Palette.TONES:
		assert_true(TileFactory.has_tile("wall/" + tone))
		assert_true(TileFactory.canvas("wall/" + tone).only_palette_colors())
	assert_false(TileFactory.has_tile("wall/nao_existe"))
	assert_false(TileFactory.has_tile("xyz"))


func test_road_marking_tiles_are_half_transparent() -> void:
	var dash: RefCounted = TileFactory.canvas("dash_v")
	assert_eq(dash.opaque_count(), dash.width * dash.height / 2)
	var cross: RefCounted = TileFactory.canvas("cross_h")
	assert_gt(cross.opaque_count(), 0.0)
	assert_true(cross.opaque_count() < cross.width)


# --- cache ---

func test_factory_builds_each_texture_once() -> void:
	var look := CharacterSprites.civilian_look(777)
	var first := SpriteFactory.character(look, "down", 0)
	var builds := SpriteFactory.build_count()
	assert_eq(SpriteFactory.character(look, "down", 0), first, "mesma textura do cache")
	assert_eq(SpriteFactory.car("van", "green", 5), SpriteFactory.car("van", "green", 5))
	assert_eq(SpriteFactory.prop("lamp"), SpriteFactory.prop("lamp"))
	assert_eq(SpriteFactory.tile("asphalt"), SpriteFactory.tile("asphalt"))
	SpriteFactory.character(look, "down", 0)
	assert_true(SpriteFactory.build_count() <= builds + 2, "pedidos repetidos não montam de novo")
	assert_ne(SpriteFactory.character(look, "up", 0), first)


func test_factory_textures_have_the_sprite_size() -> void:
	assert_eq(Vector2i(SpriteFactory.character(CharacterSprites.agent_look(1), "down", 0).get_size()), CharacterSprites.CANVAS)
	assert_eq(int(SpriteFactory.car("sedan", "red", 0).get_width()), CarSprites.FRAME_SIDE)
	assert_eq(int(SpriteFactory.tile("grass").get_width()), TileFactory.SIZE)


func test_make_sprite_scales_by_the_texel_and_sets_the_pivot() -> void:
	var sprite := SpriteFactory.make_sprite(SpriteFactory.prop("lamp"), Vector2(3, 4))
	assert_eq(sprite.scale, Vector2(SpriteFactory.TEXEL, SpriteFactory.TEXEL))
	assert_eq(sprite.offset, Vector2(-3, -4))
	assert_false(sprite.centered)
	sprite.free()


func test_text_texture_is_cached_by_content() -> void:
	var a := SpriteFactory.text("Armaria", "white")
	assert_eq(SpriteFactory.text("Armaria", "white"), a)
	assert_ne(SpriteFactory.text("Farmácia", "white"), a)


# --- interiores caprichados: pisos novos e faces de parede ---

const NEW_FLOORS := ["floor/herringbone", "floor/wood_dark", "floor/laminate", "floor/carpet_navy",
	"floor/carpet_cream", "floor/linoleum_mint", "floor/linoleum_gray", "floor/linoleum_white", "floor/bath_tile"]
const FACE_STYLES := ["stripes_wine", "wood_panel", "tile_blue", "tile_white_green", "navy_half", "brick",
	"floral", "plaster_cream", "plaster_gray"]


func test_new_floors_exist_and_use_the_palette() -> void:
	for id in NEW_FLOORS:
		assert_true(TileFactory.has_tile(id), id)
		var canvas: RefCounted = TileFactory.canvas(id)
		assert_eq(Vector2i(canvas.width, canvas.height), Vector2i(32, 32), id)
		assert_true(canvas.only_palette_colors(), id)
		assert_gt(float(canvas.used_colors().size()), 2.0, id)


func test_wall_faces() -> void:
	for style in FACE_STYLES:
		assert_true(TileFactory.has_face(style), style)
		var canvas: RefCounted = TileFactory.face(style)
		assert_eq(Vector2i(canvas.width, canvas.height), Vector2i(16, 12), style)
		assert_true(canvas.only_palette_colors(), style)
		assert_ne(canvas.get_px(4, 11), canvas.get_px(4, 6), "%s: rodapé" % style)
		assert_true(SpriteFactory.face(style) == SpriteFactory.face(style), "cache")
	assert_false(TileFactory.has_face("castelo"))


# --- poses (sentado, deitado, trabalhando) ---

func test_poses_differ_from_standing() -> void:
	var look := CharacterSprites.civilian_look(4)
	var stand: RefCounted = CharacterSprites.build(look, "down", 0, "stand")
	for pose in ["sit", "lie", "work"]:
		var canvas: RefCounted = CharacterSprites.build(look, "down", 1, pose)
		assert_ne(canvas.image.get_data(), stand.image.get_data(), pose)
		assert_true(canvas.only_palette_colors(), pose)
	for dir in ["up", "right", "left"]:
		var sit: RefCounted = CharacterSprites.build(look, dir, 0, "sit")
		assert_ne(sit.image.get_data(), CharacterSprites.build(look, dir, 0).image.get_data(), "sentado %s" % dir)
	assert_eq(CharacterSprites.POSES, ["stand", "sit", "lie", "work"])


func test_lying_has_no_floor_shadow() -> void:
	var canvas: RefCounted = CharacterSprites.build(CharacterSprites.civilian_look(4), "down", 0, "lie")
	var shadow: Color = Palette.cast_shadow()
	for y in range(canvas.height - 3, canvas.height):
		for x in canvas.width:
			assert_false(canvas.get_px(x, y).is_equal_approx(shadow), "sombra em %d,%d" % [x, y])


func test_work_animates() -> void:
	var look := CharacterSprites.civilian_look(6)
	var a: RefCounted = CharacterSprites.build(look, "down", 1, "work")
	var b: RefCounted = CharacterSprites.build(look, "down", 2, "work")
	assert_ne(a.image.get_data(), b.image.get_data())


func test_pose_is_part_of_the_cache_key() -> void:
	var look := CharacterSprites.civilian_look(2)
	assert_false(SpriteFactory.character(look, "down", 0, "sit") == SpriteFactory.character(look, "down", 0))
	assert_true(SpriteFactory.character(look, "down", 0, "sit") == SpriteFactory.character(look, "down", 0, "sit"))
