extends "res://tests/base_test.gd"

const CAR_SCENE := preload("res://scenes/vehicle/car.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CarScript := preload("res://scripts/vehicle/car.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var car
var player


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	car = CAR_SCENE.instantiate()
	car.global_position = Vector2(500, 500)
	tree.root.add_child(car)
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 540)  # dentro da zona de interação do carro
	tree.root.add_child(player)
	await wait_physics_frames(3)


func after_each() -> void:
	_release_all()
	car.queue_free()
	player.queue_free()
	await wait_frames(1)


func _release_all() -> void:
	for n in [1, 2]:
		for a in ["up", "down", "left", "right", "interact"]:
			Input.action_release("p%d_%s" % [n, a])


# --- física pura ---

func test_accelerates_and_caps_at_max() -> void:
	assert_gt(CarScript.next_speed(0.0, 1.0, 0.1), 0.0)
	assert_almost_eq(CarScript.next_speed(CarScript.MAX_FORWARD, 1.0, 1.0), CarScript.MAX_FORWARD)


func test_reverse_caps() -> void:
	assert_almost_eq(CarScript.next_speed(-CarScript.MAX_REVERSE, -1.0, 1.0), -CarScript.MAX_REVERSE)
	assert_true(CarScript.next_speed(0.0, -1.0, 0.1) < 0.0)


func test_braking_is_stronger_than_accelerating() -> void:
	var braked: float = 300.0 - CarScript.next_speed(300.0, -1.0, 0.1)
	var accelerated: float = CarScript.next_speed(0.0, 1.0, 0.1)
	assert_gt(braked, accelerated)


func test_friction_stops_car_without_overshoot() -> void:
	assert_true(CarScript.next_speed(100.0, 0.0, 0.1) < 100.0)
	assert_eq(CarScript.next_speed(1.0, 0.0, 1.0), 0.0)
	assert_eq(CarScript.next_speed(-1.0, 0.0, 1.0), 0.0)


func test_steering_needs_movement_and_inverts_in_reverse() -> void:
	assert_eq(CarScript.steer_amount(0.0, 1.0, 0.1), 0.0)
	assert_gt(CarScript.steer_amount(200.0, 1.0, 0.1), 0.0)
	assert_true(CarScript.steer_amount(-100.0, 1.0, 0.1) < 0.0)


# --- cena ---

func test_parked_car_does_not_move() -> void:
	player.global_position = Vector2(500, 900)  # longe, para não empurrar o carro
	await wait_physics_frames(2)
	Input.action_press("p1_up")  # ninguém dirigindo o carro
	await wait_physics_frames(10)
	assert_eq(car.global_position, Vector2(500, 500))


func test_enter_vehicle_hides_and_disables_player() -> void:
	assert_true(player.enter_vehicle(car))
	assert_eq(car.driver, player)
	assert_eq(player.vehicle, car)
	assert_false(player.visible)
	assert_true(player.get_node("CollisionShape2D").disabled)


func test_occupied_car_refuses_second_driver() -> void:
	var other := PLAYER_SCENE.instantiate()
	other.player_index = 2
	tree.root.add_child(other)
	assert_true(player.enter_vehicle(car))
	assert_false(other.enter_vehicle(car))
	assert_eq(car.driver, player)
	other.queue_free()


func test_driving_moves_car_and_player_follows() -> void:
	player.enter_vehicle(car)
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	assert_gt(car.global_position.x, 520.0)
	assert_almost_eq(car.global_position.y, 500.0, 0.5)
	assert_eq(player.global_position, car.global_position)


func test_steering_rotates_car() -> void:
	player.enter_vehicle(car)
	Input.action_press("p1_up")
	Input.action_press("p1_right")
	await wait_physics_frames(30)
	assert_gt(car.rotation, 0.1)


func test_reverse_goes_backwards() -> void:
	player.enter_vehicle(car)
	Input.action_press("p1_down")
	await wait_physics_frames(20)
	assert_true(car.global_position.x < 500.0)


func test_car_stops_against_wall() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 300)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = Vector2(700, 500)
	tree.root.add_child(wall)
	player.enter_vehicle(car)
	Input.action_press("p1_up")
	await wait_physics_frames(120)
	assert_true(car.global_position.x < 700.0 - 10.0 - 26.0 + 1.0, "atravessou a parede")
	wall.queue_free()


func test_exit_vehicle_restores_player_next_to_car() -> void:
	player.enter_vehicle(car)
	assert_true(player.exit_vehicle())
	assert_true(player.visible)
	assert_false(player.get_node("CollisionShape2D").disabled)
	assert_eq(car.driver, null)
	assert_eq(player.vehicle, null)
	assert_gt(player.global_position.distance_to(car.global_position), 40.0)
	assert_false(player.test_move(player.global_transform, Vector2.ZERO), "saiu dentro de algo sólido")


func test_exit_picks_free_side_when_blocked() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(200, 30)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = Vector2(500, 448)  # bloqueia o lado esquerdo (y - 52)
	tree.root.add_child(wall)
	await wait_physics_frames(1)
	player.enter_vehicle(car)
	player.exit_vehicle()
	assert_false(player.test_move(player.global_transform, Vector2.ZERO))
	assert_gt(player.global_position.y, 500.0, "deveria sair pelo lado livre")
	wall.queue_free()


# --- interação com E ---

func test_prompt_to_drive_appears_near_car_without_entering() -> void:
	assert_true(is_instance_valid(player.interactable), "zona do carro não detectada")
	assert_true(player.current_prompt().contains("dirigir"))
	assert_true(player.current_prompt().contains("E"))
	assert_eq(player.vehicle, null, "não deve entrar sem apertar E")


func test_pressing_interact_enters_then_exits_car() -> void:
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(player.vehicle, car, "E deveria entrar no carro")
	assert_true(player.current_prompt().contains("sair"))
	await wait_physics_frames(2)
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(player.vehicle, null, "E deveria sair do carro")
	assert_eq(car.driver, null)


func test_prompt_cleared_when_walking_away() -> void:
	player.global_position = Vector2(500, 900)
	await wait_physics_frames(3)
	assert_eq(player.current_prompt(), "")
