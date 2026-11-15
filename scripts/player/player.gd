extends CharacterBody2D
## Personagem top-down: anda com WASD (8 direções), mira no mouse, usa o item de cada mão
## (botão esquerdo/direito), interage (E), conversa (F), abre inventário (I) e ficha (C),
## e dirige veículos.

const HudScript := preload("res://scripts/ui/hud.gd")
const DialogScript := preload("res://scripts/ui/dialog_card.gd")
const InventoryPanelScript := preload("res://scripts/ui/inventory_panel.gd")
const CharacterSheetScript := preload("res://scripts/ui/character_sheet.gd")
const ShopPanelScript := preload("res://scripts/ui/shop_panel.gd")
const MapPanelScript := preload("res://scripts/ui/map_panel.gd")
const PausePanelScript := preload("res://scripts/ui/pause_panel.gd")
const RoutePlanner := preload("res://scripts/world/route_planner.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")
const BulletScript := preload("res://scripts/combat/bullet.gd")
const Fx := preload("res://scripts/effects/fx.gd")
const ShopDefsScript := preload("res://scripts/items/shop_defs.gd")
const ItemDefsScript := preload("res://scripts/items/item_defs.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")

signal died
signal leveled_up(new_level: int)
signal blocked

const MAX_HEALTH := 10.0           # vida base (a Vitalidade aumenta)
const BULLET_OFFSET := 20.0
const SHIELD_SLOWDOWN := 0.6       # velocidade ao andar com o escudo erguido
const SHIELD_COS := 0.34           # ~70° de cada lado da mira
const XP_FIRST_TALK := 5
const HANDS := ["left", "right"]
const ACTOR_Z := 3
const WALK_FRAME_TIME := 0.14      # segundos por quadro de passo
const MOVING_SPEED := 5.0
const AIM_DISTANCE := 16.0
## Tremor de câmera (Fase 5): deslocamento em px e duração.
const SHAKE_TIME := 0.15
const SHAKE_SHOTGUN := 3.0
const SHAKE_DAMAGE := 3.0

@export var player_index: int = 1
@export var speed: float = 220.0

var interactable: Node = null
var vehicle: Node = null
var talk_target: Node = null
var talking_with: Node = null
var region_name := ""
## Bairro e rua onde o jogador está (ou o nome do prédio, dentro de um interior).
var place_name := ""
## Alvos apontados pelas setas do HUD (posições no mundo): pista de crime, criminosos revelados.
var targets: Array = []
## Dinheiro perdido na última derrota (para o aviso).
var last_defeat_loss := 0
var hud
var dialog
var inventory_panel
var character_sheet
var shop_panel
var map_panel
var pause_panel
var profile: RefCounted
var inventory: RefCounted
var health: float = MAX_HEALTH
var respawn_position := Vector2.ZERO
## Vira true no primeiro movimento do mouse (jogador 1); a partir daí a mira segue o mouse.
var mouse_active := false
## Permite trocar a origem da posição do mouse no mundo (usado em testes).
var mouse_world_provider := Callable()

var _facing := Vector2.DOWN
var _cooldowns := {"left": 0.0, "right": 0.0}
var _shield_raised := false
var _last_max_health := MAX_HEALTH
var _sprite: Sprite2D
var _aim_sprite: Sprite2D
var _look := {}
var _anim_time := 0.0
var _shown_key := ""
var _shake_time := 0.0
var _shake_amount := 0.0
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("players")
	z_index = ACTOR_Z
	_look = CharacterSprites.agent_look(player_index)
	_sprite = SpriteFactory.make_sprite(null, Vector2(CharacterSprites.PIVOT))
	add_child(_sprite)
	_aim_sprite = Sprite2D.new()
	_aim_sprite.scale = Vector2(SpriteFactory.TEXEL, SpriteFactory.TEXEL)
	add_child(_aim_sprite)
	respawn_position = global_position
	profile = GameState.profile_for(player_index)
	inventory = GameState.inventory_for(player_index)
	# A vida é guardada na ficha entre trocas de cena (entrar em um prédio não cura).
	health = max_health() if profile.health <= 0.0 else minf(profile.health, max_health())
	_last_max_health = max_health()
	profile.changed.connect(_on_profile_changed)
	hud = HudScript.new()
	add_child(hud)
	dialog = DialogScript.new()
	add_child(dialog)
	dialog.closed.connect(_on_dialog_closed)
	inventory_panel = InventoryPanelScript.new()
	add_child(inventory_panel)
	character_sheet = CharacterSheetScript.new()
	add_child(character_sheet)
	shop_panel = ShopPanelScript.new()
	add_child(shop_panel)
	map_panel = MapPanelScript.new()
	map_panel.player_index = player_index
	add_child(map_panel)
	pause_panel = PausePanelScript.new()
	pause_panel.player_index = player_index
	add_child(pause_panel)


