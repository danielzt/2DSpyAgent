extends RefCounted
## Identidade (card de personalidade) de um NPC: nome, idade, área de trabalho,
## traços, humor e respostas às perguntas do jogador. Determinística por seed.

const NameGenerator := preload("res://scripts/world/name_generator.gd")

const FIRST_NAMES := ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabriela", "Hugo", "Iara", "João",
	"Karina", "Lucas", "Marina", "Nelson", "Olívia", "Paulo", "Quitéria", "Rafael", "Sônia", "Tiago"]
const LAST_NAMES := ["Silva", "Souza", "Oliveira", "Santos", "Pereira", "Lima", "Costa", "Ribeiro", "Almeida", "Barbosa",
	"Cardoso", "Dias", "Fernandes", "Gomes", "Martins", "Nunes", "Rocha", "Teixeira", "Vieira", "Moraes"]
const JOBS := ["padaria", "transporte", "educação", "restaurante", "saúde", "contabilidade",
	"floricultura", "construção", "livraria", "comércio", "tecnologia", "limpeza urbana"]
const TRAITS := ["tagarela", "nervoso", "gentil", "desconfiado", "bem-humorado", "distraído", "orgulhoso", "tímido"]
const MOODS := ["tranquilo", "apressado", "animado", "cansado", "preocupado"]

const QUESTIONS := [
	{"id": "greet", "text": "Como vai?"},
	{"id": "job", "text": "O que você faz da vida?"},
	{"id": "suspicious", "text": "Viu algo suspeito por aqui?"},
	{"id": "about", "text": "Fale um pouco sobre você."},
]

const MOOD_GREETINGS := {
	"tranquilo": "Tudo tranquilo, e com você?",
	"apressado": "Mais ou menos, estou com pressa.",
	"animado": "Ótimo! Dia lindo para andar pela cidade.",
	"cansado": "Cansado, mas vivendo.",
	"preocupado": "Preocupado com umas coisas, mas vou levando.",
}

const TRAIT_SUFFIX := {
	"tagarela": " Aliás, você sabia que o tempo muda demais por aqui?",
	"nervoso": " ...desculpe, eu fico assim quando alguém me aborda.",
	"gentil": " Obrigado por perguntar!",
	"desconfiado": " Por que quer saber?",
	"bem-humorado": " Pelo menos o café ainda é barato!",
	"distraído": " Desculpe, o que você disse mesmo?",
	"orgulhoso": " Sou muito respeitado no bairro, sabia?",
	"tímido": " ...desculpe, não sou bom de conversa.",
}

const INNOCENT_TIPS := [
	"Não notei nada de estranho hoje.",
	"Só a movimentação de sempre por aqui.",
	"Vi uns rapazes discutindo na esquina, mas nada demais.",
]


## Gera a identidade: {seed, kind, name, age, job, traits:Array, mood, years}.
## `context` (opcional, de Population.context_for) liga o NPC ao mundo: acrescenta
## work_id, work_name, role, home_id, home_name e district, e a profissão passa a ser `role`.
static func generate(p_seed: int, kind := "innocent", context := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var first: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
	var last: String = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
	var trait_a := rng.randi_range(0, TRAITS.size() - 1)
	var trait_b := (trait_a + rng.randi_range(1, TRAITS.size() - 1)) % TRAITS.size()
	var identity := {
		"seed": p_seed,
		"kind": kind,
		"name": "%s %s" % [first, last],
		"age": rng.randi_range(18, 70),
		"job": JOBS[rng.randi_range(0, JOBS.size() - 1)],
		"traits": [TRAITS[trait_a], TRAITS[trait_b]],
		"mood": MOODS[rng.randi_range(0, MOODS.size() - 1)],
		"years": rng.randi_range(1, 30),
	}
	if context.has("role"):
		for key in context:
			identity[key] = context[key]
		identity.job = context.role
	return identity


## True se a identidade está ligada a prédios do mundo.
static func has_place(identity: Dictionary) -> bool:
	return identity.get("work_name", "") != "" and identity.get("home_name", "") != ""


static func answer(identity: Dictionary, question_id: String) -> String:
	var suffix: String = TRAIT_SUFFIX[identity.traits[0]]
	match question_id:
		"greet":
			return (MOOD_GREETINGS[identity.mood] as String) + suffix
		"job":
			if has_place(identity):
				return "Sou %s %s há %d anos." % [identity.role, NameGenerator.at_place(identity.work_name), identity.years] + suffix
			return "Trabalho com %s há %d anos." % [identity.job, identity.years] + suffix
		"suspicious":
			if identity.kind == "criminal":
				return "Não vi nada. E eu tenho pressa."
			return INNOCENT_TIPS[identity.seed % INNOCENT_TIPS.size()] + suffix
		"about":
			if has_place(identity):
				var where: String = NameGenerator.at_place(identity.home_name)
				if identity.get("district", "") != "":
					where += ", %s" % NameGenerator.at_place(identity.district)
				return "Me chamo %s, tenho %d anos e moro %s, há %d anos." % [identity.name, identity.age, where, identity.years] + suffix
			return "Me chamo %s, tenho %d anos e moro por aqui há %d anos." % [identity.name, identity.age, identity.years] + suffix
	return "Hum? Não entendi."


static func summary(identity: Dictionary) -> String:
	if has_place(identity):
		return "%d anos • %s: %s • humor %s" % [identity.age, identity.job, identity.work_name, identity.mood]
	return "%d anos • trabalha com %s • humor %s" % [identity.age, identity.job, identity.mood]


## `reveal`: quantos traços o jogador enxerga (depende da Inteligência); o resto aparece como "???".
static func traits_text(identity: Dictionary, reveal := 2) -> String:
	var shown: Array = (identity.traits as Array).slice(0, clampi(reveal, 0, 2))
	var hidden := 2 - shown.size()
	for i in hidden:
		shown.append("???")
	var text := "Personalidade: %s" % ", ".join(shown)
	if hidden > 0:
		text += "  (Inteligência revela mais)"
	return text
