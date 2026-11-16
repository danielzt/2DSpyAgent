extends RefCounted
## Sprites de personagens (12x16 texels) escritos como texto e recoloridos por legenda.
## Direções: "down", "up", "right", "left" (espelho de "right").
## Quadros: 0 = parado, 1 e 2 = passos.
##
## Letras trocáveis: 1 roupa, 2 sombra/detalhe da roupa, 3 calça, 4 cabelo, 5 boné/gorro,
## f pele. As demais vêm da legenda padrão da paleta.

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")

const WIDTH := 12
const HEIGHT := 16
## Tela final: sprite + anel (jogador) + sombra no chão.
const CANVAS := Vector2i(16, 20)
const ORIGIN := Vector2i(2, 1)
## Ponto da tela que coincide com o centro da colisão do personagem.
const PIVOT := Vector2i(8, 11)
const DIRECTIONS := ["down", "up", "right", "left"]
const FRAMES := 3
const POSES := ["stand", "sit", "lie", "work"]

const FRONT := [
	"....kkkk....",
	"...k4444k...",
	"..k444444k..",
	"..k4ffff4k..",
	"..kfkffkfk..",
	"..kffffffk..",
	"...kffffk...",
	"..k111111k..",
	".k11111111k.",
	"kf11111111fk",
	"kf12111121fk",
	".k11111111k.",
	"..k333333k..",
	"..k33kk33k..",
	"..k33kk33k..",
	"..kkk..kkk..",
]
const BACK := [
	"....kkkk....",
	"...k4444k...",
	"..k444444k..",
	"..k444444k..",
	"..k444444k..",
	"..k444444k..",
	"...k4ff4k...",
	"..k111111k..",
	".k11111111k.",
	"kf11111111fk",
	"kf11211211fk",
	".k11111111k.",
	"..k333333k..",
	"..k33kk33k..",
	"..k33kk33k..",
	"..kkk..kkk..",
]
const SIDE := [
	"....kkkk....",
	"...k4444k...",
	"..k44444fk..",
	"..k444fffk..",
	"..k44ffkfk..",
	"..k4fffffk..",
	"...kffffk...",
	"...k1111k...",
	"..k111111k..",
	"..k11f111k..",
	"..k11f211k..",
	"..k111111k..",
	"...k3333k...",
	"...k3333k...",
	"...k33k3k...",
	"...kkkkkk...",
]
## Pernas (últimas 4 fileiras) no passo, de frente e de costas.
const STEP_LEGS := [
	"..k333333k..",
	"..k33kk33k..",
	"..k33k.kkk..",
	"..kkk.......",
]
## Pernas no passo, de lado (abertas).
const SIDE_STEP_LEGS := [
	"...k3333k...",
	"..k33kk33k..",
	".k33k..k33k.",
	".kkk....kkk.",
]

const SKINS := ["skin_light", "skin_dark"]
const HAIRS := ["brown_dark", "amber", "shadow", "orange", "gray"]
const HAIR_STYLES := ["short", "long", "cap", "bald"]
const SHIRTS := ["red", "blue", "green", "yellow", "white", "teal", "purple", "orange", "pink", "brown"]
const PANTS := ["navy", "brown", "slate", "shadow"]
const CAPS := ["red", "blue", "white", "green_dark"]


## Aparência do agente (jogador N): terno escuro, gravata e óculos escuros.
static func agent_look(player_index: int = 1) -> Dictionary:
	return {
		"kind": "agent", "skin": "skin_light", "hair": "brown_dark", "hair_style": "short",
		"shirt": "navy", "shirt2": "ink", "pants": "navy", "cap": "",
		"ring": "blue" if player_index == 1 else "orange", "hat": "", "detail": "", "detail_color": "",
	}