func _exit_tree() -> void:
	if profile != null:
		profile.health = health
	if profile != null and profile.changed.is_connected(_on_profile_changed):
		profile.changed.disconnect(_on_profile_changed)


func _input(event: InputEvent) -> void:
	if player_index == 1 and event is InputEventMouseMotion:
		mouse_active = true


## Pausa (Esc): os painéis abertos tratam o Esc antes e o consomem, então só chega aqui sem painel.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p%d_pause" % player_index) and not event.is_echo():
		pause()
		get_viewport().set_input_as_handled()


## Abre a tela de pausa (congela o jogo).
func pause() -> void:
	if pause_panel.is_open() or panels_open() or Transition.busy:
		return
	var where := global_position
	if GameState.is_inside():
		where = GameState.return_position  # dentro de prédios, o mapa mostra a porta
	pause_panel.open(GameState.world_layout(), profile.known_buildings, where, player_index, profile)


func _process(delta: float) -> void:
	_update_sprite(delta)
	_update_shake(delta)
	profile.tick(delta)
	hud.set_clock(WorldClock.text())
	hud.set_targets(global_position, targets)
	_follow_waypoint()
	if GameState.is_inside():
		hud.hide_minimap()
	else:
		hud.set_minimap(GameState.world_layout(), profile.known_buildings, global_position, targets, delta, profile)
	hud.set_prompt(current_prompt())
	hud.set_region(region_name)
	hud.set_place(place_name)
	hud.set_health(health, max_health())
	hud.set_level("Nível %d • XP %d/%d" % [profile.level, profile.xp, profile.xp_for_next()])
	hud.set_hands(hands_text())
	hud.set_money(profile.money)


func _physics_process(delta: float) -> void:
	var prefix := "p%d_" % player_index
	for hand in HANDS:
		_cooldowns[hand] = maxf(_cooldowns[hand] - delta, 0.0)
	_shield_raised = false

	if is_instance_valid(vehicle):
		# Dirigindo: o jogador acompanha o carro (a câmera é filha do jogador).
		global_position = vehicle.global_position
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed(prefix + "interact"):
			exit_vehicle()
		return
	vehicle = null

	if talking_with != null:
		velocity = Vector2.ZERO
		if not is_instance_valid(talking_with) or not talking_with.talking:
			end_conversation()  # NPC saiu, morreu ou foi atacado
		elif Input.is_action_just_pressed(prefix + "talk"):
			end_conversation()
		return

	if Input.is_action_just_pressed(prefix + "inventory"):
		toggle_inventory()
	if Input.is_action_just_pressed(prefix + "character"):
		toggle_character()
	if Input.is_action_just_pressed(prefix + "map"):
		toggle_map()
	if panels_open():
		velocity = Vector2.ZERO
		return

	var dir := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if mouse_active:
		_update_mouse_aim()
	elif dir != Vector2.ZERO:
		face(dir)
	_process_hands(prefix)  # depois da mira: o primeiro tiro já sai na direção certa
	velocity = dir * speed * profile.speed_multiplier() * (SHIELD_SLOWDOWN if _shield_raised else 1.0)
	move_and_slide()
	if Input.is_action_just_pressed(prefix + "interact"):
		try_interact()
	if Input.is_action_just_pressed(prefix + "talk"):
		try_talk()


# --- mira ---

func _update_mouse_aim() -> void:
	var point: Vector2 = mouse_world_provider.call() if mouse_world_provider.is_valid() else get_global_mouse_position()
	aim_at(point)


## Vira o jogador para um ponto do mundo.
func aim_at(point: Vector2) -> void:
	face(point - global_position)


