extends CharacterBody2D
## Carro top-down. Cima/baixo aceleram/freiam, esquerda/direita viram.
## Entra e sai com a tecla de interação (via InteractZone).
## Colisões "chutam" o carro para longe e o giram ao longo da parede;
## sem curva, ele se alinha levemente às direções cardeais (auxílio de direção).
## Com `ai_controlled`, vira carro de trânsito: dirige sozinho pelas ruas e não pode ser roubado.

const TrafficRoute := preload("res://scripts/vehicle/traffic_route.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")

const ACTOR_Z := 3

const MAX_FORWARD := 340.0
const MAX_REVERSE := 140.0
const ACCEL := 300.0
const BRAKE := 600.0
const FRICTION := 220.0
const STEER_RATE := 2.4       # rad/s na velocidade de manobra plena
const STEER_FULL_SPEED := 100.0

# Colisão
const IMPACT_SPEED_LOSS := 0.6    # fração da velocidade perdida numa batida de frente
const KNOCK_FACTOR := 0.7
const KNOCK_MIN := 140.0
const KNOCK_DECAY := 700.0
const WALL_TURN := 0.5            # quanto o carro gira rumo à direção da parede
const RUN_OVER_SPEED := 110.0     # acima disso atropela NPCs

# Auxílio de direção
const ASSIST_RANGE := 0.21        # rad (~12°) em torno de cada direção cardeal
const ASSIST_RATE := 1.8          # rad/s
const ASSIST_MIN_SPEED := 60.0

# IA do trânsito
const AI_CRUISE := 150.0
const AI_TURN_SPEED := 80.0
const AI_LOOKAHEAD := 70.0        # distância para detectar obstáculos
const AI_LANE_LOOKAHEAD := 110.0  # ponto da faixa perseguido à frente
const AI_TURN_MARGIN := 45.0      # começa a próxima perna esta distância antes do cruzamento

## Modelo (CarSprites.MODELS) e cor da lataria (CarSprites.TONES).
@export var model := "sedan"
@export var tone := "red"
@export var ai_controlled := false
@export var ai_seed := 1

var speed := 0.0
var driver: Node = null
var knock := Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _route_node := Vector2i.ZERO
var _route_dir := Vector2i(1, 0)
var _has_route := false
var _stuck_time := 0.0
var _reverse_time := 0.0
var _probe := KinematicCollision2D.new()
var _sprite: Sprite2D
var _shown_direction := -1


func _ready() -> void:
	add_to_group("vehicles")
	z_index = ACTOR_Z
	_sprite = SpriteFactory.make_sprite(null, Vector2.ONE * CarSprites.FRAME_SIDE / 2.0)
	add_child(_sprite)
	_update_sprite()
	_rng.seed = ai_seed
	if ai_controlled:
		add_to_group("traffic")
		$InteractZone.monitoring = false  # carros de trânsito não podem ser roubados
	$InteractZone.interacted.connect(_on_interacted)


## Nova velocidade escalar dado o acelerador (-1..1).
static func next_speed(current: float, throttle: float, delta: float) -> float:
	if throttle > 0.0:
		var rate := ACCEL if current >= 0.0 else BRAKE
		return minf(current + rate * throttle * delta, MAX_FORWARD)
	if throttle < 0.0:
		var rate := ACCEL if current <= 0.0 else BRAKE
		return maxf(current + rate * throttle * delta, -MAX_REVERSE)
	return move_toward(current, 0.0, FRICTION * delta)


## Variação de ângulo (rad); zero parado, invertida em marcha à ré.
static func steer_amount(current: float, steer_input: float, delta: float) -> float:
	var factor := clampf(current / STEER_FULL_SPEED, -1.0, 1.0)
	return steer_input * STEER_RATE * factor * delta


## Auxílio de direção: sem curva e em movimento, alinha o carro à direção cardeal mais próxima
## quando já estiver quase nela. Retorna a variação de ângulo (rad).
static func assist_turn(rot: float, steer_input: float, current_speed: float, delta: float) -> float:
	if absf(steer_input) > 0.1 or absf(current_speed) < ASSIST_MIN_SPEED:
		return 0.0
	var nearest := roundf(rot / (PI / 2.0)) * (PI / 2.0)
	var diff := angle_difference(rot, nearest)
	if absf(diff) > ASSIST_RANGE or absf(diff) < 0.0001:
		return 0.0
	return signf(diff) * minf(absf(diff), ASSIST_RATE * delta)


