extends RefCounted
## Nomes próprios gerados por seed (lógica pura): prédios, ruas e avenidas.
## O humor fica nos nomes; nenhum copia nome de jogo, filme ou marca.
## Só usa letras que a fonte pixel desenha (sem "&", "ª" ou "º").

const LINES := 13   # linhas de rua por eixo (0..CELLS)
const AVENUE_LINE := 6

## Nomes completos por tipo de prédio com serviço (sorteados sem repetir).
const BUILDING_NAMES := {
	"hq": ["Lavanderia Mancha Zero", "Lavanderia Sigilo", "Lavanderia Roupa Limpa"],
	"police": ["Delegacia Central", "Delegacia do Flagrante", "Delegacia Boletim Feito"],
	"hospital": ["Hospital Santa Paciência", "Hospital São Curativo", "Hospital Boa Sorte"],
	"bank": ["Banco Confia em Mim", "Banco Cofre Aberto", "Banco Juro Alto", "Banco Tio Rico", "Banco Sem Fundos"],
	"hotel": ["Hotel Álibi", "Hotel Sono Leve", "Hotel Nome Falso", "Hotel Quarto 13", "Hotel Mala Pronta"],
	"restaurant": ["Cantina Bela Máfia", "Restaurante Prato Frio", "Bistrô Vingança", "Churrascaria Ponto Cego",
		"Cantina Molho Secreto", "Restaurante Conta Alta", "Bistrô Garfo Torto"],
	"diner": ["Lanchonete X-Tudo", "Lanchonete Pão na Chapa", "Lanchonete Coxinha Suspeita",
		"Lanchonete Pastel de Vento", "Lanchonete Café Requentado", "Lanchonete Misto Quente", "Lanchonete Troco em Bala"],
	"bar": ["Bar Sem Testemunhas", "Bar Saideira", "Bar do Informante", "Bar Copo Sujo", "Bar Última Dose",
		"Bar Fiado Amanhã", "Bar Balcão Torto"],
	"club": ["Boate Infravermelho", "Boate Curto-Circuito", "Boate Estrobo", "Boate Laser Rosa"],
	"agent_store": ["Loja do Agente Discreto", "Loja do Agente Precavido", "Loja do Agente Anônimo"],
	"armory": ["Armaria Pólvora Seca", "Armaria Mira Torta", "Armaria Bala Perdida"],
	"pharmacy": ["Farmácia Placebo", "Farmácia Santo Remédio", "Farmácia Dor de Cabeça", "Farmácia Efeito Colateral"],
	"market": ["Mercado Troco Certo", "Mercado Fila Única", "Mercado Carrinho Torto", "Mercado Sacola Furada",
		"Mercado Oferta Relâmpago", "Mercado Preço de Ontem"],
	"workshop": ["Oficina Pneu Furado", "Oficina Parafuso Solto", "Oficina Motor Fundido", "Oficina Lata Velha"],
	"gas_station": ["Posto Tanque Cheio", "Posto Última Gota", "Posto Gasolina Batizada", "Posto Calibrador"],
	"cinema": ["Cine Suspense", "Cine Sessão Dupla", "Cine Reviravolta"],
	"gym": ["Academia Braço Longo da Lei", "Academia Supino Secreto", "Academia Perna Fina", "Academia Suor Frio"],
	"newspaper": ["Gazeta do Boato", "Jornal Furo Certo", "Diário do Disfarce"],
	"farm_store": ["Armazém Rural do Compadre", "Armazém Rural Porteira", "Armazém Rural Sela Nova"],
}

