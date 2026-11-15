extends Node2D
## Cena principal: mundo (Cidade + Campo) e jogador 1 com câmera.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WorldLayout := preload("res://scripts/world/world_layout.gd")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.player_index = 1
	if GameState.has_return:
		player.position = GameState.consume_return_position()
	else:
		player.position = WorldLayout.spawn_point()
	add_child(player)
	player.set_camera_limits(Rect2(Vector2.ZERO, WorldLayout.world_size()))
