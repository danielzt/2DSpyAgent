extends RefCounted
## Serviços dos interiores (lógica pura, no formato do ShopDefs.buy): cada um cobra o seu
## preço e produz um efeito real no jogo. Nenhum é enfeite.
## Toda interação passa por uma InteractZone e pela ação `p{N}_interact`; o verbo aparece no HUD.
##
## `actor`: quem usa o serviço (o jogador): precisa de `health`, `max_health()` e `profile`.
## `world`: {clock, state, score, tip_provider}: relógio do mundo, estado global (pista e
## revelação de criminosos), pontuação e uma função que sorteia uma pista de crime.

const CarSprites := preload("res://scripts/art/car_sprites.gd")

const DELIVERY_POINTS := 40
const DELIVERY_MONEY := 30
const HEAL_COST_PER_POINT := 5
const BANK_STEP := 100
const WAKE_HOUR := 7.0
const MOVIE_HOURS := 2.0
const MOVIE_XP_BOOST_SECONDS := 300.0
const INFORMANT_SECONDS := 60.0
## Kits médicos que o baú da casa do agente repõe por dia.
const STASH_KITS := 3

const DEFS := {
	"sleep": {"verb": "dormir", "cost": 40},
	"meal": {"verb": "pedir uma refeição", "cost": 25, "heal": 6.0},
	"snack": {"verb": "pedir um lanche", "cost": 10, "heal": 3.0},
	"rumor": {"verb": "pagar uma rodada e ouvir os rumores", "cost": 15},
	"informant": {"verb": "falar com o informante", "cost": 50},
	"heal": {"verb": "ser atendido", "cost": 0},
	"deliver": {"verb": "entregar os presos", "cost": 0},
	"deposit": {"verb": "depositar $%d" % BANK_STEP, "cost": 0},
	"withdraw": {"verb": "sacar $%d" % BANK_STEP, "cost": 0},
	"briefing": {"verb": "ouvir o briefing", "cost": 0},
	"paint": {"verb": "pintar o carro da agência", "cost": 30},
	"movie": {"verb": "assistir a uma sessão", "cost": 20},
	"train": {"verb": "treinar", "cost": 30, "xp": 20},
	"rest": {"verb": "dormir até de manhã", "cost": 0},
	"stash": {"verb": "abrir o baú de equipamento", "cost": 0},
}

## Serviços oferecidos por tipo de prédio (as lojas usam o ShopDefs).
const BY_TYPE := {
	"hotel": ["sleep"], "restaurant": ["meal"], "diner": ["snack"], "bar": ["rumor"],
	"club": ["informant"], "hospital": ["heal"], "police": ["deliver"], "bank": ["deposit", "withdraw"],
	"hq": ["briefing"], "workshop": ["paint"], "cinema": ["movie"], "gym": ["train"],
	"agent_home": ["rest", "stash"],
}


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func for_type(type: String) -> Array:
	return BY_TYPE.get(type, [])


static func cost(id: String) -> int:
	return DEFS[id].cost if DEFS.has(id) else 0


## Verbo da instrução do HUD, com o preço: "dormir ($40)".
static func verb(id: String) -> String:
	if not DEFS.has(id):
		return ""
	var text: String = DEFS[id].verb
	if id == "heal":
		return "%s ($%d por ponto de vida)" % [text, HEAL_COST_PER_POINT]
	return "%s ($%d)" % [text, cost(id)] if cost(id) > 0 else text


