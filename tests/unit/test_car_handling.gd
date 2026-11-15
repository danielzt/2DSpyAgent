extends "res://tests/base_test.gd"
## Colisão com "chute" e auxílio de direção do carro.

const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CarScript := preload("res://scripts/vehicle/car.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var car
var player
var walls: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	car = CAR_SCENE.instantiate()
	car.global_position = Vector2(500, 500)
	tree.root.add_child(car)
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 900)
	tree.root.add_child(player)
	await wait_physics_frames(2)
	player.enter_vehicle(car)


func after_each() -> void:
	for n in ["up", "down", "left", "right"]:
		Input.action_release("p1_" + n)
	car.queue_free()
	player.queue_free()
	for w in walls:
		w.queue_free()
	walls.clear()
	await wait_frames(1)


func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = center
	tree.root.add_child(wall)
	walls.append(wall)


# --- resposta de colisão (pura) ---

func test_head_on_loses_speed_and_kicks_back() -> void:
	var r: Dictionary = CarScript.collision_response(Vector2.RIGHT, 400.0, Vector2.LEFT)
	assert_almost_eq(r.speed, 400.0 * (1.0 - CarScript.IMPACT_SPEED_LOSS), 0.01)
	assert_true((r.knock as Vector2).x < 0.0, "chute deve afastar da parede")
	assert_almost_eq(r.turn, 0.0, 0.001)
	assert_gt(r.speed, 0.0, "não deve zerar a velocidade")


func test_glancing_hit_keeps_more_speed_and_turns_along_wall() -> void:
	var heading := Vector2.RIGHT.rotated(deg_to_rad(20.0))
	var glancing: Dictionary = CarScript.collision_response(heading, 400.0, Vector2.LEFT)
	var head_on: Dictionary = CarScript.collision_response(Vector2.RIGHT, 400.0, Vector2.LEFT)
	assert_gt(glancing.speed, head_on.speed)
	assert_gt(glancing.turn, 0.0, "deve girar rumo à direção da parede (para baixo)")


func test_reverse_head_on_also_kicks_away() -> void:
	var r: Dictionary = CarScript.collision_response(Vector2.RIGHT, -200.0, Vector2.RIGHT)
	assert_true(r.speed > -200.0 and r.speed < 0.0)
	assert_true((r.knock as Vector2).x > 0.0)


func test_moving_away_from_surface_has_no_response() -> void:
	var r: Dictionary = CarScript.collision_response(Vector2.RIGHT, 300.0, Vector2.RIGHT)
	assert_eq(r.speed, 300.0)
	assert_eq(r.knock, Vector2.ZERO)
	assert_eq(r.turn, 0.0)


func test_standing_still_has_no_response() -> void:
	var r: Dictionary = CarScript.collision_response(Vector2.RIGHT, 0.0, Vector2.LEFT)
	assert_eq(r.knock, Vector2.ZERO)


# --- colisão na cena ---

func test_head_on_wall_bounces_instead_of_sticking() -> void:
	_add_wall(Vector2(760, 500), Vector2(20, 400))  # face esquerda em x = 750
	Input.action_press("p1_up")
	var xs: Array[float] = []
	for i in 105:
		await tree.physics_frame
		xs.append(car.global_position.x)
	Input.action_release("p1_up")
	var hit_index := xs.find(xs.max())
	var rebound: float = xs.max() - (xs.slice(hit_index) as Array[float]).min()
	assert_gt(rebound, 3.0, "deveria quicar para trás após a batida")
	var max_x: float = xs.max()
	assert_true(car.global_position.x < 750.0 - 26.0 + 1.0, "atravessou a parede")


func test_diagonal_hit_slides_along_wall() -> void:
	_add_wall(Vector2(760, 600), Vector2(20, 800))
	car.rotation = deg_to_rad(45.0)
	Input.action_press("p1_up")
	await wait_physics_frames(150)
	assert_gt(car.global_position.y, 800.0, "travou na parede em vez de deslizar")
	assert_true(car.global_position.x < 750.0)


func test_can_steer_away_after_head_on_hit() -> void:
	_add_wall(Vector2(760, 500), Vector2(20, 600))
	Input.action_press("p1_up")
	await wait_physics_frames(80)
	Input.action_press("p1_down")
	Input.action_release("p1_up")
	await wait_physics_frames(40)
	Input.action_release("p1_down")
	assert_true(car.global_position.x < 700.0, "deveria conseguir dar ré")


# --- auxílio de direção (puro) ---

func test_assist_pulls_toward_nearest_cardinal() -> void:
	assert_true(CarScript.assist_turn(0.1, 0.0, 200.0, 0.016) < 0.0)
	assert_true(CarScript.assist_turn(-0.1, 0.0, 200.0, 0.016) > 0.0)
	assert_true(CarScript.assist_turn(PI / 2.0 + 0.1, 0.0, 200.0, 0.016) < 0.0)
	assert_true(CarScript.assist_turn(PI - 0.1, 0.0, 200.0, 0.016) > 0.0)


func test_assist_does_nothing_when_steering_slow_or_diagonal() -> void:
	assert_eq(CarScript.assist_turn(0.1, 1.0, 200.0, 0.016), 0.0, "jogador virando")
	assert_eq(CarScript.assist_turn(0.1, 0.0, 10.0, 0.016), 0.0, "devagar demais")
	assert_eq(CarScript.assist_turn(PI / 4.0, 0.0, 200.0, 0.016), 0.0, "diagonal: sem auxílio")
	assert_eq(CarScript.assist_turn(0.0, 0.0, 200.0, 0.016), 0.0, "já alinhado")


func test_assist_never_overshoots() -> void:
	assert_almost_eq(CarScript.assist_turn(0.001, 0.0, 200.0, 1.0), -0.001, 0.00001)


# --- auxílio na cena ---

func test_car_straightens_when_driving_nearly_straight() -> void:
	car.rotation = 0.12
	car.speed = 250.0
	await wait_physics_frames(25)
	assert_true(absf(car.rotation) < 0.02, "deveria alinhar: %f" % car.rotation)


func test_assist_is_off_while_steering() -> void:
	car.rotation = 0.12
	car.speed = 250.0
	Input.action_press("p1_right")
	await wait_physics_frames(10)
	assert_gt(car.rotation, 0.12)


func test_diagonal_heading_is_preserved() -> void:
	car.rotation = deg_to_rad(45.0)
	car.speed = 250.0
	await wait_physics_frames(15)
	assert_almost_eq(car.rotation, deg_to_rad(45.0), 0.001)
