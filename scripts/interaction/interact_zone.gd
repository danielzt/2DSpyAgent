extends Area2D
## Zona de interação: quando um jogador está dentro, aparece a instrução
## "Pressione E para <verbo>"; a ação só acontece ao pressionar a tecla.

const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

signal interacted(player: Node)

@export var verb := "entrar"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.has_method("set_interactable"):
		body.set_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("players") and body.has_method("clear_interactable"):
		body.clear_interactable(self)


func prompt_text(player: Node) -> String:
	var key: String = InputSetupScript.key_label("p%d_interact" % player.player_index)
	return "Pressione %s para %s" % [key, verb]


func interact(player: Node) -> void:
	interacted.emit(player)