## Usa o serviço. Retorna {result, message}; `result` é "ok", "no_money", "no_need"
## (nada a fazer), "already" (já feito hoje) ou "unknown".
static func use(id: String, actor: Object, world := {}) -> Dictionary:
	if not DEFS.has(id):
		return _r("unknown", "")
	var profile: RefCounted = actor.profile
	var clock: Object = world.get("clock")
	var state: Object = world.get("state")
	match id:
		"sleep":
			if not profile.spend_money(cost(id)):
				return _no_money()
			actor.health = actor.max_health()
			if clock != null:
				clock.advance_to(WAKE_HOUR)
			return _r("ok", "Você dormiu bem. Vida cheia; são %s." % _time(clock))
		"rest":
			actor.health = actor.max_health()
			if clock != null:
				clock.advance_to(WAKE_HOUR)
			return _r("ok", "Você dormiu em casa. Vida cheia; são %s." % _time(clock))
		"stash":
			var today: int = int(clock.day()) if clock != null else 0
			if profile.last_stash_day == today:
				return _r("no_need", "O baú está como você deixou hoje.")
			var inv: RefCounted = actor.inventory
			var missing_kits := maxi(STASH_KITS - inv.count("medkit"), 0)
			profile.last_stash_day = today
			if missing_kits > 0:
				inv.add("medkit", missing_kits)
				return _r("ok", "Você repôs %d kit(s) médico(s) do baú." % missing_kits)
			return _r("no_need", "Seus kits médicos já estão completos.")
		"meal", "snack":
			if actor.health >= actor.max_health():
				return _r("no_need", "Você não está com fome (vida cheia).")
			if not profile.spend_money(cost(id)):
				return _no_money()
			var before: float = actor.health
			actor.health = minf(actor.health + DEFS[id].heal, actor.max_health())
			return _r("ok", "Bom apetite! +%d de vida." % roundi(actor.health - before))
		"heal":
			var missing := ceili(actor.max_health() - actor.health)
			if missing <= 0:
				return _r("no_need", "Você está ótimo. Nada a tratar.")
			if not profile.spend_money(missing * HEAL_COST_PER_POINT):
				return _no_money()
			actor.health = actor.max_health()
			return _r("ok", "Atendimento feito: vida cheia por $%d." % (missing * HEAL_COST_PER_POINT))
		"deliver":
			var count: int = profile.prisoners
			if count <= 0:
				return _r("no_need", "Nenhum preso a entregar. Atordoe criminosos com o taser.")
			profile.prisoners = 0
			profile.add_money(count * DELIVERY_MONEY)
			var score: Object = world.get("score")
			if score != null:
				score.register_incident(count * DELIVERY_POINTS)
			return _r("ok", "%d preso(s) entregue(s): +%d pontos e +$%d." % [count, count * DELIVERY_POINTS, count * DELIVERY_MONEY])
		"deposit":
			var amount := mini(BANK_STEP, profile.money)
			if amount <= 0:
				return _r("no_need", "Você não tem dinheiro para depositar.")
			profile.spend_money(amount)
			profile.bank += amount
			return _r("ok", "Depositado $%d. Saldo no banco: $%d." % [amount, profile.bank])
		"withdraw":
			var amount := mini(BANK_STEP, profile.bank)
			if amount <= 0:
				return _r("no_need", "Sua conta está vazia.")
			profile.bank -= amount
			profile.add_money(amount)
			return _r("ok", "Sacado $%d. Saldo no banco: $%d." % [amount, profile.bank])
		"rumor":
			if state != null and not (state.tip as Dictionary).is_empty():
				return _r("already", "Você já tem uma pista: %s." % tip_text(state.tip))
			var tip := _new_tip(world)
			if tip.is_empty():
				return _r("no_need", "Ninguém ouviu nada hoje.")
			if not profile.spend_money(cost(id)):
				return _no_money()
			state.tip = tip
			return _r("ok", "Rumor: %s. A seta no HUD mostra o caminho." % tip_text(tip))
		"informant":
			if not profile.spend_money(cost(id)):
				return _no_money()
			if state != null:
				state.reveal_seconds = INFORMANT_SECONDS
			return _r("ok", "O informante abriu o jogo: criminosos por perto ficam marcados por %d s." % int(INFORMANT_SECONDS))
		"briefing":
			var lines := "Briefing: %d preso(s) a entregar na delegacia; $%d no banco." % [profile.prisoners, profile.bank]
			var today: int = clock.day() if clock != null else 0
			if state != null and (state.tip as Dictionary).is_empty() and profile.last_briefing_day != today:
				var tip := _new_tip(world)
				if not tip.is_empty():
					profile.last_briefing_day = today
					state.tip = tip
					lines += " Missão: %s." % tip_text(tip)
			elif state != null and not (state.tip as Dictionary).is_empty():
				lines += " Missão em aberto: %s." % tip_text(state.tip)
			return _r("ok", lines)
		"paint":
			if not profile.spend_money(cost(id)):
				return _no_money()
			var paints: Array = CarSprites.AGENT_PAINTS
			profile.car_paint = paints[(paints.find(profile.car_paint) + 1) % paints.size()]
			return _r("ok", "Carros da agência pintados: %s." % CarSprites.paint_name(profile.car_paint))
		"movie":
			if not profile.spend_money(cost(id)):
				return _no_money()
			if clock != null:
				clock.advance_hours(MOVIE_HOURS)
			profile.xp_boost = MOVIE_XP_BOOST_SECONDS
			return _r("ok", "Que filme! +25%% de XP por %d min. São %s." % [int(MOVIE_XP_BOOST_SECONDS / 60.0), _time(clock)])
		"train":
			var today: int = clock.day() if clock != null else 0
			if profile.last_train_day == today:
				return _r("already", "Você já treinou hoje. Volte amanhã.")
			if not profile.spend_money(cost(id)):
				return _no_money()
			profile.last_train_day = today
			if actor.has_method("gain_xp"):
				actor.gain_xp(DEFS[id].xp)
			else:
				profile.add_xp(DEFS[id].xp)
			return _r("ok", "Treino concluído: XP ganho.")
	return _r("unknown", "")


## "Briga de bar no Bar Saideira".
static func tip_text(tip: Dictionary) -> String:
	return "%s: %s" % [tip.get("crime_name", "crime"), tip.get("place", "")]


static func _new_tip(world: Dictionary) -> Dictionary:
	var provider: Variant = world.get("tip_provider")
	if provider is Callable and (provider as Callable).is_valid():
		return (provider as Callable).call()
	return {}


static func _time(clock: Object) -> String:
	return clock.text() if clock != null else "--:--"


static func _no_money() -> Dictionary:
	return _r("no_money", "Dinheiro insuficiente.")


static func _r(result: String, message: String) -> Dictionary:
	return {"result": result, "message": message}