## Aparência de um civil, determinística pela seed.
static func civilian_look(p_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 7919 + 17
	var tone: String = SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	return {
		"kind": "innocent",
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"hair": HAIRS[rng.randi_range(0, HAIRS.size() - 1)],
		"hair_style": HAIR_STYLES[rng.randi_range(0, HAIR_STYLES.size() - 1)],
		"shirt": Palette.TONES[tone][1], "shirt2": Palette.TONES[tone][0],
		"pants": PANTS[rng.randi_range(0, PANTS.size() - 1)],
		"cap": CAPS[rng.randi_range(0, CAPS.size() - 1)],
		"ring": "", "hat": "", "detail": "", "detail_color": "",
	}


## Aparência de um criminoso: gorro, máscara e camisa listrada.
static func criminal_look(p_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 7919 + 31
	return {
		"kind": "criminal",
		"skin": SKINS[rng.randi_range(0, SKINS.size() - 1)],
		"hair": "ink", "hair_style": "cap",
		"shirt": "red", "shirt2": "ink", "pants": "shadow", "cap": "shadow", "ring": "",
		"hat": "", "detail": "", "detail_color": "",
	}


## Aparência de um NPC. Com `building_type`, o uniforme vem do prédio (todo funcionário do hospital
## de branco, da delegacia de azul...); sem, vale o uniforme antigo pelo nome do papel.
static func look_for(kind: String, p_seed: int, role := "", building_type := "", staff := false) -> Dictionary:
	if kind == "criminal":
		return criminal_look(p_seed)
	var base := civilian_look(p_seed)
	if building_type == "":
		return dressed(base, role)
	var overrides := uniform_for(building_type, role, staff)
	for key in overrides:
		base[key] = overrides[key]
	return base


## Uniformes por prédio (Fase 7): `staff` vale para todo funcionário; `roles` acrescenta o do papel.
## Chaves: shirt, shirt2, pants, cap (cor do boné ou do chapéu), hair_style, hat, detail, detail_color.
const BUILDING_UNIFORMS := {
	"hq": {"staff": {"shirt": "ice", "shirt2": "sky", "pants": "navy", "cap": "", "detail": "apron", "detail_color": "sky"},
		"roles": {"agente": {"shirt": "ink", "shirt2": "shadow", "pants": "ink", "detail": "tie", "detail_color": "red"}}},
	"police": {"staff": {"shirt": "blue", "shirt2": "navy", "pants": "navy", "cap": "navy", "hat": "kepi", "detail": "badge", "detail_color": "amber"},
		"roles": {"perito": {"shirt": "white", "shirt2": "light", "pants": "slate", "cap": "", "hat": "", "detail": "coat", "detail_color": "blue"},
			"detetive": {"shirt": "sand", "shirt2": "brown", "pants": "brown", "cap": "", "hat": "", "detail": "coat", "detail_color": "brown"}}},
	"hospital": {"staff": {"shirt": "white", "shirt2": "light", "pants": "white", "cap": ""},
		"roles": {"médica": {"detail": "coat", "detail_color": "teal"}, "farmacêutico": {"detail": "coat", "detail_color": "green"},
			"enfermeiro": {"hat": "nurse_cap", "cap": "white"}, "auxiliar de enfermagem": {"hat": "nurse_cap", "cap": "white"},
			"recepcionista": {"detail": "badge", "detail_color": "teal"}}},
	"bank": {"staff": {"shirt": "white", "shirt2": "light", "pants": "ink", "cap": "", "detail": "tie", "detail_color": "wine"},
		"roles": {"gerente": {"shirt": "slate", "shirt2": "shadow", "pants": "slate", "detail_color": "red"},
			"segurança": {"shirt": "ink", "shirt2": "shadow", "pants": "ink", "cap": "ink", "hat": "kepi", "detail": "badge", "detail_color": "amber"}}},
	"hotel": {"staff": {"shirt": "wine", "shirt2": "ink", "pants": "ink", "cap": "", "detail": "badge", "detail_color": "amber"},
		"roles": {"concierge": {"cap": "wine", "hat": "kepi"},
			"camareira": {"shirt": "ink", "shirt2": "shadow", "pants": "ink", "detail": "apron", "detail_color": "white"}}},
	"restaurant": {"staff": {"shirt": "white", "shirt2": "light", "pants": "ink", "cap": "", "detail": "vest", "detail_color": "ink"},
		"roles": {"chef": {"pants": "slate", "cap": "white", "hat": "chef_hat", "detail": ""},
			"ajudante de cozinha": {"pants": "slate", "cap": "white", "hat": "chef_hat", "detail": "apron", "detail_color": "light"}}},
	"diner": {"staff": {"shirt": "white", "shirt2": "light", "pants": "navy", "hair_style": "cap", "cap": "red", "detail": "apron", "detail_color": "red"}},
	"bar": {"staff": {"shirt": "white", "shirt2": "light", "pants": "ink", "cap": "", "detail": "vest", "detail_color": "ink"}},
	"club": {"staff": {"shirt": "ink", "shirt2": "shadow", "pants": "ink", "cap": ""},
		"roles": {"DJ": {"shirt": "purple", "detail": "badge", "detail_color": "neon_cyan"},
			"segurança": {"detail": "badge", "detail_color": "amber"}}},
	"agent_store": {"staff": {"shirt": "navy", "shirt2": "ink", "pants": "navy", "cap": "", "detail": "tie", "detail_color": "sky"}},
	"armory": {"staff": {"shirt": "cream", "shirt2": "sand", "pants": "brown", "hair_style": "cap", "cap": "green_dark", "detail": "vest", "detail_color": "green_dark"}},
	"pharmacy": {"staff": {"shirt": "white", "shirt2": "light", "pants": "white", "cap": "", "detail": "coat", "detail_color": "green"}},
	"market": {"staff": {"shirt": "white", "shirt2": "light", "pants": "navy", "cap": "", "detail": "apron", "detail_color": "green"}},
	"gas_station": {"staff": {"shirt": "red", "shirt2": "wine", "pants": "red", "hair_style": "cap", "cap": "amber"}},
	"farm_store": {"staff": {"shirt": "red", "shirt2": "wine", "pants": "navy", "cap": "sand", "hat": "straw"}},
	"workshop": {"staff": {"shirt": "blue", "shirt2": "navy", "pants": "blue", "hair_style": "cap", "cap": "blue"}},
	"cinema": {"staff": {"shirt": "white", "shirt2": "light", "pants": "ink", "cap": "", "detail": "vest", "detail_color": "wine"},
		"roles": {"lanterninha": {"shirt": "wine", "shirt2": "ink", "cap": "wine", "hat": "kepi", "detail": ""}}},
	"gym": {"staff": {"shirt": "orange", "shirt2": "wine", "pants": "ink", "cap": ""},
		"roles": {"personal trainer": {"shirt": "teal", "shirt2": "navy", "pants": "teal", "detail": "reflective", "detail_color": "white"}}},
	"newspaper": {"staff": {"shirt": "light", "shirt2": "gray", "pants": "slate", "cap": "", "detail": "vest", "detail_color": "slate"},
		"roles": {"fotojornalista": {"shirt": "cream", "pants": "brown", "detail_color": "sand"}}},
	"office": {"staff": {"shirt": "light", "shirt2": "gray", "pants": "ink", "cap": "", "detail": "tie", "detail_color": "blue"},
		"roles": {"gerente": {"shirt": "slate", "shirt2": "shadow", "pants": "slate", "detail_color": "red"}}},
	"warehouse": {"staff": {"shirt": "orange", "shirt2": "wine", "pants": "navy", "cap": "amber", "hat": "helmet", "detail": "reflective", "detail_color": "white"}},
	"farm": {"staff": {"shirt": "red", "shirt2": "wine", "pants": "navy", "cap": "sand", "hat": "straw"}},
}
## Roupa de quem não trabalha no prédio mas tem papel próprio.
const VISITOR_UNIFORMS := {
	"paciente": {"shirt": "ice", "shirt2": "sky", "pants": "ice", "cap": "", "hat": ""},
	"preso": {"shirt": "orange", "shirt2": "red", "pants": "orange", "cap": "", "hat": ""},
}


## Trocas de roupa do uniforme de `role` no prédio `building_type` (vazio = roupa comum).
static func uniform_for(building_type: String, role: String, staff: bool) -> Dictionary:
	if not staff:
		return VISITOR_UNIFORMS.get(role, {})
	var entry: Dictionary = BUILDING_UNIFORMS.get(building_type, {})
	if entry.is_empty():
		return {}
	var result: Dictionary = (entry.staff as Dictionary).duplicate()
	var by_role: Dictionary = entry.get("roles", {})
	for key in by_role.get(role, {}):
		result[key] = by_role[role][key]
	return result


## Uniformes por papel (Fase 6): quem trabalha ou está internado se veste conforme o lugar.
## Cada entrada: palavras do papel -> trocas na aparência.
const UNIFORMS := [
	[["médic", "enfermeir", "enfermagem", "plantonista", "farmacêutic", "técnic", "atendente de saúde"],
		{"shirt": "white", "shirt2": "light", "pants": "white", "cap": ""}],
	[["paciente"], {"shirt": "ice", "shirt2": "sky", "pants": "ice", "cap": ""}],
	[["policial", "delegad"], {"shirt": "blue", "shirt2": "navy", "pants": "navy", "cap": "navy"}],
	[["detetive"], {"shirt": "sand", "shirt2": "brown", "pants": "brown", "cap": ""}],
	[["preso"], {"shirt": "orange", "shirt2": "red", "pants": "orange", "cap": ""}],
	[["chef", "cozinh", "ajudante de cozinha"], {"shirt": "white", "shirt2": "light", "pants": "slate", "cap": "white"}],
	[["segurança"], {"shirt": "ink", "shirt2": "shadow", "pants": "ink", "cap": "ink"}],
	[["caixa", "gerente", "maître", "concierge"], {"shirt": "white", "shirt2": "light", "pants": "ink", "cap": ""}],
	[["mecânic"], {"shirt": "blue", "shirt2": "navy", "pants": "blue", "cap": "blue"}],
]


## Troca de roupa de quem tem `role` (vazio ou desconhecido não muda nada).
static func dressed(look: Dictionary, role: String) -> Dictionary:
	var lowered := role.to_lower()
	for entry in UNIFORMS:
		for word in entry[0]:
			if lowered.contains(word):
				var result := look.duplicate()
				for key in entry[1]:
					result[key] = entry[1][key]
				return result
	return look


## Há uniforme para o papel?
static func has_uniform(role: String) -> bool:
	return dressed({"shirt": "x"}, role).get("shirt", "x") != "x"


## Chave de cache: muda só quando a aparência muda.
static func look_key(look: Dictionary) -> String:
	return "%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [look.kind, look.skin, look.hair, look.hair_style,
		look.shirt, look.shirt2, look.pants, look.cap, look.ring, look.get("hat", ""), look.get("detail", ""),
		look.get("detail_color", "")]


## Fileiras (texto) do personagem na direção e no quadro pedidos, sem espelhar.
## Fileiras com a pose: "stand" (em pé/andando), "sit" (sentado), "lie" (deitado de barriga para cima,
## coberto pelo lençol, só de frente) e "work" (braços à frente, quadros 1 e 2 alternam).
static func rows_for(look: Dictionary, direction: String, frame: int, pose := "stand") -> Array:
	if pose == "lie":
		direction = "down"
	var rows := _rows_standing(look, direction, frame if pose == "stand" else 0)
	var side := direction == "right" or direction == "left"
	match pose:
		"sit":
			if direction == "down":
				rows[12] = "..k333333k.."
				rows[13] = ".k33333333k."
				rows[14] = ".kkk....kkk."
				rows[15] = "............"
			elif direction == "up":
				rows[12] = "..k333333k.."
				rows[13] = "..kkkkkkkk.."
				rows[14] = "............"
				rows[15] = "............"
			else:
				rows[12] = "...k333333k."
				rows[13] = "...kkkkk33k."
				rows[14] = "........kkk."
				rows[15] = "............"
		"lie":
			rows[10] = "kwfwwwwwwfwk"
			rows[11] = "kllllllllllk"
			for i in range(12, 15):
				rows[i] = "kwwwwwwwwwwk"
			rows[15] = "kkkkkkkkkkkk"
		"work":
			var second := frame == 2
			if direction == "down":
				if second:
					rows[10] = "kf11111111k."
					rows[11] = ".k1111111fk."
				else:
					rows[10] = ".kf111111fk."
			elif direction == "up":
				rows[9 if not second else 10] = ".k11111111k."
			elif side:
				if second:
					rows[10] = "..k111ffk..."
				else:
					rows[9] = "..k1111ffk.."
	return rows


static func _rows_standing(look: Dictionary, direction: String, frame: int) -> Array:
	var rows: Array = []
	match direction:
		"up":
			rows = BACK.duplicate()
		"right", "left":
			rows = SIDE.duplicate()
		_:
			rows = FRONT.duplicate()
	var side := direction == "right" or direction == "left"
	_apply_head(rows, look, direction)
	_apply_body(rows, look, direction)
	_apply_hat(rows, look.get("hat", ""), direction)
	_apply_detail(rows, look.get("detail", ""), direction)
	if frame > 0:
		var legs: Array = SIDE_STEP_LEGS if side else STEP_LEGS
		if not side or frame == 1:
			for i in 4:
				rows[12 + i] = legs[i]
	return rows


static func _apply_head(rows: Array, look: Dictionary, direction: String) -> void:
	var style: String = look.hair_style
	if direction == "down":
		match style:
			"long":
				rows[4] = "..k4kffk4k.."
				rows[5] = "..k4ffff4k.."
				rows[6] = "...k4ff4k..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555k.."
				rows[3] = "..k555555k.."
			"bald":
				rows[1] = "...kffffk..."
				rows[2] = "..kffffffk.."
				rows[3] = "..kffffffk.."
		if look.kind == "agent":
			rows[4] = "..kkkkkkkk.."   # óculos escuros
		elif look.kind == "criminal":
			rows[3] = "..k555555k.."
			rows[4] = "..kkwkkwkk.."   # máscara
	elif direction == "up":
		match style:
			"long":
				rows[6] = "...k4444k..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555k.."
				rows[3] = "..k555555k.."
			"bald":
				for i in range(1, 6):
					rows[i] = (rows[i] as String).replace("4", "f")
	else:
		match style:
			"long":
				rows[5] = "..k44ffffk.."
				rows[6] = "...k4fffk..."
			"cap":
				rows[1] = "...k5555k..."
				rows[2] = "..k555555kk."
				rows[3] = "..k55ffffk.."
			"bald":
				for i in range(1, 6):
					rows[i] = (rows[i] as String).replace("4", "f")
		if look.kind == "agent":
			rows[4] = "..k44fkkkk.."
		elif look.kind == "criminal":
			rows[3] = "..k555555k.."
			rows[4] = "..k55kkwkk.."


static func _apply_body(rows: Array, look: Dictionary, direction: String) -> void:
	if look.kind == "agent" and direction == "down":
		rows[7] = "..k11ww11k.."     # colarinho
		rows[8] = ".k111rr111k."     # gravata
		rows[9] = "kf111rr111fk"
		rows[10] = "kf11111111fk"
	elif look.kind == "criminal":
		# listras horizontais
		if direction == "right" or direction == "left":
			rows[8] = "..k222222k.."
			rows[10] = "..k22f222k.."
		else:
			rows[8] = ".k22222222k."
			rows[10] = "kf22222222fk"


## Chapéu do uniforme (cor "5" = cap): quepe, touca de enfermagem, touca de chef, capacete, chapéu de palha.
static func _apply_hat(rows: Array, hat: String, direction: String) -> void:
	var side := direction == "right" or direction == "left"
	match hat:
		"kepi":
			rows[0] = "...kkkkkk..."
			rows[1] = "..k555555k.."
			if direction == "down":
				rows[2] = "..k556655k.."
				rows[3] = ".kkkkkkkkkk."
			elif side:
				rows[2] = "..k555555k.."
				rows[3] = "..kkkkkkkkkk"
			else:
				rows[2] = "..k555555k.."
				rows[3] = "..kkkkkkkk.."
		"nurse_cap":
			rows[0] = "............"
			rows[1] = "...kkkkkk..."
			rows[2] = "..k555555k.."
			if direction == "down":
				rows[2] = "..k55rr55k.."
		"chef_hat":
			rows[0] = "..k555555k.."
			rows[1] = ".k55555555k."
			rows[2] = "..k555555k.."
			rows[3] = "..kkkkkkkk.." if not side else "..kkkkkkfk.."
		"helmet":
			rows[0] = "...kkkkkk..."
			rows[1] = "..k555555k.."
			rows[2] = ".k55555555k."
			rows[3] = ".kkkkkkkkkk." if not side else "..kkkkkkkkk."
		"straw":
			rows[0] = "...kkkkkk..."
			rows[1] = "...k5555k..."
			rows[2] = "kk55555555kk"
			rows[3] = ".kkkkkkkkkk." if not side else "..k444fffk.."


## Detalhe do uniforme (cor "6" = detail_color): jaleco, avental, colete, gravata, crachá, faixa refletiva.
static func _apply_detail(rows: Array, detail: String, direction: String) -> void:
	var side := direction == "right" or direction == "left"
	match detail:
		"coat":
			# jaleco: a camisa desce até o joelho; crachá no peito
			if side:
				rows[12] = "...k1111k..."
				rows[13] = "...k1111k..."
			else:
				rows[12] = "..k111111k.."
				rows[13] = "..k11kk11k.."
			if direction == "down":
				rows[8] = ".k11111611k."
		"apron":
			if direction == "down":
				rows[9] = "kf11666611fk"
				rows[10] = "kf12666621fk"
				rows[11] = ".k16666661k."
				rows[12] = "..k666666k.."
			elif side:
				rows[10] = "..k11f666k.."
				rows[11] = "..k111666k.."
			else:
				rows[9] = "kf11611611fk"
		"vest":
			if side:
				for i in range(8, 12):
					rows[i] = (rows[i] as String).substr(0, 3) + "66" + (rows[i] as String).substr(5)
			elif direction == "down":
				for i in range(8, 12):
					rows[i] = (rows[i] as String).substr(0, 2) + "66" + (rows[i] as String).substr(4, 4) + "66" + (rows[i] as String).substr(10)
			else:
				for i in range(8, 12):
					rows[i] = (rows[i] as String).replace("1", "6")
		"tie":
			if direction == "down":
				rows[7] = "..k1wwww1k.."
				rows[8] = ".k11166111k."
				rows[9] = "kf11166111fk"
		"badge":
			if direction == "down":
				rows[8] = ".k11111161k."
			elif side:
				rows[8] = "..k111161k.."
		"reflective":
			if side:
				rows[10] = "..k666666k.."
			else:
				rows[10] = "kf66666666fk"


## Legenda (letra -> cor) da aparência.
static func legend_for(look: Dictionary) -> Dictionary:
	var detail: String = look.get("detail_color", "")
	return Palette.legend({
		"1": look.shirt, "2": look.shirt2, "3": look.pants, "4": look.hair,
		"5": look.cap if look.cap != "" else look.hair, "6": detail if detail != "" else look.shirt2,
		"f": look.skin,
	})


## Só o personagem (12x16), sem sombra nem anel.
static func body(look: Dictionary, direction: String, frame: int, pose := "stand") -> RefCounted:
	var canvas: RefCounted = PixelCanvas.new(WIDTH, HEIGHT)
	canvas.stamp(rows_for(look, direction, frame, pose), legend_for(look))
	if pose == "lie":
		return canvas
	# o passo alternado espelha o quadro 2; nas outras poses só a esquerda espelha
	if direction == "left" or (pose == "stand" and frame == 2 and direction != "right"):
		return canvas.flipped_h()
	return canvas


## Quadro completo (16x20): sombra no chão, anel do jogador e o personagem. Deitado não tem sombra.
static func build(look: Dictionary, direction: String, frame: int, pose := "stand") -> RefCounted:
	var canvas: RefCounted = PixelCanvas.new(CANVAS.x, CANVAS.y)
	if look.ring != "":
		canvas.ellipse(1, 13, 14, 6, Palette.get_color(look.ring))
		canvas.ellipse(3, 14, 10, 4, Color(0, 0, 0, 0))
	if pose != "lie":
		canvas.ellipse(3, 15, 10, 3, Palette.cast_shadow())
	canvas.blit(body(look, direction, frame, pose), ORIGIN.x, ORIGIN.y)
	return canvas


## Direção de sprite mais próxima de um vetor.
static func direction_of(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "down"
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"
