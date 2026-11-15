extends Node
## Pontuação do agente. Regra de design: matar inocentes tira pontos.

signal changed(points: int)

const INNOCENT_PENALTY := 100
const CRIMINAL_REWARD := 50
const STUN_CRIMINAL_REWARD := 30
const STUN_INNOCENT_PENALTY := 20

var points := 0


## Registra uma morte ("innocent" ou "criminal"). Retorna a variação de pontos.
func register_kill(kind: String) -> int:
	var delta := 0
	match kind:
		"innocent":
			delta = -INNOCENT_PENALTY
		"criminal":
			delta = CRIMINAL_REWARD
		_:
			push_warning("Tipo de morte desconhecido: %s" % kind)
			return 0
	points += delta
	changed.emit(points)
	return delta


## Atordoar sem matar: criminal dá pontos, inocente tira poucos.
func register_stun(kind: String) -> int:
	var delta := 0
	match kind:
		"criminal":
			delta = STUN_CRIMINAL_REWARD
		"innocent":
			delta = -STUN_INNOCENT_PENALTY
		_:
			return 0
	points += delta
	changed.emit(points)
	return delta


## Crime resolvido (todos os criminosos mortos ou atordoados): bônus de pontos.
func register_incident(reward: int) -> int:
	points += reward
	changed.emit(points)
	return reward


func reset() -> void:
	points = 0
	changed.emit(points)
