extends Node2D
## Cena principal: mundo (Cidade + Campo) e jogador 1 com câmera.
## Ao entrar num prédio a cena não é destruída: o GameState a guarda fora da árvore
## (congelada) e a devolve ao sair, chamando `resume_from_interior`.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WorldLayout := preload("res://scripts/world/world_layout.gd")

var player: Node


func _ready() -> void:
	add_to_group(GameState.WORLD_GROUP)
	player = PLAYER_SCENE.instantiate()
	player.player_index = 1
	if GameState.has_return:
		player.position = GameState.consume_return_position()
	else:
		player.position = WorldLayout.spawn_point()
	add_child(player)
	player.set_camera_limits(Rect2(Vector2.ZERO, WorldLayout.world_size()))


## De volta da rua: o jogador reaparece na porta do prédio; o resto do mundo segue como estava.
func resume_from_interior() -> void:
	if not is_instance_valid(player):
		return
	if GameState.has_return:
		player.global_position = GameState.consume_return_position()
	player.velocity = Vector2.ZERO
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		cam.make_current()
		cam.reset_smoothing()