## Tipos de preenchimento: prefixo + palavra (com numeral romano quando a lista acaba).
const FILL_PREFIX := {"office": "Escritório", "apartment": "Edifício", "warehouse": "Armazém", "farm": "Fazenda"}
const FILL_WORDS := {
	"office": ["Papelada", "Carimbo", "Ata e Pauta", "Clipe de Ouro", "Protocolo", "Hora Extra", "Planilha",
		"Reunião", "Fax Urgente", "Crachá", "Grampo", "Relatório", "Memorando", "Cafezinho", "Arquivo Morto",
		"Assinatura", "Ponto Batido", "Firma Reconhecida", "Rubrica", "Expediente", "Pasta Azul", "Sala 2"],
	"apartment": ["Codinome", "Álibi", "Sigilo", "Disfarce", "Senha", "Contato", "Dossiê", "Microfilme",
		"Escuta", "Pseudônimo", "Mirante", "Aurora", "Horizonte", "Solar", "Bela Vista", "Primavera",
		"Esplendor", "Monte Alto", "Dois Irmãos", "Sete Chaves", "Olho Vivo", "Porta Giratória", "Elevador Lento",
		"Síndico Bravo", "Vizinho de Cima", "Interfone Mudo", "Varanda", "Cobertura", "Portaria", "Luz Acesa"],
	"warehouse": ["Caixote", "Doca 3", "Paleta", "Carga Seca", "Empilhadeira", "Galpão Frio", "Contêiner",
		"Sem Nota", "Lona Preta", "Balança", "Estoque Zero", "Portão 9", "Guindaste", "Frete Pago"],
	"farm": ["Boi Dormindo", "Porteira Aberta", "Galo Cedo", "Milho Verde", "Cerca Viva", "Vaca Amarela",
		"Trator Novo", "Chuva Boa", "Sol a Pino", "Poeira Fina"],
}
const ROMAN := ["", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X"]

## Primeira palavra de nomes femininos ("na Cantina", "na Vila"); o resto usa "no".
const FEMININE := ["Cantina", "Boate", "Oficina", "Academia", "Delegacia", "Lavanderia", "Farmácia", "Armaria",
	"Loja", "Lanchonete", "Gazeta", "Fazenda", "Casa", "Churrascaria", "Vila", "Praça", "Doca", "Esplanada",
	"Rua", "Travessa", "Avenida", "Av.", "Estrada", "Cidade", "Esquina"]

const AVENUES := ["Av. Codinome", "Av. Martini Batido", "Av. Identidade Secreta", "Av. Contraespionagem"]
const STREETS := ["Rua do Disfarce", "Rua da Escuta", "Travessa do Microfilme", "Rua Sem Saída", "Rua do Álibi",
	"Rua Agente Duplo", "Beco do Informante", "Rua da Senha Errada", "Rua do Bigode Falso", "Travessa da Maleta",
	"Rua do Grampo", "Rua da Tinta Invisível", "Beco do Recado", "Rua do Sobretudo", "Rua da Vigia",
	"Travessa do Jornal Furado", "Rua do Ponto de Encontro", "Rua da Mensagem Cifrada", "Beco da Sombra",
	"Rua do Chapéu", "Rua da Contrassenha", "Travessa do Binóculo", "Rua do Passaporte", "Rua da Pista Fria",
	"Beco do Cochicho", "Rua do Relatório", "Rua da Câmera Oculta", "Travessa do Telefone Vermelho"]
const COUNTRY_ROAD := "Estrada do Contrabando"


## Nome de um prédio do tipo dado. `used` (nome -> true) evita repetição e é atualizado.
static func building_name(type: String, rng: RandomNumberGenerator, used: Dictionary) -> String:
	var result := ""
	if type == "house":
		for attempt in 50:
			result = "Casa %d" % rng.randi_range(1, 999)
			if not used.has(result):
				break
	elif BUILDING_NAMES.has(type):
		result = _unused(BUILDING_NAMES[type], rng, used)
	elif FILL_WORDS.has(type):
		var options: Array = []
		for word in FILL_WORDS[type]:
			options.append("%s %s" % [FILL_PREFIX[type], word])
		result = _unused(options, rng, used)
	else:
		result = "Prédio %d" % (used.size() + 1)
	used[result] = true
	return result


## Sorteia um nome ainda não usado; se todos já saíram, acrescenta um numeral romano.
static func _unused(options: Array, rng: RandomNumberGenerator, used: Dictionary) -> String:
	var start := rng.randi_range(0, options.size() - 1)
	for round_index in ROMAN.size():
		for i in options.size():
			var candidate: String = options[(start + i) % options.size()] + ROMAN[round_index]
			if not used.has(candidate):
				return candidate
	return "%s %d" % [options[start], used.size() + 1]


## "no" ou "na" conforme a primeira palavra do nome.
static func preposition(place_name: String) -> String:
	var first := place_name.get_slice(" ", 0)
	return "na" if FEMININE.has(first) else "no"


## "no Hotel Álibi", "na Cantina Bela Máfia".
static func at_place(place_name: String) -> String:
	return "%s %s" % [preposition(place_name), place_name]


## Nomes das 26 linhas de rua: {"v": 13 nomes (linhas verticais), "h": 13 nomes (horizontais)}.
## As linhas AVENUE_LINE são as avenidas.
static func street_names(p_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 613 + 29
	var avenues := _shuffled(AVENUES, rng)
	var streets := _shuffled(STREETS, rng)
	var result := {"v": [], "h": []}
	var next := 0
	for axis in ["v", "h"]:
		for line in LINES:
			if line == AVENUE_LINE:
				result[axis].append(avenues[0 if axis == "v" else 1])
			else:
				result[axis].append(streets[next])
				next += 1
	return result


static func _shuffled(source: Array, rng: RandomNumberGenerator) -> Array:
	var items := source.duplicate()
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: String = items[i]
		items[i] = items[j]
		items[j] = swap
	return items
