extends RefCounted
## Tabela única dos tipos de prédio e a atribuição de tipo a cada prédio da cidade.
## Por tipo: nome, bairros onde aparece, quantidade mínima/máxima, tamanho mínimo, aparência
## (toldo, vitrine, letreiro), funcionários, horário de funcionamento, serviço e loja.
## Lógica pura e determinística. Os interiores e os serviços entram na Fase 3; o horário
## passa a valer na Fase 4 (por ora é só dado).

const NameGenerator := preload("res://scripts/world/name_generator.gd")

## Altura mínima (px) para um prédio receber um tipo com tamanho mínimo.
const MIN_DEPTH := 160.0

## Ordem da tabela: é a ordem em que os tipos com mínimo escolhem seus prédios.
const ORDER := ["hq", "police", "hospital", "bank", "hotel", "restaurant", "diner", "bar", "club",
	"agent_store", "armory", "pharmacy", "market", "workshop", "gas_station", "cinema", "gym", "newspaper",
	"office", "apartment", "house", "warehouse", "farm", "farm_store"]

## `fill`: peso no preenchimento do que sobra (0 = tipo com cota). `front`: vitrine no térreo.
## `hours`: [abre, fecha] em horas; [0, 24] é 24 h; fecha menor que abre vira a meia-noite.
const DEFS := {
	"hq": {"name": "QG (lavanderia)", "short": "Lavanderia", "districts": ["center"], "min": 1, "max": 1,
		"min_size": 160, "front": true, "awning": "teal", "sign_fg": "neon_cyan", "sign_bg": "navy",
		"staff": ["atendente de lavanderia", "agente", "chefe"], "hours": [0, 24], "service": "Briefing e baú de equipamento"},
	"police": {"name": "Delegacia", "short": "Delegacia", "districts": ["civic"], "min": 1, "max": 2,
		"min_size": 280, "sign_fg": "white", "sign_bg": "blue",
		"staff": ["policial", "detetive", "atendente", "delegado", "perito"], "hours": [0, 24], "service": "Entregar criminoso atordoado"},
	"hospital": {"name": "Hospital", "short": "Hospital", "districts": ["civic"], "min": 1, "max": 1,
		"min_size": 280, "sign_fg": "red", "sign_bg": "white",
		"staff": ["médica", "enfermeiro", "recepcionista", "farmacêutico", "técnico de raio-X", "auxiliar de enfermagem"], "hours": [0, 24], "service": "Cura total paga"},
	"bank": {"name": "Banco", "short": "Banco", "districts": ["center", "upscale"], "min": 2, "max": 3,
		"min_size": 200, "sign_fg": "amber", "sign_bg": "green_dark",
		"staff": ["caixa", "gerente", "segurança"], "hours": [9, 17], "service": "Guardar e sacar dinheiro"},
	"hotel": {"name": "Hotel", "short": "Hotel", "districts": ["center", "nightlife", "upscale"], "min": 2, "max": 4,
		"min_size": 240, "awning": "purple", "sign_fg": "magenta", "sign_bg": "ink",
		"staff": ["recepcionista", "concierge", "camareira"], "hours": [0, 24], "service": "Dormir"},
	"restaurant": {"name": "Restaurante", "short": "Restaurante", "districts": ["center", "upscale", "nightlife"],
		"min": 4, "max": 6, "min_size": 160, "front": true, "awning": "orange", "sign_fg": "orange", "sign_bg": "brown_dark",
		"staff": ["chef", "maître", "ajudante de cozinha", "garçom"], "hours": [11, 23], "service": "Refeição"},
	"diner": {"name": "Lanchonete", "short": "Lanches", "districts": ["center", "residential", "industrial"],
		"min": 4, "max": 6, "min_size": 160, "max_floors": 2, "front": true, "awning": "red", "sign_fg": "white", "sign_bg": "red",
		"staff": ["atendente", "balconista"], "hours": [6, 22], "service": "Lanche"},
	"bar": {"name": "Bar", "short": "Bar", "districts": ["nightlife", "center", "industrial"], "min": 4, "max": 6,
		"min_size": 160, "front": true, "awning": "green", "sign_fg": "neon_green", "sign_bg": "ink",
		"staff": ["bartender", "atendente"], "hours": [17, 3], "service": "Rumores"},
	"club": {"name": "Boate", "short": "Boate", "districts": ["nightlife"], "min": 2, "max": 3,
		"min_size": 240, "awning": "purple", "sign_fg": "magenta", "sign_bg": "navy",
		"staff": ["DJ", "bartender", "segurança"], "hours": [21, 5], "service": "Informante"},
	"agent_store": {"name": "Loja do Agente", "short": "Loja do Agente", "districts": ["center", "civic"], "min": 2, "max": 2,
		"min_size": 160, "max_floors": 2, "front": true, "awning": "teal", "sign_fg": "neon_cyan", "sign_bg": "navy",
		"wall": "wall/blue", "roof": "roof/slab", "shop": "agent_store",
		"staff": ["balconista"], "hours": [8, 20], "service": "Loja"},
	"armory": {"name": "Armaria", "short": "Armaria", "districts": ["industrial", "center"], "min": 2, "max": 2,
		"min_size": 160, "max_floors": 2, "front": true, "awning": "red", "sign_fg": "white", "sign_bg": "wine",
		"wall": "wall/brick", "roof": "roof/tar", "shop": "armory",
		"staff": ["balconista"], "hours": [8, 20], "service": "Loja"},
	"pharmacy": {"name": "Farmácia", "short": "Farmácia", "districts": ["residential", "center", "civic"], "min": 3, "max": 3,
		"min_size": 160, "max_floors": 2, "front": true, "awning": "green", "sign_fg": "neon_green", "sign_bg": "green_dark",
		"wall": "wall/white", "roof": "roof/slab_light", "shop": "pharmacy",
		"staff": ["balconista"], "hours": [7, 23], "service": "Loja"},
	"market": {"name": "Mercado", "short": "Mercado", "districts": ["residential", "center"], "min": 3, "max": 5,
		"min_size": 200, "max_floors": 2, "front": true, "awning": "yellow", "sign_fg": "amber", "sign_bg": "green_dark", "shop": "market",
		"staff": ["caixa", "estoquista"], "hours": [7, 22], "service": "Loja de comida para levar"},
	"workshop": {"name": "Oficina", "short": "Oficina", "districts": ["industrial", "residential"], "min": 2, "max": 3,
		"min_size": 200, "max_floors": 2, "sign_fg": "orange", "sign_bg": "ink",
		"staff": ["auxiliar de mecânica", "lanterneiro"], "hours": [7, 19], "service": "Pintar e consertar o carro"},
	"gas_station": {"name": "Posto", "short": "Posto", "districts": ["industrial", "residential", "center"], "min": 2, "max": 3,
		"min_size": 200, "max_floors": 1, "front": true, "awning": "red", "sign_fg": "white", "sign_bg": "red", "shop": "gas_station",
		"staff": ["frentista"], "hours": [0, 24], "service": "Conveniência 24 h"},
	"cinema": {"name": "Cinema", "short": "Cine", "districts": ["center", "nightlife"], "min": 1, "max": 2,
		"min_size": 240, "awning": "red", "sign_fg": "amber", "sign_bg": "wine",
		"staff": ["lanterninha", "projecionista", "bilheteiro", "atendente"], "hours": [13, 24], "service": "Sessão"},
	"gym": {"name": "Academia", "short": "Academia", "districts": ["residential", "upscale", "center"], "min": 2, "max": 3,
		"min_size": 160, "front": true, "awning": "blue", "sign_fg": "white", "sign_bg": "blue",
		"staff": ["personal trainer", "recepcionista"], "hours": [6, 22], "service": "Treino"},
	"newspaper": {"name": "Redação do jornal", "short": "Jornal", "districts": ["center", "civic"], "min": 1, "max": 1,
		"min_size": 200, "sign_fg": "white", "sign_bg": "ink",
		"staff": ["repórter", "colunista", "fotojornalista", "editor"], "hours": [6, 24], "service": "Pistas e manchetes"},
	"office": {"name": "Escritório", "short": "Escritório", "districts": ["center", "civic"], "fill": 5,
		"min_size": 132, "sign_fg": "light", "sign_bg": "slate",
		"staff": ["analista", "auxiliar de escritório", "gerente", "recepcionista"], "hours": [8, 18], "service": "Local de trabalho"},
	"apartment": {"name": "Prédio residencial", "short": "Edifício",
		"districts": ["residential", "center", "nightlife", "upscale"], "fill": 3,
		"min_size": 132, "sign_fg": "cream", "sign_bg": "brown_dark", "home": true, "hours": [0, 24], "service": "Moradia"},
	"house": {"name": "Casa", "short": "", "districts": ["residential", "upscale"], "fill": 6,
		"min_size": 132, "max_floors": 2, "no_sign": true, "home": true, "hours": [0, 24], "service": "Moradia"},
	# A casa do agente: uma das casas do bairro residencial, escolhida por `designate_home`
	# (fora do ORDER: não entra no sorteio comum).
	"agent_home": {"name": "Casa do agente", "short": "", "districts": ["residential"],
		"min_size": 0, "max_floors": 2, "no_sign": true, "home": true, "hours": [0, 24],
		"service": "Dormir, baú de equipamento"},
	"warehouse": {"name": "Armazém", "short": "Armazém", "districts": ["industrial"], "fill": 5,
		"min_size": 200, "max_floors": 2, "sign_fg": "white", "sign_bg": "slate",
		"staff": ["estoquista", "conferente"], "hours": [0, 24], "service": "Ponto de crimes"},
	"farm": {"name": "Casa de fazenda", "short": "", "districts": ["country"], "min_size": 0, "max_floors": 1,
		"no_sign": true, "home": true, "wall": "wall/wood", "roof": "roof/tile",
		"staff": ["ajudante de fazenda", "tratorista"], "hours": [0, 24], "service": "Moradia"},
	"farm_store": {"name": "Armazém Rural", "short": "Armazém Rural", "districts": ["country"], "min_size": 0, "max_floors": 1,
		"front": true, "awning": "yellow", "sign_fg": "cream", "sign_bg": "brown_dark",
		"wall": "wall/wood", "roof": "roof/tile", "shop": "farm_store",
		"staff": ["balconista"], "hours": [6, 20], "service": "Loja"},
}

