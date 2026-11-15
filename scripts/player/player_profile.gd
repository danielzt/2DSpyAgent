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
const XP_BOOST := 1.25            # bônus temporário de XP (sessão de cinema)
const DEFEAT_LOSS := 0.5          # fração do dinheiro em mãos perdida ao ser derrotado

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
## Vida atual, guardada entre trocas de cena (-1 = vida cheia).
var health := -1.0
## Dinheiro guardado no banco: não se perde ao ser derrotado.
var bank := 0
## Criminosos atordoados ainda não entregues na delegacia.
var prisoners := 0
## Cor dos carros da agência (CarSprites.AGENT_PAINTS), trocada na oficina.
var car_paint := "black"
## Segundos restantes do bônus de XP da sessão de cinema.
var xp_boost := 0.0
## Dia do mundo do último treino na academia e do último briefing com missão (-1 = nunca).
var last_train_day := -1
var last_briefing_day := -1
## Prédios que o jogador já visitou ou viu de perto: id -> true. Só eles ganham ícone no mapa.
var known_buildings := {}


## Quarteirões (grade de CityLayout.BLOCK sobre o mundo todo) já explorados: Vector2i -> true.
## O que não foi explorado fica sob neblina no mapa.
var explored := {}
## Pontos marcados no mapa: [{pos: Vector2, name: String}]. O ativo é o que o HUD indica.
var waypoints: Array = []
var active_waypoint := -1
const MAX_WAYPOINTS := 5
## Alcance da exploração: quarteirões cujo retângulo fica a até esta distância do jogador.
const EXPLORE_RADIUS := 600.0
const CELL := 560.0


static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / CELL)), int(floor(point.y / CELL)))


## Explora os quarteirões em volta de `point`. Retorna quantos eram novos.
func explore(point: Vector2) -> int:
	var added := 0
	var low := cell_of(point - Vector2(EXPLORE_RADIUS, EXPLORE_RADIUS))
	var high := cell_of(point + Vector2(EXPLORE_RADIUS, EXPLORE_RADIUS))
	for cx in range(low.x, high.x + 1):
		for cy in range(low.y, high.y + 1):
			var cell := Vector2i(cx, cy)
			var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
			if rect.grow(EXPLORE_RADIUS - 1.0).has_point(point) and not explored.has(cell):
				explored[cell] = true
				added += 1
	return added


func is_explored(point: Vector2) -> bool:
	return explored.has(cell_of(point))


## Novo ponto no mapa (vira o ativo). Se já houver MAX_WAYPOINTS, o mais antigo sai.
## Retorna o índice do ponto.
func add_waypoint(pos: Vector2, label := "") -> int:
	if waypoints.size() >= MAX_WAYPOINTS:
		waypoints.pop_front()
	var name_text := label if label != "" else "Ponto %d" % _next_number()
	waypoints.append({"pos": pos, "name": name_text})
	active_waypoint = waypoints.size() - 1
	return active_waypoint


func _next_number() -> int:
	var used := {}
	for w in waypoints:
		used[w.name] = true
	var n := 1
	while used.has("Ponto %d" % n):
		n += 1
	return n


func remove_waypoint(index: int) -> void:
	if index < 0 or index >= waypoints.size():
		return
	waypoints.remove_at(index)
	if waypoints.is_empty():
		active_waypoint = -1
	elif active_waypoint >= waypoints.size() or active_waypoint == index:
		active_waypoint = waypoints.size() - 1
	elif active_waypoint > index:
		active_waypoint -= 1


## Índice do ponto a até `radius` do ponto dado (o mais perto), ou -1.
func waypoint_near(pos: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius
	for i in waypoints.size():
		var d: float = (waypoints[i].pos as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = i
	return best


func active_waypoint_data() -> Dictionary:
	if active_waypoint < 0 or active_waypoint >= waypoints.size():
		return {}
	return waypoints[active_waypoint]


## Marca o prédio como conhecido. Retorna true se era novo.
func know_building(id: int) -> bool:
	if known_buildings.has(id):
		return false
	known_buildings[id] = true
	return true


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
	var boost := XP_BOOST if xp_boost > 0.0 else 1.0
	return (1.0 + XP_PER_POINT * (stat("intelligence") - 1)) * boost


## Derrota: perde parte do dinheiro que carrega (o do banco fica). Retorna quanto perdeu.
func lose_money_on_defeat() -> int:
	var lost := int(money * DEFEAT_LOSS)
	add_money(-lost)
	return lost


## Conta o tempo do bônus de XP.
func tick(delta: float) -> void:
	if xp_boost > 0.0:
		xp_boost = maxf(xp_boost - delta, 0.0)


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
