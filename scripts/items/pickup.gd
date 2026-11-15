extends "res://scripts/interaction/interact_zone.gd"
## Item no chão. Dinheiro ("cash") é recolhido ao encostar; os demais itens exigem a
## tecla de interação (E), como portas e carros.

const ItemDefs := preload("res://scripts/items/item_defs.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const ITEM_Z := 1
const SPRITES := ["cash", "medkit", "pistol", "shotgun", "taser", "shield"]

@export var item_id := ""   # "cash" = dinheiro
@export var amount := 1


## Cria um item no chão em `parent`.
static func spawn(parent: Node, pos: Vector2, p_item_id: String, p_amount: int) -> Node:
	var pickup: Node2D = (load("res://scripts/items/pickup.gd") as GDScript).new()
	pickup.item_id = p_item_id
	pickup.amount = p_amount
	pickup.position = pos
	parent.add_child(pickup)
	return pickup


func _ready() -> void:
	verb = "pegar %s" % display_name()
	if get_child_count() == 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		shape.shape = circle
		add_child(shape)
	add_to_group("pickups")
	z_index = ITEM_Z
	super._ready()
	queue_redraw()


func display_name() -> String:
	if item_id == "cash":
		return "$%d" % amount
	var def := ItemDefs.get_def(item_id)
	var item_name: String = def.get("name", item_id)
	return item_name if amount <= 1 else "%s ×%d" % [item_name, amount]


func _on_body_entered(body: Node) -> void:
	if item_id == "cash" and body.is_in_group("players") and body.has_method("pick_up"):
		collect(body)
	else:
		super._on_body_entered(body)


func interact(player: Node) -> void:
	collect(player)


## Entrega o item ao jogador; some se ele aceitou.
func collect(player: Node) -> bool:
	if is_queued_for_deletion():
		return false
	var ok: bool = player.pick_up(item_id, amount)
	if ok:
		queue_free()
	return ok


## Sprite usado para este item ("item" = caixa genérica).
func sprite_id() -> String:
	return item_id if SPRITES.has(item_id) else "item"


func _draw() -> void:
	var texture := SpriteFactory.prop(sprite_id())
	var size := Vector2(texture.get_size()) * SpriteFactory.TEXEL
	draw_texture_rect(texture, Rect2(-size / 2.0, size), false)
