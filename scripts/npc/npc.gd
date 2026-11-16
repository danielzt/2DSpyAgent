extends CharacterBody2D
## NPC a pé. `innocent`: anda sem rumo e foge quando atacado.
## `criminal`: persegue e atira no jogador dentro do alcance.
## Matar um NPC como jogador altera a pontuação (inocente tira pontos, criminoso dá).

const BulletScript := preload("res://scripts/combat/bullet.gd")
const Fx := preload("res://scripts/effects/fx.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
const SidewalkGraph := preload("res://scripts/world/sidewalk_graph.gd")
const PickupScript := preload("res://scripts/items/pickup.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const Palette := preload("res://scripts/art/palette.gd")

signal died(kind: String)
signal went_home

const WALK_SPEED := 60.0
const FLEE_SPEED := 130.0
const FLEE_TIME := 3.0
const CRIMINAL_SPEED := 75.0
const AGGRO_RANGE := 450.0
const KEEP_DISTANCE := 180.0
const FIRE_INTERVAL := 1.2
const AIM_SPREAD := 0.06
const BULLET_OFFSET := 20.0
const TALK_RANGE := 64.0
const XP_CRIMINAL_KILL := 25
const XP_CRIMINAL_STUN := 15
const ARRIVE_DISTANCE := 12.0
const BLOCKED_TURN_BACK_TIME := 1.2
const LOOT_CASH_MIN := 15
const LOOT_CASH_MAX := 45
const LOOT_MEDKIT_CHANCE := 0.25
const LOOT_WEAPON_CHANCE := 0.08
const ACTOR_Z := 3
const WALK_FRAME_TIME := 0.18
const MOVING_SPEED := 5.0
## Indo para casa (à noite): confere de tempos em tempos se chegou a uma porta de moradia.
const HOME_CHECK_TIME := 0.4
const HOME_REACH := 56.0
## Atividades dos interiores (Fase 7).
const PATROL_SPEED := 40.0
const PATROL_PAUSE := Vector2(2.0, 4.0)     # pausa em cada ponto da ronda (mín., máx. em s)
const LOOK_AROUND := Vector2(4.0, 8.0)      # de quanto em quanto tempo quem está no posto olha em volta
const LOOK_AWAY_TIME := 1.5
const WORK_FRAME_TIME := 0.4

@export var kind := "innocent"
@export var max_health := 3
## Semente do comportamento aleatório (0 = aleatória a cada execução).
@export var ai_seed := 0
## Crime de que o criminoso participa (id de CrimeProfiles); vazio para civis.
@export var crime := ""
## Civis da cidade andam pelas calçadas (grafo de calçadas); os demais vagam livremente.
@export var use_sidewalks := false
## Fica parado no lugar (funcionários e clientes dos interiores). Ainda foge se for atacado.
@export var stationary := false

var health: float = 0.0
var dead := false
var stunned := false
var talking := false
## Card de personalidade (nome, idade, traços...). O nome só aparece no card e no aviso do HUD.
var identity: Dictionary = {}
## Trabalho e moradia (Population.context_for); vazio para NPC avulso.
var context: Dictionary = {}
var display_name := ""
## À noite parte dos pedestres vai para casa: some ao passar por uma porta de moradia.
var going_home := false
var _home_doors := PackedVector2Array()
var _home_timer := 0.0
var rng := RandomNumberGenerator.new()

var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _flee_timer := 0.0
var _flee_dir := Vector2.ZERO
var _fire_cooldown := 0.0
var _stun_timer := 0.0
var _sw_from := Vector4i.ZERO   # último nó da calçada
var _sw_to := Vector4i.ZERO     # nó para onde caminha
var _sw_blocked := 0.0
var _flee_threat := Vector2.ZERO
var _stun_scored := false
var _sprite: Sprite2D
var _look := {}
## Papel que define o uniforme (médico de branco, policial de azul...). Vazio = roupa comum.
var uniform_role := ""
## Prédio e vínculo que definem o uniforme (Fase 7): todo funcionário do hospital de branco etc.
var uniform_building := ""
var uniform_staff := false
## Atividade no interior: "" (comportamento antigo), "post", "patrol", "sit", "lie" ou "work".
var activity := ""
## Pontos da ronda (o primeiro é o posto); `facing` é para onde olha parado.
var route := PackedVector2Array()
var facing := "down"
## Em cima de um móvel (assento, cama, aparelho): aí a pessoa não tem colisão.
var on_furniture := true
var _route_index := 1
var _pause_timer := 0.0
var _patrol_blocked := 0.0
var _look_timer := 0.0
var _look_away := 0.0
var _sprite_direction := "down"
var _anim_time := 0.0
var _shown_key := ""


func _ready() -> void:
	add_to_group("npcs")
	health = float(max_health)
	if ai_seed != 0:
		rng.seed = ai_seed
	else:
		rng.randomize()
	_fire_cooldown = rng.randf_range(0.2, FIRE_INTERVAL)
	identity = NpcIdentity.generate(ai_seed if ai_seed != 0 else rng.randi(), kind, context)
	display_name = identity.name
	z_index = ACTOR_Z
	_look = CharacterSprites.look_for(kind, identity.seed, uniform_role, uniform_building, uniform_staff)
	if activity != "":
		_sprite_direction = "down" if activity == "lie" else facing
		_look_timer = rng.randf_range(LOOK_AROUND.x, LOOK_AROUND.y)
		if activity in ["sit", "lie"] or (activity == "exercise" and on_furniture):
			(get_node("CollisionShape2D") as CollisionShape2D).disabled = true
	_sprite = SpriteFactory.make_sprite(null, Vector2(CharacterSprites.PIVOT))
	add_child(_sprite)
	_update_sprite(0.0)
	_add_talk_zone()


## Manda o NPC para casa: ele segue o passeio e entra na primeira moradia por onde passar.
func go_home(doors: PackedVector2Array) -> void:
	going_home = true
	_home_doors = doors


## True (e o NPC some) se está em frente a uma porta de moradia.
func _arrive_home() -> bool:
	for door in _home_doors:
		if door.distance_squared_to(global_position) < HOME_REACH * HOME_REACH:
			went_home.emit()
			queue_free()
			return true
	return false


func _physics_process(delta: float) -> void:
	_fire_cooldown -= delta
	if going_home and not dead:
		_home_timer -= delta
		if _home_timer <= 0.0:
			_home_timer = HOME_CHECK_TIME
			if _arrive_home():
				return
	if _stun_timer > 0.0:
		_stun_timer -= delta
		stunned = _stun_timer > 0.0
		velocity = Vector2.ZERO
		return
	if talking:
		velocity = Vector2.ZERO
		return
	if _flee_timer > 0.0:
		_flee_timer -= delta
		if use_sidewalks:
			_walk_sidewalk(delta, FLEE_SPEED, true)
		else:
			velocity = _flee_dir * FLEE_SPEED
	else:
		var target := _nearest_player_in_range() if kind == "criminal" else null
		if target != null:
			_attack(target)
		else:
			_wander(delta)
	var wanted := velocity
	move_and_slide()
	if get_slide_collision_count() > 0 and not use_sidewalks:
		_wander_timer = 0.0  # bateu: escolhe outro rumo
	if activity == "patrol":
		# bloqueado = quer andar mas quase não sai do lugar (deslizar pela quina de uma parede não conta)
		var stuck := wanted.length() > 0.0 and get_real_velocity().length() < PATROL_SPEED * 0.25
		_patrol_blocked = _patrol_blocked + delta if stuck else 0.0
		if _patrol_blocked > BLOCKED_TURN_BACK_TIME:
			_patrol_blocked = 0.0
			_next_patrol_point()   # alguém ou algo no caminho: espera e segue para o próximo ponto


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	health -= amount
	talking = false  # a conversa é interrompida
	if health <= 0:
		_die(source)
		return
	if activity != "":
		_stand_up()
	if kind == "innocent" and is_instance_valid(source):
		_flee_dir = (global_position - source.global_position).normalized()
		_flee_threat = source.global_position
		_flee_timer = FLEE_TIME


## Atordoamento (taser): para o NPC por `duration` s. Não mata; só pontua uma vez por NPC.
func stun(duration: float, source: Node = null) -> void:
	if dead:
		return
	_stun_timer = duration
	stunned = true
	talking = false
	if not _stun_scored and is_instance_valid(source) and source.is_in_group("players"):
		_stun_scored = true
		Score.register_stun(kind)
		if kind == "criminal" and source.has_method("gain_xp"):
			source.gain_xp(XP_CRIMINAL_STUN)
		# Criminoso atordoado vira preso a entregar na delegacia.
		if kind == "criminal" and source.get("profile") != null:
			source.profile.prisoners += 1


## Só é possível conversar com civis (criminosos são hostis por enquanto).
func can_talk() -> bool:
	return kind == "innocent" and not dead


func set_talking(value: bool) -> void:
	talking = value


func _add_talk_zone() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = TALK_RANGE
	shape.shape = circle
	zone.add_child(shape)
	zone.body_entered.connect(_on_talk_entered)
	zone.body_exited.connect(_on_talk_exited)
	add_child(zone)


func _on_talk_entered(body: Node) -> void:
	if body.is_in_group("players") and body.has_method("set_talk_target"):
		body.set_talk_target(self)


func _on_talk_exited(body: Node) -> void:
	if body.is_in_group("players") and body.has_method("clear_talk_target"):
		body.clear_talk_target(self)


func _die(source: Node) -> void:
	dead = true
	if is_instance_valid(source) and source.is_in_group("players"):
		Score.register_kill(kind)
		if kind == "criminal" and source.has_method("gain_xp"):
			source.gain_xp(XP_CRIMINAL_KILL)
	if kind == "criminal":
		_drop_loot()
	died.emit(kind)
	queue_free()


## Coloca o NPC numa calçada, caminhando de `from` para `to` (nós do SidewalkGraph).
func start_on_sidewalk(from: Vector4i, to: Vector4i) -> void:
	use_sidewalks = true
	_sw_from = from
	_sw_to = to
	_sw_blocked = 0.0


func sidewalk_target() -> Vector4i:
	return _sw_to


func _walk_sidewalk(delta: float, speed: float, fleeing := false) -> void:
	var target := SidewalkGraph.position(_sw_to)
	if global_position.distance_to(target) < ARRIVE_DISTANCE:
		var arrived := _sw_to
		var next: Vector4i
		if fleeing:
			next = SidewalkGraph.farthest_neighbor(arrived, _flee_threat, _sw_from)
		else:
			next = SidewalkGraph.next_node(arrived, _sw_from, rng)
		_sw_from = arrived
		_sw_to = next
		target = SidewalkGraph.position(_sw_to)
	velocity = (target - global_position).normalized() * speed
	# Preso (gente, carro parado): depois de um tempo, volta pelo caminho.
	if get_slide_collision_count() > 0:
		_sw_blocked += delta
		if _sw_blocked > BLOCKED_TURN_BACK_TIME:
			_sw_blocked = 0.0
			var swap := _sw_from
			_sw_from = _sw_to
			_sw_to = swap
	else:
		_sw_blocked = maxf(_sw_blocked - delta, 0.0)


## Criminal morto larga dinheiro e, às vezes, um kit médico ou uma arma.
func _drop_loot() -> void:
	var parent := get_parent()
	if parent == null:
		return
	PickupScript.spawn(parent, global_position, "cash", rng.randi_range(LOOT_CASH_MIN, LOOT_CASH_MAX))
	if rng.randf() < LOOT_MEDKIT_CHANCE:
		PickupScript.spawn(parent, global_position + Vector2(26, 0), "medkit", 1)
	if rng.randf() < LOOT_WEAPON_CHANCE:
		PickupScript.spawn(parent, global_position + Vector2(-26, 0), "pistol", 1)


func _wander(delta: float) -> void:
	if activity != "":
		_act(delta)
		return
	if stationary:
		velocity = Vector2.ZERO
		return
	if use_sidewalks:
		_walk_sidewalk(delta, WALK_SPEED)
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = rng.randf_range(1.0, 3.0)
		if rng.randf() < 0.3:
			_wander_dir = Vector2.ZERO
		else:
			_wander_dir = Vector2.RIGHT.rotated(rng.randf() * TAU)
	var speed := WALK_SPEED if kind == "innocent" else WALK_SPEED * 0.7
	velocity = _wander_dir * speed


func _attack(target: Node2D) -> void:
	var to := target.global_position - global_position
	var dir := to.normalized()
	velocity = dir * CRIMINAL_SPEED if to.length() > KEEP_DISTANCE else Vector2.ZERO
	if _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		var aim := dir.rotated(rng.randf_range(-AIM_SPREAD, AIM_SPREAD))
		BulletScript.fire(get_parent(), global_position + aim * BULLET_OFFSET, aim, self, "players")
		Fx.shot(get_parent(), global_position, aim, false)


func _nearest_player_in_range() -> Node2D:
	var best: Node2D = null
	var best_dist := AGGRO_RANGE
	for p in get_tree().get_nodes_in_group("players"):
		var d := global_position.distance_to(p.global_position)
		if d <= best_dist:
			best = p
			best_dist = d
	return best


func _process(delta: float) -> void:
	_update_sprite(delta)


## Atividade de interior: parado no posto (olhando em volta), em ronda, sentado, deitado ou trabalhando.
func _act(delta: float) -> void:
	velocity = Vector2.ZERO
	match activity:
		"post":
			if _look_away > 0.0:
				_look_away -= delta
				if _look_away <= 0.0:
					_sprite_direction = facing
			else:
				_look_timer -= delta
				if _look_timer <= 0.0:
					_look_timer = rng.randf_range(LOOK_AROUND.x, LOOK_AROUND.y)
					_look_away = LOOK_AWAY_TIME
					var others: Array = CharacterSprites.DIRECTIONS.filter(func(d: String) -> bool: return d != facing)
					_sprite_direction = others[rng.randi_range(0, others.size() - 1)]
		"patrol":
			if route.size() < 2:
				return
			if _pause_timer > 0.0:
				_pause_timer -= delta
				return
			var to := route[_route_index] - global_position
			if to.length() <= ARRIVE_DISTANCE:
				_next_patrol_point()
				return
			velocity = to.normalized() * PATROL_SPEED


func _next_patrol_point() -> void:
	_route_index = (_route_index + 1) % route.size()
	_pause_timer = rng.randf_range(PATROL_PAUSE.x, PATROL_PAUSE.y)


## Interrompe a atividade (atacado): levanta, volta a ter colisão e passa a agir como civil comum.
func _stand_up() -> void:
	activity = ""
	(get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", false)


## Pose atual do sprite: "stand", "sit", "lie" ou "work".
func pose() -> String:
	if activity in ["sit", "lie", "work", "exercise", "dance"]:
		return activity
	return "stand"


## Aparência (roupa, cabelo, pele), determinística pela identidade.
func look() -> Dictionary:
	return _look


func sprite_direction() -> String:
	return _sprite_direction


func _update_sprite(delta: float) -> void:
	if _sprite == null:
		return
	var moving := velocity.length() >= MOVING_SPEED
	var current_pose := pose()
	var frame := 0
	if moving:
		_anim_time += delta
		_sprite_direction = CharacterSprites.direction_of(velocity)
		frame = 1 + int(_anim_time / WALK_FRAME_TIME) % 2
	elif current_pose in ["work", "exercise", "dance"]:
		_anim_time += delta
		frame = 1 + int(_anim_time / WORK_FRAME_TIME) % 2
	else:
		_anim_time = 0.0
	var key := "%s/%d/%s" % [_sprite_direction, frame, current_pose]
	if key != _shown_key:
		_shown_key = key
		_sprite.texture = SpriteFactory.character(_look, _sprite_direction, frame, current_pose)
	# Atordoado: fica azulado até passar.
	_sprite.modulate = Palette.get_color("sky") if stunned else Color.WHITE
