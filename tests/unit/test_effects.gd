extends "res://tests/base_test.gd"
## Efeitos da Fase 5: clarão e cápsula, faíscas, poeira, marcas de pneu e tremor de câmera.

const Fx := preload("res://scripts/effects/fx.gd")
const FxSprites := preload("res://scripts/art/fx_sprites.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const TireMarksScript := preload("res://scripts/effects/tire_marks.gd")
const BulletScript := preload("res://scripts/combat/bullet.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var holder: Node2D
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	Fx.reset()
	GameState.screen_shake = true
	holder = Node2D.new()
	tree.root.add_child(holder)


func after_each() -> void:
	for b in tree.get_nodes_in_group("bullets"):
		b.free()
	for p in tree.get_nodes_in_group("fx"):
		p.queue_free()
	holder.queue_free()
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	await wait_frames(2)
	Fx.reset()


func _count_fx() -> int:
	return tree.get_nodes_in_group("fx").size()


# --- sprites ---

func test_every_fx_sprite_uses_only_palette_colors() -> void:
	for id in FxSprites.ids():
		var canvas: RefCounted = FxSprites.canvas(id)
		assert_true(canvas.only_palette_colors(), "sprite de efeito fora da paleta: %s" % id)
		assert_gt(canvas.opaque_count(), 0.0, "sprite vazio: %s" % id)


func test_fx_textures_are_cached() -> void:
	var a := SpriteFactory.fx("spark/0")
	var before := SpriteFactory.build_count()
	assert_true(SpriteFactory.fx("spark/0") == a)
	assert_eq(SpriteFactory.build_count(), before)


# --- tiro ---

func test_shot_makes_a_two_frame_flash_and_a_casing() -> void:
	Fx.shot(holder, Vector2(100, 100), Vector2.RIGHT, true)
	assert_eq(_count_fx(), 3, "clarão grande, clarão pequeno e cápsula")
	await wait_frames(1)
	await get_tree_seconds(0.2)
	assert_eq(_count_fx(), 1, "só a cápsula fica depois do clarão")


func test_casing_disappears_in_two_seconds() -> void:
	Fx.shot(holder, Vector2.ZERO, Vector2.RIGHT, true)
	await get_tree_seconds(1.0)
	assert_eq(_count_fx(), 1, "ainda no chão com 1 s")
	await get_tree_seconds(1.3)
	assert_eq(_count_fx(), 0, "some em 2 s")


func test_shot_without_casing_has_only_the_flash() -> void:
	Fx.shot(holder, Vector2.ZERO, Vector2.DOWN, false)
	assert_eq(_count_fx(), 2)


func test_muzzle_flash_points_along_the_shot() -> void:
	Fx.shot(holder, Vector2(50, 50), Vector2.DOWN, false)
	var flash: Node2D = tree.get_nodes_in_group("fx")[0]
	assert_almost_eq(flash.rotation, PI / 2.0, 0.01)
	assert_true(flash.position.y > 50.0)


# --- impacto ---

func test_wall_impact_makes_four_to_six_sparks() -> void:
	for i in 10:
		var made := Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
		assert_true(made >= Fx.SPARKS_MIN and made <= Fx.SPARKS_MAX, "faíscas: %d" % made)
	assert_true(_count_fx() <= Fx.MAX_PARTICLES)


func test_sparks_fly_back_against_the_shot() -> void:
	Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	for p in tree.get_nodes_in_group("fx"):
		assert_true(p.velocity.x < 0.0, "faísca foi na direção do tiro")


func test_sparks_expire_quickly() -> void:
	Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	await get_tree_seconds(0.4)
	assert_eq(_count_fx(), 0)


func test_ground_hit_makes_dust() -> void:
	assert_eq(Fx.ground_hit(holder, Vector2.ZERO), Fx.GROUND_PUFFS)


func test_bullet_hitting_a_wall_makes_sparks() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(40, 200)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = Vector2(300, 0)
	tree.root.add_child(wall)
	extras.append(wall)
	BulletScript.fire(holder, Vector2(200, 0), Vector2.RIGHT, null, "npcs")
	await wait_physics_frames(8)
	assert_gt(_count_fx(), 3.0, "faíscas na parede")
	assert_eq(tree.get_nodes_in_group("bullets").size(), 0)


func test_bullet_running_out_of_range_raises_dust() -> void:
	BulletScript.fire(holder, Vector2.ZERO, Vector2.RIGHT, null, "npcs", 1.0, "damage", 0.05)
	await wait_physics_frames(6)
	assert_gt(_count_fx(), 0.0, "poeira onde o tiro caiu")


func test_particle_cap_is_respected() -> void:
	for i in 100:
		Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	assert_true(Fx.active_count() <= Fx.MAX_PARTICLES)
	assert_true(_count_fx() <= Fx.MAX_PARTICLES)


func test_effects_are_deterministic() -> void:
	Fx.reset()
	Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	var first: Array = []
	for p in tree.get_nodes_in_group("fx"):
		first.append(p.velocity)
	for p in tree.get_nodes_in_group("fx"):
		p.queue_free()
	await wait_frames(2)
	Fx.reset()
	Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	var second: Array = []
	for p in tree.get_nodes_in_group("fx"):
		second.append(p.velocity)
	assert_eq(first, second)


func test_counter_returns_to_zero_when_particles_expire() -> void:
	Fx.sparks(holder, Vector2.ZERO, Vector2.RIGHT)
	assert_gt(Fx.active_count(), 0.0)
	await get_tree_seconds(0.4)
	assert_eq(Fx.active_count(), 0)


func test_dirt_is_the_country_off_the_road() -> void:
	assert_false(Fx.is_dirt(Vector2(3000, 3000)), "cidade")
	assert_false(Fx.is_dirt(Vector2(8000, 3360)), "estrada do campo")
	assert_true(Fx.is_dirt(Vector2(8000, 2000)), "campo")


# --- marcas de pneu ---

func _marks() -> Node2D:
	var marks := Node2D.new()
	marks.set_script(TireMarksScript)
	tree.root.add_child(marks)
	extras.append(marks)
	return marks


func test_tire_marks_respect_spacing() -> void:
	var marks := _marks()
	assert_true(marks.add_mark(1, Vector2.ZERO, 0.0))
	assert_false(marks.add_mark(1, Vector2(3, 0), 0.0), "perto demais da marca anterior")
	assert_true(marks.add_mark(1, Vector2(12, 0), 0.0))
	assert_true(marks.add_mark(2, Vector2(3, 0), 0.0), "outra roda tem o próprio espaçamento")
	assert_eq(marks.marks.size(), 3)


func test_tire_marks_keep_only_the_newest_200() -> void:
	var marks := _marks()
	for i in 260:
		marks.add_mark(1, Vector2(i * 20.0, 0), 0.0)
	assert_eq(marks.marks.size(), TireMarksScript.MAX_MARKS)
	assert_eq(marks.marks[0].pos, Vector2(60 * 20.0, 0), "as 60 mais antigas saíram")
	assert_eq(marks.marks[marks.marks.size() - 1].pos, Vector2(259 * 20.0, 0))


func test_lifting_a_wheel_allows_a_new_streak_in_place() -> void:
	var marks := _marks()
	marks.add_mark(1, Vector2.ZERO, 0.0)
	marks.lift(1)
	assert_true(marks.add_mark(1, Vector2(1, 0), 0.0))


func test_clear_removes_all_marks() -> void:
	var marks := _marks()
	marks.add_mark(1, Vector2.ZERO, 0.0)
	marks.clear()
	assert_eq(marks.marks.size(), 0)


func _driven_car(pos: Vector2) -> Array:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = pos
	tree.root.add_child(player)
	extras.append(player)
	var car := CAR_SCENE.instantiate()
	car.global_position = pos
	tree.root.add_child(car)
	extras.append(car)
	await wait_physics_frames(2)
	player.enter_vehicle(car)
	return [player, car]


func test_hard_braking_leaves_marks_for_the_player_car() -> void:
	var marks := _marks()
	var pair: Array = await _driven_car(Vector2(1000, 1000))
	var car: Node = pair[1]
	car.speed = 300.0
	Input.action_press("p1_down")  # freio
	await wait_physics_frames(4)
	Input.action_release("p1_down")
	assert_gt(marks.marks.size(), 0.0, "freada deixa marca")


func test_cruising_leaves_no_marks() -> void:
	var marks := _marks()
	var pair: Array = await _driven_car(Vector2(1000, 1000))
	var car: Node = pair[1]
	car.speed = 200.0
	Input.action_press("p1_up")
	await wait_physics_frames(4)
	Input.action_release("p1_up")
	assert_eq(marks.marks.size(), 0)


func test_traffic_cars_leave_no_marks() -> void:
	var marks := _marks()
	var car := CAR_SCENE.instantiate()
	car.ai_controlled = true
	car.global_position = Vector2(1000, 1000)
	tree.root.add_child(car)
	extras.append(car)
	car.speed = 300.0
	car._trail_effects(0.016, -1.0, 0.0, 300.0)
	assert_eq(marks.marks.size(), 0)


func test_car_on_dirt_raises_dust_and_on_asphalt_does_not() -> void:
	var car := CAR_SCENE.instantiate()
	car.global_position = Vector2(8000, 2000)
	tree.root.add_child(car)
	extras.append(car)
	await wait_physics_frames(1)
	car._trail_effects(0.016, 1.0, 0.0, 250.0)
	assert_gt(_count_fx(), 0.0, "poeira na terra")
	for p in tree.get_nodes_in_group("fx"):
		p.queue_free()
	await wait_frames(2)
	car.global_position = Vector2(1000, 1000)
	car._dust_timer = 0.0
	car._trail_effects(0.016, 1.0, 0.0, 250.0)
	assert_eq(_count_fx(), 0, "sem poeira no asfalto")


# --- tremor de câmera ---

func _player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	tree.root.add_child(player)
	extras.append(player)
	await wait_physics_frames(2)
	return player


func test_shake_moves_the_camera_then_settles() -> void:
	var player: Node = await _player()
	player.shake(3.0)
	assert_true(player.is_shaking())
	await wait_frames(3)
	var offset: Vector2 = player.get_node("Camera2D").offset
	assert_true(absf(offset.x) <= 3.0 and absf(offset.y) <= 3.0, "dentro de 3 px")
	await get_tree_seconds(0.3)
	assert_false(player.is_shaking())
	assert_eq(player.get_node("Camera2D").offset, Vector2.ZERO)


func test_shake_can_be_turned_off() -> void:
	var player: Node = await _player()
	GameState.screen_shake = false
	player.shake(4.0)
	assert_false(player.is_shaking())


func test_taking_damage_shakes_the_camera() -> void:
	var player: Node = await _player()
	player.take_damage(1.0)
	assert_true(player.is_shaking())


func test_blocked_shot_does_not_shake() -> void:
	var player: Node = await _player()
	player.set("_shield_raised", true)
	var shooter := Node2D.new()
	shooter.global_position = player.global_position + player.facing() * 100.0
	tree.root.add_child(shooter)
	extras.append(shooter)
	player.take_damage(1.0, shooter)
	assert_false(player.is_shaking())


func test_shotgun_shakes_and_pistol_does_not() -> void:
	var player: Node = await _player()
	player.inventory.equip("left", "shotgun")
	player.fire_hand("left")
	assert_true(player.is_shaking(), "escopeta")
	player.queue_free()
	await wait_frames(2)
	var other: Node = await _player()
	other.inventory.equip("left", "pistol")
	other.fire_hand("left")
	assert_false(other.is_shaking(), "pistola")
	assert_gt(_count_fx(), 0.0, "mas a pistola tem clarão")


func test_car_crash_shakes_the_driver() -> void:
	var pair: Array = await _driven_car(Vector2(1000, 1000))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(40, 400)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = Vector2(1200, 1000)
	tree.root.add_child(wall)
	extras.append(wall)
	var car: Node = pair[1]
	car.speed = 300.0
	Input.action_press("p1_up")
	var shook := false
	for i in 80:
		await wait_physics_frames(1)
		shook = shook or pair[0].is_shaking()
	Input.action_release("p1_up")
	assert_true(shook, "a batida sacudiu a câmera")


func get_tree_seconds(seconds: float) -> void:
	await tree.create_timer(seconds).timeout