## Resposta a uma batida: perde velocidade conforme o impacto, é "chutado" para longe da
## parede e gira rumo à direção da parede. Retorna {speed, knock, turn}.
static func collision_response(heading: Vector2, current_speed: float, normal: Vector2) -> Dictionary:
	if is_zero_approx(current_speed):
		return {"speed": current_speed, "knock": Vector2.ZERO, "turn": 0.0}
	var dir := heading * signf(current_speed)
	var impact := clampf(-dir.dot(normal), 0.0, 1.0)
	if impact <= 0.0:
		return {"speed": current_speed, "knock": Vector2.ZERO, "turn": 0.0}
	var tangent := dir - normal * dir.dot(normal)
	var turn := 0.0
	if tangent.length() > 0.01:
		turn = dir.angle_to(tangent) * impact * WALL_TURN
	var push := maxf(absf(current_speed) * impact * KNOCK_FACTOR, KNOCK_MIN * impact)
	return {
		"speed": current_speed * (1.0 - IMPACT_SPEED_LOSS * impact),
		"knock": normal * push,
		"turn": turn,
	}


## Define a rota do trânsito: o carro segue para o cruzamento `node` chegando na direção `dir`.
func start_route(node: Vector2i, dir: Vector2i) -> void:
	_rng.seed = ai_seed
	_route_node = node
	_route_dir = dir
	_has_route = true


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if is_instance_valid(driver):
		var prefix := "p%d_" % driver.player_index
		throttle = Input.get_axis(prefix + "down", prefix + "up")
		steer = Input.get_axis(prefix + "left", prefix + "right")
	elif ai_controlled:
		var ai := _ai_inputs(delta)
		throttle = ai.x
		steer = ai.y
	speed = next_speed(speed, throttle, delta)
	rotation += steer_amount(speed, steer, delta)
	if is_instance_valid(driver):
		rotation += assist_turn(rotation, steer, speed, delta)

	var speed_before := speed
	velocity = Vector2.RIGHT.rotated(rotation) * speed + knock
	knock = knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	move_and_slide()
	_handle_collisions(speed_before)


func _handle_collisions(speed_before: float) -> void:
	var wall_handled := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider() as Node
		if other != null and other.is_in_group("npcs"):
			if absf(speed_before) > RUN_OVER_SPEED:
				other.take_damage(99, driver if is_instance_valid(driver) else null)
			continue
		if wall_handled:
			continue
		wall_handled = true
		var r := collision_response(Vector2.RIGHT.rotated(rotation), speed_before, col.get_normal())
		speed = r.speed
		if (r.knock as Vector2).length() > knock.length():
			knock = r.knock
		rotation += r.turn


# --- IA do trânsito ---

func _ai_inputs(delta: float) -> Vector2:
	if not _has_route:
		return Vector2.ZERO
	if TrafficRoute.reached_node(global_position, _route_node, _route_dir, AI_TURN_MARGIN):
		_advance_route()
	var to := TrafficRoute.lane_target(global_position, _route_node, _route_dir, AI_LANE_LOOKAHEAD) - global_position
	var diff := angle_difference(rotation, to.angle())
	var steer := clampf(diff * 2.0, -1.0, 1.0)

	if _reverse_time > 0.0:
		_reverse_time -= delta
		return Vector2(-1.0, -steer)

	var cruise := AI_CRUISE if absf(diff) < 0.3 else AI_TURN_SPEED
	var throttle := 1.0
	if speed >= cruise + 30.0:
		throttle = -0.4
	elif speed >= cruise:
		throttle = 0.0

	if _blocked_by_actor_ahead():
		throttle = -1.0 if speed > 20.0 else 0.0

	if absf(speed) < 15.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 1.5:
		_stuck_time = 0.0
		_reverse_time = 1.0
	return Vector2(throttle, steer)


func _advance_route() -> void:
	var d := TrafficRoute.next_dir(_route_node, _route_dir, _rng)
	_route_node += d
	_route_dir = d


## Só freia para pessoas, jogadores e outros carros (não para paredes de curva).
func _blocked_by_actor_ahead() -> bool:
	var ahead := Vector2.RIGHT.rotated(rotation) * AI_LOOKAHEAD
	if not test_move(global_transform, ahead, _probe):
		return false
	var other := _probe.get_collider() as Node
	return other != null and (other.is_in_group("npcs") or other.is_in_group("vehicles") or other.is_in_group("players"))


func _on_interacted(player: Node) -> void:
	if driver == null and not ai_controlled:
		player.enter_vehicle(self)


func _process(_delta: float) -> void:
	_update_sprite()


## O carro gira livremente na física; o sprite usa a direção pré-gerada mais próxima
## e fica sem rotação própria, para os pixels não serrilharem.
func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.global_rotation = 0.0
	var direction := CarSprites.direction_index(rotation)
	if direction != _shown_direction:
		_shown_direction = direction
		_sprite.texture = SpriteFactory.car(model, tone, direction)


## Direção do sprite em uso (0 a 31), para testes.
func sprite_direction() -> int:
	return _shown_direction
