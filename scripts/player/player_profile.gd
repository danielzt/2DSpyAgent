extends RefCounted
## Ficha do jogador: nome, características, nível, XP e atributos.
## Todo atributo tem efeito real no jogo (ver STATS e os métodos de efeito).

signal changed

const MAX_LEVEL := 20
const MAX_STAT := 10
const POINTS_PER_LEVEL := 2
const START_POINTS := 3
const XP_PER_LEVEL := 50          # xp para o próximo nível = nível * 50
const BASE_HEALTH := 10.0
const START_MONEY := 200

const SPEED_PER_POINT := 0.06     # +6% de velocidade ao andar
const DAMAGE_PER_POINT := 0.20    # +20% de dano das armas
const HEALTH_PER_POINT := 2.0     # +2 de vida máxima
const XP_PER_POINT := 0.10        # +10% de XP

const STATS := [
	{"id": "speed", "name": "Velocidade", "effect": "+6% de velocidade ao andar por ponto"},
	{"id": "strength", "name": "Força", "effect": "+20% de dano das armas por ponto"},
	{"id": "vitality", "name": "Vitalidade", "effect": "+2 de vida máxima por ponto"},
	{"id": "intelligence", "name": "Inteligência",
		"effect": "+10% de XP por ponto; revela a personalidade dos NPCs (2 pts: 1 traço, 3 pts: 2 traços)"},
]

const PROFILES := [
	{"name": "Dante Ramos", "codename": "Falcão", "traits": ["Disciplinado", "Sarcástico"],
		"background": "Ex-detetive recrutado pela agência."},
	{"name": "Lúcia Prado", "codename": "Coruja", "traits": ["Observadora", "Impaciente"],
		"background": "Analista de campo promovida a agente."},
]

var player_name := ""
var codename := ""
var background := ""
var traits: Array = []
var money := START_MONEY
var level := 1
var xp := 0
var unspent := START_POINTS
var stats := {"speed": 1, "strength": 1, "vitality": 1, "intelligence": 1}
## Sementes de NPCs com quem já conversou (cada um dá XP só uma vez).
var talked := {}


func _init(p_index := 1) -> void:
	var p: Dictionary = PROFILES[(p_index - 1) % PROFILES.size()]
	player_name = p.name
	codename = p.codename
	background = p.background
	traits = p.traits.duplicate()


func stat(id: String) -> int:
	return stats.get(id, 0)


func xp_for_next() -> int:
	return XP_PER_LEVEL * level


## Soma XP; sobe de nível quantas vezes couber (cada nível dá pontos de atributo).
## Retorna quantos níveis subiu.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_for_next():
		xp -= xp_for_next()
		level += 1
		unspent += POINTS_PER_LEVEL
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	changed.emit()
	return gained


func add_money(amount: int) -> void:
	if amount != 0:
		money = maxi(money + amount, 0)
		changed.emit()


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	changed.emit()
	return true


func can_spend(id: String) -> bool:
	return unspent > 0 and stats.has(id) and stats[id] < MAX_STAT


func spend(id: String) -> bool:
	if not can_spend(id):
		return false
	stats[id] += 1
	unspent -= 1
	changed.emit()
	return true


# --- efeitos ---

func speed_multiplier() -> float:
	return 1.0 + SPEED_PER_POINT * (stat("speed") - 1)


func damage_multiplier() -> float:
	return 1.0 + DAMAGE_PER_POINT * (stat("strength") - 1)


func max_health() -> float:
	return BASE_HEALTH + HEALTH_PER_POINT * (stat("vitality") - 1)


func xp_multiplier() -> float:
	return 1.0 + XP_PER_POINT * (stat("intelligence") - 1)


## Quantos traços de personalidade de um NPC o jogador enxerga (0 a 2).
func visible_trait_count() -> int:
	return clampi(stat("intelligence") - 1, 0, 2)


## Texto do efeito atual de um atributo.
func effect_text(id: String) -> String:
	match id:
		"speed":
			return "andar %d%% mais rápido" % roundi((speed_multiplier() - 1.0) * 100.0)
		"strength":
			return "dano das armas +%d%%" % roundi((damage_multiplier() - 1.0) * 100.0)
		"vitality":
			return "vida máxima %d" % roundi(max_health())
		"intelligence":
			return "XP +%d%%, vê %d traço(s) dos NPCs" % [roundi((xp_multiplier() - 1.0) * 100.0), visible_trait_count()]
	return ""