func face(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_facing = dir.normalized()


func facing() -> Vector2:
	return _facing


# --- interação (E) ---

func set_interactable(zone: Node) -> void:
	interactable = zone


func clear_interactable(zone: Node) -> void:
	if interactable == zone:
		interactable = null


func try_interact() -> void:
	if is_instance_valid(interactable):
		interactable.interact(self)


# --- conversa (F) ---

func set_talk_target(npc: Node) -> void:
	talk_target = npc


func clear_talk_target(npc: Node) -> void:
	if talk_target == npc:
		talk_target = null


func try_talk() -> bool:
	if is_instance_valid(talk_target) and talk_target.can_talk():
		return start_conversation(talk_target)
	return false


func start_conversation(npc: Node) -> bool:
	if talking_with != null or is_instance_valid(vehicle) or panels_open() or not npc.can_talk():
		return false
	talking_with = npc
	npc.set_talking(true)
	dialog.open(npc.identity, profile.visible_trait_count())
	var seed_key: int = npc.identity.seed
	if not profile.talked.has(seed_key):
		profile.talked[seed_key] = true
		gain_xp(XP_FIRST_TALK)
	return true


func end_conversation() -> void:
	var npc := talking_with
	talking_with = null
	if is_instance_valid(npc):
		npc.set_talking(false)
	dialog.close()


func _on_dialog_closed() -> void:
	if talking_with != null:
		end_conversation()


# --- painéis (I / C) ---

func panels_open() -> bool:
	return inventory_panel.is_open() or character_sheet.is_open() or shop_panel.is_open() or map_panel.is_open()


func toggle_inventory() -> void:
	if inventory_panel.is_open():
		inventory_panel.close()
		return
	character_sheet.close()
	shop_panel.close()
	map_panel.close()
	inventory_panel.open(inventory)


func toggle_character() -> void:
	if character_sheet.is_open():
		character_sheet.close()
		return
	inventory_panel.close()
	shop_panel.close()
	map_panel.close()
	character_sheet.open(profile)


## Chegou a este alcance (px) do ponto marcado: o ponto some e o HUD avisa.
const WAYPOINT_ARRIVE := 110.0
## A rota é refeita quando o ponto muda ou o jogador anda tanto (px) desde o último cálculo.
const ROUTE_REPLAN_DISTANCE := 90.0
## Espaço entre os pontos da trilha da rota (px do mundo).
const ROUTE_DOT_SPACING := 36.0

var _route_for := Vector2(-1.0e9, -1.0e9)
var _route_from := Vector2(-1.0e9, -1.0e9)


## O HUD indica o ponto ativo do mapa (só na rua); chegando perto, ele é desfeito.
func _follow_waypoint() -> void:
	var waypoint: Dictionary = profile.active_waypoint_data()
	if GameState.is_inside() or waypoint.is_empty():
		hud.set_waypoint(global_position, {})
		hud.set_route([] as Array[Vector2])
		_route_for = Vector2(-1.0e9, -1.0e9)
		return
	if global_position.distance_to(waypoint.pos) <= WAYPOINT_ARRIVE:
		notify("Chegou a %s" % waypoint.name, 4.0)
		profile.remove_waypoint(profile.active_waypoint)
		hud.set_waypoint(global_position, {})
		hud.set_route([] as Array[Vector2])
		_route_for = Vector2(-1.0e9, -1.0e9)
		return
	hud.set_waypoint(global_position, waypoint)
	_update_route(waypoint.pos)


## Refaz a trilha da rota pelas ruas quando preciso (ponto novo ou o jogador saiu do caminho).
func _update_route(target: Vector2) -> void:
	if target == _route_for and global_position.distance_to(_route_from) < ROUTE_REPLAN_DISTANCE:
		return
	_route_for = target
	_route_from = global_position
	hud.set_route(RoutePlanner.dots(RoutePlanner.plan(global_position, target), ROUTE_DOT_SPACING))


## Abre ou fecha o mapa de tela cheia (só na rua: dentro de prédios não há mapa).
func toggle_map() -> void:
	if map_panel.is_open():
		map_panel.close()
		return
	if GameState.is_inside():
		notify("O mapa só funciona na rua", 2.0)
		return
	inventory_panel.close()
	character_sheet.close()
	shop_panel.close()
	map_panel.open(GameState.world_layout(), profile.known_buildings, global_position, targets, profile)


# --- loja, itens no chão, avisos ---

func open_shop(shop_id: String) -> bool:
	if is_instance_valid(vehicle) or talking_with != null or not ShopDefsScript.exists(shop_id):
		return false
	inventory_panel.close()
	character_sheet.close()
	shop_panel.open(shop_id, inventory, profile)
	return true


## Recolhe um item do chão. "cash" soma dinheiro. Retorna false se não coube na mochila.
func pick_up(item_id: String, amount: int) -> bool:
	if item_id == "cash":
		profile.add_money(amount)
		notify("+$%d" % amount)
		return true
	if inventory.add(item_id, amount):
		var item_name: String = ItemDefsScript.get_def(item_id).get("name", item_id)
		notify("Pegou %s" % item_name)
		return true
	notify("Mochila cheia")
	return false


## Aviso temporário no topo da tela.
func notify(text: String, seconds := 5.0) -> void:
	hud.show_toast(text, seconds)


# --- ficha: XP, atributos ---

func max_health() -> float:
	return profile.max_health()


## XP base já multiplicado pela Inteligência. Retorna quantos níveis subiu.
func gain_xp(base_amount: int) -> int:
	var levels: int = profile.add_xp(roundi(base_amount * profile.xp_multiplier()))
	if levels > 0:
		leveled_up.emit(profile.level)
	return levels


func _on_profile_changed() -> void:
	var new_max := max_health()
	if new_max > _last_max_health:
		health += new_max - _last_max_health  # Vitalidade também cura a diferença
	_last_max_health = new_max
	health = minf(health, new_max)


# --- mãos ---

func hands_text() -> String:
	return "Esq: %s    Dir: %s" % [_hand_label("left"), _hand_label("right")]


func _hand_label(hand: String) -> String:
	var def: Dictionary = inventory.equipped_def(hand)
	if def.is_empty():
		return "—"
	if def.kind == "tool":
		return "%s ×%d" % [def.name, inventory.count(def.id)]
	return def.name


func _process_hands(prefix: String) -> void:
	for hand in HANDS:
		var def: Dictionary = inventory.equipped_def(hand)
		if def.is_empty():
			continue
		var action: String = prefix + "use_" + hand
		match def.kind:
			"weapon":
				if Input.is_action_pressed(action):
					fire_hand(hand)
			"tool":
				if Input.is_action_just_pressed(action):
					use_tool(hand)
			"shield":
				if Input.is_action_pressed(action):
					_shield_raised = true


func is_shield_raised() -> bool:
	return _shield_raised


## Usa a arma da mão. Retorna o primeiro projétil, ou null (recarga, sem arma, dirigindo, menus).
func fire_hand(hand: String) -> Node:
	if is_instance_valid(vehicle) or talking_with != null or panels_open() or _cooldowns[hand] > 0.0:
		return null
	var def: Dictionary = inventory.equipped_def(hand)
	if def.is_empty() or def.kind != "weapon":
		return null
	_cooldowns[hand] = def.interval
	var damage: float = def.damage * profile.damage_multiplier()
	var first: Node = null
	var pellets: int = def.pellets
	for i in pellets:
		var offset := 0.0
		if pellets > 1:
			offset = lerpf(-def.spread / 2.0, def.spread / 2.0, float(i) / (pellets - 1))
		var dir := _facing.rotated(offset)
		var bullet := BulletScript.fire(get_parent(), global_position + dir * BULLET_OFFSET, dir, self,
				"npcs", damage, def.effect, def.lifetime)
		if first == null:
			first = bullet
	Fx.shot(get_parent(), global_position, _facing, true)
	if pellets > 1:
		shake(SHAKE_SHOTGUN)  # escopeta dá coice
	return first


## Atalho: dispara a arma da mão esquerda.
func fire() -> Node:
	return fire_hand("left")


## Usa a ferramenta da mão (kit médico). Retorna true se foi usada.
func use_tool(hand: String) -> bool:
	var def: Dictionary = inventory.equipped_def(hand)
	if def.is_empty() or def.kind != "tool" or not def.has("heal"):
		return false
	if health >= max_health():
		return false  # não gasta o kit com vida cheia
	health = minf(health + def.heal, max_health())
	inventory.consume(def.id)
	return true


func take_damage(amount: float, source: Node = null) -> void:
	if _blocks(source):
		blocked.emit()
		return
	health -= amount
	shake(SHAKE_DAMAGE)
	if health <= 0.0:
		_die()


## O escudo ergue-se na direção da mira e barra tiros vindos da frente.
func _blocks(source: Node) -> bool:
	if not _shield_raised or not is_instance_valid(source) or not source is Node2D:
		return false
	var to_source: Vector2 = ((source as Node2D).global_position - global_position).normalized()
	return _facing.dot(to_source) >= SHIELD_COS


func _die() -> void:
	if is_instance_valid(vehicle):
		exit_vehicle()
	if talking_with != null:
		end_conversation()
	# Derrota: perde parte do dinheiro em mãos (o do banco fica) e volta ao ponto de retorno
	# (o mundo o troca pela porta do hospital).
	last_defeat_loss = profile.lose_money_on_defeat()
	health = max_health()
	global_position = respawn_position
	velocity = Vector2.ZERO
	died.emit()


# --- veículos ---

func enter_vehicle(car: Node) -> bool:
	if is_instance_valid(vehicle) or talking_with != null or panels_open() or car.driver != null or car.ai_controlled:
		return false
	vehicle = car
	car.driver = self
	visible = false
	$CollisionShape2D.disabled = true
	global_position = car.global_position
	return true


func exit_vehicle() -> bool:
	if not is_instance_valid(vehicle):
		return false
	var car := vehicle
	$CollisionShape2D.disabled = false
	# Tenta sair pela esquerda, direita ou traseira do carro, onde houver espaço livre.
	var offsets := [Vector2(0, -52), Vector2(0, 52), Vector2(-60, 0)]
	for off in offsets:
		global_position = car.global_position + (off as Vector2).rotated(car.rotation)
		if not test_move(global_transform, Vector2.ZERO):
			break
	car.driver = null
	vehicle = null
	visible = true
	return true


## Instrução exibida no canto da tela, ou "" se não houver.
func current_prompt() -> String:
	if is_instance_valid(vehicle):
		return "Pressione %s para sair do carro" % InputSetupScript.key_label("p%d_interact" % player_index)
	if talking_with != null or panels_open():
		return ""
	var lines: Array[String] = []
	if is_instance_valid(interactable):
		lines.append(interactable.prompt_text(self))
	if is_instance_valid(talk_target) and talk_target.can_talk():
		lines.append("Pressione %s para falar com %s" % [
			InputSetupScript.key_label("p%d_talk" % player_index), talk_target.display_name])
	return "\n".join(lines)


## Sacode a câmera por um instante (tiro de escopeta, batida, dano). `amount` em px (2 a 4).
## Desligado se GameState.screen_shake for falso.
func shake(amount: float, seconds := SHAKE_TIME) -> void:
	if not GameState.screen_shake:
		return
	if amount >= _shake_amount or _shake_time <= 0.0:
		_shake_amount = amount
	_shake_time = maxf(_shake_time, seconds)


## Tremor em andamento (para testes e para a UI).
func is_shaking() -> bool:
	return _shake_time > 0.0


func _update_shake(delta: float) -> void:
	var cam: Camera2D = $Camera2D
	if _shake_time <= 0.0:
		if cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_shake_amount = 0.0
		cam.offset = Vector2.ZERO
		return
	cam.offset = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * _shake_amount


func set_camera_limits(bounds: Rect2) -> void:
	var cam: Camera2D = $Camera2D
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)