## Tipos que a campanha exige em qualquer seed (roteiro-jogo.md, item 1.1).
const STORY_TYPES := ["hq", "bank", "club", "police", "workshop", "bar", "newspaper"]


static func exists(type: String) -> bool:
	return DEFS.has(type)


static func def(type: String) -> Dictionary:
	return DEFS.get(type, {})


static func type_name(type: String) -> String:
	return DEFS[type].name if DEFS.has(type) else ""


## Loja do tipo ("" se o tipo não vende nada ainda).
static func shop_of(type: String) -> String:
	return def(type).get("shop", "")


static func staff_of(type: String) -> Array:
	return def(type).get("staff", [])


static func is_home(type: String) -> bool:
	return def(type).get("home", false)


static func min_count(type: String) -> int:
	return def(type).get("min", 0)


static func max_count(type: String) -> int:
	return def(type).get("max", 0)


## True se o tipo está aberto na hora dada (0 a 24, com fração).
static func is_open(type: String, hour: float) -> bool:
	var hours: Array = def(type).get("hours", [0, 24])
	var open: float = hours[0]
	var close: float = hours[1]
	hour = fposmod(hour, 24.0)
	if close - open >= 24.0:
		return true
	if open <= close:
		return hour >= open and hour < close
	return hour >= open or hour < close


