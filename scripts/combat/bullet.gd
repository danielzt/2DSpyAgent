extends Area2D
## Projétil. Fere o primeiro corpo do grupo `target_group` que atingir;
## some ao bater em paredes/carros e atravessa personagens que não são alvo.

const BULLET_SCENE_PATH := "res://scenes/combat/bullet.tscn"
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const BULLET_Z := 4

var direction := Vector2.RIGHT
var speed := 900.0
var damage := 1.0
var effect := "damage"   # "damage" ou "stun"
var target_group := "npcs"
var shooter: Node = null
var lifetime := 0.7

const STUN_TIME := 3.0


## Cria um projétil em `parent`. `target_group`: "npcs" (tiro do jogador) ou "players" (tiro de criminoso).
static func fire(parent: Node, origin: Vector2, dir: Vector2, p_shooter: Node, p_target_group: String,
		p_damage := 1.0, p_effect := "damage", p_lifetime := 0.7) -> Node:
	var bullet: Node = load(BULLET_SCENE_PATH).instantiate()
	bullet.direction = dir.normalized()
	bullet.shooter = p_shooter
	bullet.target_group = p_target_group
	bullet.damage = p_damage
	bullet.effect = p_effect
	bullet.lifetime = p_lifetime
	bullet.position = origin
	parent.add_child(bullet)
	return bullet


func _ready() -> void:
	add_to_group("bullets")
	z_index = BULLET_Z
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.is_in_group(target_group):
		if effect == "stun" and body.has_method("stun"):
			body.stun(STUN_TIME, shooter)
		else:
			body.take_damage(damage, shooter)
		queue_free()
		return
	if body.is_in_group("vehicles"):
		# Tiro em carro com motorista fere o motorista (quando o alvo são jogadores).
		if target_group == "players" and is_instance_valid(body.driver):
			body.driver.take_damage(damage, shooter)
		queue_free()
		return
	if body.is_in_group("players") or body.is_in_group("npcs"):
		return  # atravessa personagens que não são alvo
	queue_free()


func _draw() -> void:
	var texture := SpriteFactory.prop("bullet_stun" if effect == "stun" else "bullet")
	var size := Vector2(texture.get_size()) * SpriteFactory.TEXEL
	draw_texture_rect(texture, Rect2(-size / 2.0, size), false)
