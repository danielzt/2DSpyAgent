extends RefCounted
## Lista de controles para as telas de título e pausa, montada das ações reais do jogador
## (assim a lista nunca fica diferente das teclas de verdade).

const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")


static func _key(player_index: int, action: String) -> String:
	return InputSetupScript.key_label("p%d_%s" % [player_index, action])


## Pares [ação, teclas] do jogador.
static func lines(player_index := 1) -> Array[Array]:
	var move := "%s %s %s %s" % [_key(player_index, "up"), _key(player_index, "left"),
			_key(player_index, "down"), _key(player_index, "right")]
	var hands := "Botões do mouse" if player_index == 1 else "%s / %s" % [
			_key(player_index, "use_left"), _key(player_index, "use_right")]
	var aim := "Mouse" if player_index == 1 else "Direção do movimento"
	return [
		["Andar", move],
		["Mirar", aim],
		["Mão esq. / dir.", hands],
		["Interagir e dirigir", _key(player_index, "interact")],
		["Falar", _key(player_index, "talk")],
		["Mochila", _key(player_index, "inventory")],
		["Ficha do agente", _key(player_index, "character")],
		["Mapa", _key(player_index, "map")],
		["Pausa", _key(player_index, "pause")],
	]