## True se o tipo nunca fecha.
static func always_open(type: String) -> bool:
	var hours: Array = def(type).get("hours", [0, 24])
	return hours[1] - hours[0] >= 24


static func opening_hour(type: String) -> int:
	return def(type).get("hours", [0, 24])[0]


## Aviso da porta de um prédio fechado.
static func closed_text(type: String) -> String:
	return "Fechado — abre às %02d:00" % opening_hour(type)


static func fits(type: String, rect: Rect2) -> bool:
	var min_size: float = def(type).get("min_size", 0)
	return rect.size.x >= min_size and rect.size.y >= minf(min_size, MIN_DEPTH)


## Define `type`, `shop` e `name` de cada prédio (que já traz `district` e `floors`).
## 1) cada tipo com mínimo recebe seus prédios, na ordem da tabela; 2) sorteiam-se os
## extras até o máximo; 3) o resto é preenchido pelos pesos do bairro.
static func assign(buildings: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var free: Array[int] = []
	for i in buildings.size():
		var forced: String = buildings[i].get("forced", "")
		if forced != "":
			_set_type(buildings[i], forced)  # casas do bairro residencial já nascem com tipo
		else:
			free.append(i)
	for type in ORDER:
		for n in min_count(type):
			_give(buildings, free, type, rng)
	for type in ORDER:
		var extras := max_count(type) - min_count(type)
		if extras > 0:
			for n in rng.randi_range(0, extras):
				_give(buildings, free, type, rng, true)
	for index in free:
		_set_type(buildings[index], _fill_type(buildings[index], rng))
	var used := {}
	for b in buildings:
		b.name = NameGenerator.building_name(b.type, rng, used)
	designate_home(buildings)


## Escolhe a casa do agente: a casa do bairro residencial mais perto do QG (se não houver
## casa, qualquer prédio residencial; sem bairro residencial, o prédio mais perto do QG).
## Vira o tipo "agent_home". Retorna o id, ou -1.
static func designate_home(buildings: Array[Dictionary]) -> int:
	var hq := Vector2.ZERO
	for b in buildings:
		if b.type == "hq":
			hq = (b.rect as Rect2).get_center()
	var pools: Array = [["house"], ["house", "apartment"], []]
	for pool in pools:
		var best := -1
		var best_d := INF
		for i in buildings.size():
			var b: Dictionary = buildings[i]
			var ok: bool = pool.has(b.type) if not pool.is_empty() else (b.type != "hq" and b.type != "police" and b.type != "hospital")
			if not ok or (b.district != "residential" and not pool.is_empty()):
				continue
			var d := (b.rect as Rect2).get_center().distance_to(hq)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			_set_type(buildings[best], "agent_home")
			buildings[best].name = "Casa do agente"
			return buildings[best].id
	return -1

## Dá a um prédio livre o tipo pedido. Preferência: cabe e está em bairro permitido; depois
## cabe em qualquer bairro; depois o maior livre (o mínimo sempre é cumprido).
## Com `strict`, só aceita a primeira opção (usado nos extras).
static func _give(buildings: Array[Dictionary], free: Array[int], type: String, rng: RandomNumberGenerator, strict := false) -> void:
	if free.is_empty():
		return
	var districts: Array = DEFS[type].districts
	var best: Array[int] = []
	var fitting: Array[int] = []
	for index in free:
		var b: Dictionary = buildings[index]
		if not fits(type, b.rect):
			continue
		fitting.append(index)
		if districts.has(b.get("district", "")):
			best.append(index)
	var pick := -1
	if not best.is_empty():
		pick = best[rng.randi_range(0, best.size() - 1)]
	elif strict:
		return
	elif not fitting.is_empty():
		pick = fitting[rng.randi_range(0, fitting.size() - 1)]
	else:
		var largest := -1.0
		for index in free:
			var area: float = (buildings[index].rect as Rect2).get_area()
			if area > largest:
				largest = area
				pick = index
	free.erase(pick)
	_set_type(buildings[pick], type)


static func _fill_type(b: Dictionary, rng: RandomNumberGenerator) -> String:
	var district: String = b.get("district", "")
	var options: Array[String] = []
	var loose: Array[String] = []
	for type in ORDER:
		var d: Dictionary = DEFS[type]
		if d.get("fill", 0) <= 0 or not (d.districts as Array).has(district):
			continue
		loose.append(type)
		if fits(type, b.rect):
			options.append(type)
	if options.is_empty():
		options = loose
	if options.is_empty():
		return "apartment"
	var total := 0
	for type in options:
		total += DEFS[type].fill
	var roll := rng.randi_range(1, total)
	for type in options:
		roll -= DEFS[type].fill
		if roll <= 0:
			return type
	return options[options.size() - 1]


static func _set_type(b: Dictionary, type: String) -> void:
	b.type = type
	b.shop = shop_of(type)
	var d: Dictionary = DEFS[type]
	if d.has("max_floors") and b.has("floors"):
		b.floors = mini(b.floors, d.max_floors)
	# Alguns tipos têm parede e telhado próprios (as lojas mantêm a cara de sempre).
	if d.has("wall"):
		b.wall = d.wall
	if d.has("roof"):
		b.roof_kind = d.roof