# --- sprite ---

## Direção do sprite (down, up, left, right) conforme a mira.
func sprite_direction() -> String:
	return CharacterSprites.direction_of(_facing)


## Quadro de animação: 0 parado, 1 e 2 andando.
func sprite_frame() -> int:
	if velocity.length() < MOVING_SPEED:
		return 0
	return 1 + int(_anim_time / WALK_FRAME_TIME) % 2


func _update_sprite(delta: float) -> void:
	if _sprite == null:
		return
	if velocity.length() >= MOVING_SPEED:
		_anim_time += delta
	else:
		_anim_time = 0.0
	var direction := sprite_direction()
	var frame := sprite_frame()
	var key := "%s/%d" % [direction, frame]
	if key != _shown_key:
		_shown_key = key
		_sprite.texture = SpriteFactory.character(_look, direction, frame)
	# Arma (ou retículo) no ângulo exato da mira.
	var armed := false
	for hand in HANDS:
		var def: Dictionary = inventory.equipped_def(hand)
		if not def.is_empty() and def.kind == "weapon":
			armed = true
	_aim_sprite.texture = SpriteFactory.prop("gun_hand" if armed else "aim")
	_aim_sprite.position = _facing * AIM_DISTANCE + Vector2(0.0, -2.0)
	_aim_sprite.rotation = _facing.angle() if armed else 0.0
	_aim_sprite.flip_v = armed and _facing.x < 0.0
	_aim_sprite.z_index = -1 if _facing.y < -0.5 else 0
