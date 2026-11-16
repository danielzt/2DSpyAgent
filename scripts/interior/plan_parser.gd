extends RefCounted
## Leitor de plantas de interior escritas como mapa de texto (lógica pura, sem nós).
##
## Uma planta é um dicionário com três grades do mesmo tamanho (uma letra por célula de 32 px):
## - `floor_grid`: estilo do cômodo (piso + parede), legenda em `floor_legend`;
## - `object_grid`: paredes, portas, saída, móveis e itens de parede, legenda em `object_legend`;
## - `detail_grid`: pessoas, pontos de ronda, zonas de serviço e itens de cima de móvel ("." = nada).
## Símbolos fixos de `object_grid`: "#" parede cheia, "|" parede fina vertical, "-" parede fina
## horizontal, "D" vão de porta interna, "E" saída (última linha), "." piso livre.
## Um retângulo conectado da mesma letra é uma peça só (móvel de várias células).
## Tapetes ficam na grade de piso (legenda com "rug"), para poderem ter móveis em cima.
## A seed do prédio decide o espelhamento, a variante de cores e os itens opcionais (`chance`).

const CELL := 32.0
const THIN := 16.0
const FACE_H := 24.0
const EXIT_DEPTH := 12.0
const SIZES := {"P": Vector2i(40, 23), "M": Vector2i(48, 27), "G": Vector2i(56, 32)}
## Móveis onde alguém pode sentar ou deitar.
const SEATS := ["chair", "office_chair", "stool", "bar_stool", "sofa", "armchair", "bench", "seats", "booth", "bunk"]
const BEDS := ["bed", "double_bed", "hospital_bed", "bunk", "sofa", "car_lift"]
const FIXED := "#|-DE."
const GRIDS := ["floor_grid", "object_grid", "detail_grid"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# --- validação ---

## Erros da planta (vazio = ok). Cada erro diz a grade, a linha, a coluna e a letra.
static func validate(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not SIZES.has(plan.get("size", "")):
		errors.append("tamanho desconhecido: '%s'" % plan.get("size", ""))
		return errors
	var dims: Vector2i = SIZES[plan.size]
	for grid_name in GRIDS:
		var rows: Array = plan.get(grid_name, [])
		if rows.size() != dims.y:
			errors.append("%s: %d linhas (esperado %d)" % [grid_name, rows.size(), dims.y])
		for y in rows.size():
			var length := (rows[y] as String).length()
			if length != dims.x:
				errors.append("%s linha %d: %d colunas (esperado %d)" % [grid_name, y, length, dims.x])
	if not errors.is_empty():
		return errors
	var floor_legend: Dictionary = plan.get("floor_legend", {})
	var object_legend: Dictionary = plan.get("object_legend", {})
	var detail_legend: Dictionary = plan.get("detail_legend", {})
	for key in object_legend:
		if FIXED.contains(key):
			errors.append("object_legend: '%s' é símbolo fixo (parede, porta, saída ou piso)" % key)
	if not errors.is_empty():
		return errors
	for y in dims.y:
		for x in dims.x:
			var f := _at(plan.floor_grid, x, y)
			if not floor_legend.has(f):
				errors.append("floor_grid linha %d coluna %d: letra '%s' sem legenda" % [y, x, f])
			var o := _at(plan.object_grid, x, y)
			if not FIXED.contains(o) and not object_legend.has(o):
				errors.append("object_grid linha %d coluna %d: letra '%s' sem legenda" % [y, x, o])
			var d := _at(plan.detail_grid, x, y)
			if d != "." and not detail_legend.has(d):
				errors.append("detail_grid linha %d coluna %d: letra '%s' sem legenda" % [y, x, d])
			if o == "E" and y != dims.y - 1:
				errors.append("object_grid linha %d coluna %d: saída (E) fora da última linha" % [y, x])
	if not errors.is_empty():
		return errors
	if not (plan.object_grid[dims.y - 1] as String).contains("E"):
		errors.append("object_grid: sem saída (E) na última linha")
	for piece in _pieces(plan.object_grid, object_legend, "item"):
		if not piece.rectangular:
			errors.append("object_grid linha %d coluna %d: peça '%s' não é retangular" % [piece.cell.y, piece.cell.x, piece.letter])
		var entry: Dictionary = object_legend[piece.letter]
		if entry.has("size") and (float(entry.size[0]) * CELL > piece.block.size.x + 0.01 or float(entry.size[1]) * CELL > piece.block.size.y + 0.01):
			errors.append("object_grid linha %d coluna %d: peça '%s' maior que o bloco desenhado" % [piece.cell.y, piece.cell.x, piece.letter])
	var shop_counters := 0
	for piece in _pieces(plan.object_grid, object_legend, "item"):
		if (object_legend[piece.letter] as Dictionary).get("shop_counter", false):
			shop_counters += 1
	if shop_counters > 1:
		errors.append("object_grid: mais de um balcão de loja (shop_counter)")
	for piece in _pieces(plan.floor_grid, floor_legend, "rug"):
		if not piece.rectangular:
			errors.append("floor_grid linha %d coluna %d: tapete '%s' não é retangular" % [piece.cell.y, piece.cell.x, piece.letter])
	for key in ["zone", "on"]:
		for piece in _pieces(plan.detail_grid, detail_legend, key):
			if not piece.rectangular:
				errors.append("detail_grid linha %d coluna %d: peça '%s' não é retangular" % [piece.cell.y, piece.cell.x, piece.letter])
	var kinds := _kind_map(plan)
	for y in dims.y:
		for x in dims.x:
			var d := _at(plan.detail_grid, x, y)
			if d == ".":
				continue
			var entry: Dictionary = detail_legend[d]
			var under: String = kinds.get(Vector2i(x, y), "")
			var where := "detail_grid linha %d coluna %d ('%s')" % [y, x, d]
			if entry.has("npc"):
				var act: String = entry.get("act", "post")
				if act == "sit" and not SEATS.has(under):
					errors.append("%s: sentado fora de um assento" % where)
				elif act == "lie" and not BEDS.has(under):
					errors.append("%s: deitado fora de uma cama" % where)
				elif act != "sit" and act != "lie" and _solid_at(plan, x, y):
					errors.append("%s: pessoa dentro de algo sólido" % where)
				if entry.has("route") and _route_points(plan, entry.route).is_empty():
					errors.append("%s: rota '%s' sem pontos" % [where, entry.route])
			elif entry.has("route") and _solid_at(plan, x, y):
				errors.append("%s: ponto de ronda sobre algo sólido" % where)
	return errors


# --- leitura ---

## Lê a planta para o prédio `building_id`. Supõe uma planta válida (ver `validate`).
static func parse(plan: Dictionary, building_id: int) -> Dictionary:
	var dims: Vector2i = SIZES[plan.size]
	var size := Vector2(dims) * CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = building_id * 7919 + 13
	var mirrored := rng.randf() < 0.5
	var variants: Array = plan.get("variants", [])
	var variant := rng.randi_range(0, variants.size() - 1) if not variants.is_empty() else 0
	var overrides: Dictionary = variants[variant] if not variants.is_empty() else {}
	var floor_over: Dictionary = overrides.get("floors", {})
	var wall_over: Dictionary = overrides.get("walls", {})
	var tone_over: Dictionary = overrides.get("tones", {})
	var floor_legend: Dictionary = plan.floor_legend
	var object_legend: Dictionary = plan.get("object_legend", {})
	var detail_legend: Dictionary = plan.get("detail_legend", {})

	var floor_of := func(letter: String) -> String:
		return floor_over.get(letter, floor_legend[letter].floor)
	var wall_of := func(letter: String) -> String:
		return wall_over.get(letter, floor_legend[letter].get("wall", ""))

	var result := {
		"size": size, "size_class": plan.size, "mirrored": mirrored, "variant": variant,
		"rooms": [], "floor_rects": [], "walls": [], "doors": [], "wall_faces": [], "items": [],
		"npc_slots": [], "zones": [], "exit": Rect2(), "spawn": Vector2.ZERO, "counter": Rect2(),
	}

	# pisos: runs horizontais da mesma letra
	for y in dims.y:
		var x := 0
		while x < dims.x:
			var letter := _at(plan.floor_grid, x, y)
			var x1 := x
			while x1 + 1 < dims.x and _at(plan.floor_grid, x1 + 1, y) == letter:
				x1 += 1
			result.floor_rects.append({"rect": _cells(x, y, x1 - x + 1, 1), "floor": floor_of.call(letter)})
			x = x1 + 1

	# cômodos: componentes conectados da mesma letra de piso, fora das paredes cheias
	var seen := {}
	for y in dims.y:
		for x in dims.x:
			var cell := Vector2i(x, y)
			if seen.has(cell) or _is_full_wall(plan, x, y):
				continue
			var letter := _at(plan.floor_grid, x, y)
			var comp := _flood(dims, cell, func(c: Vector2i) -> bool:
				return _at(plan.floor_grid, c.x, c.y) == letter and not _is_full_wall(plan, c.x, c.y))
			for c in comp.cells:
				seen[c] = true
			var entry: Dictionary = floor_legend[letter]
			result.rooms.append({"name": entry.get("room", ""), "rect": _cells(comp.min.x, comp.min.y,
					comp.max.x - comp.min.x + 1, comp.max.y - comp.min.y + 1), "floor": floor_of.call(letter),
					"wall": wall_of.call(letter)})

	# paredes cheias (runs horizontais), finas, portas e saída
	for y in dims.y:
		var x := 0
		while x < dims.x:
			if _is_full_wall(plan, x, y):
				var x1 := x
				while x1 + 1 < dims.x and _is_full_wall(plan, x1 + 1, y):
					x1 += 1
				result.walls.append(_cells(x, y, x1 - x + 1, 1))
				x = x1 + 1
			elif _at(plan.object_grid, x, y) == "-":
				var x1 := x
				while x1 + 1 < dims.x and _at(plan.object_grid, x1 + 1, y) == "-":
					x1 += 1
				result.walls.append(Rect2(x * CELL, y * CELL + (CELL - THIN) / 2.0, (x1 - x + 1) * CELL, THIN))
				x = x1 + 1
			else:
				var o := _at(plan.object_grid, x, y)
				if o == "D":
					result.doors.append(_cells(x, y, 1, 1))
				elif o == "E" and (x == 0 or _at(plan.object_grid, x - 1, y) != "E"):
					var x1 := x
					while x1 + 1 < dims.x and _at(plan.object_grid, x1 + 1, y) == "E":
						x1 += 1
					result.exit = Rect2(x * CELL, size.y - EXIT_DEPTH, (x1 - x + 1) * CELL, EXIT_DEPTH)
					result.spawn = Vector2(result.exit.get_center().x, size.y - CELL * 1.5)
				x += 1
	for x in dims.x:
		var y := 0
		while y < dims.y:
			if _at(plan.object_grid, x, y) == "|":
				var y1 := y
				while y1 + 1 < dims.y and _at(plan.object_grid, x, y1 + 1) == "|":
					y1 += 1
				result.walls.append(Rect2(x * CELL + (CELL - THIN) / 2.0, y * CELL, THIN, (y1 - y + 1) * CELL))
				y = y1 + 1
			else:
				y += 1

	# faces: parede cheia ou fina horizontal com piso logo abaixo; estilo do cômodo de baixo
	for y in dims.y - 1:
		var run: Dictionary = {}
		for x in dims.x + 1:
			var face: Dictionary = {}
			if x < dims.x:
				var o := _at(plan.object_grid, x, y)
				var below := _at(plan.object_grid, x, y + 1)
				var is_wall := _is_full_wall(plan, x, y) or o == "-"
				if is_wall and not _is_full_wall(plan, x, y + 1) and below != "-" and below != "|":
					var top := (y + 1) * CELL if o != "-" else y * CELL + (CELL + THIN) / 2.0
					face = {"style": wall_of.call(_at(plan.floor_grid, x, y + 1)), "x": x, "y": top}
			if not run.is_empty() and (face.is_empty() or face.style != run.style or face.y != run.y):
				result.wall_faces.append({"rect": Rect2(run.x * CELL, run.y, (run.end - run.x + 1) * CELL, FACE_H), "style": run.style})
				run = {}
			if not face.is_empty():
				if run.is_empty():
					run = face.duplicate()
				run["end"] = x

	# tapetes: marcados na grade de piso (revestimento), ficam embaixo dos móveis
	for piece in _pieces(plan.floor_grid, floor_legend, "rug"):
		var entry: Dictionary = floor_legend[piece.letter]
		result.items.append({"kind": entry.rug, "rect": piece.block, "solid": false, "layer": "floor",
				"tone": tone_over.get(entry.rug, entry.get("tone", ""))})
	# móveis e itens de parede (ordem de leitura); os opcionais consomem a seed nessa ordem
	for piece in _pieces(plan.object_grid, object_legend, "item"):
		var entry: Dictionary = object_legend[piece.letter]
		if not _roll(rng, entry):
			continue
		var rect := _place(piece.block, entry)
		result.items.append({"kind": entry.item, "rect": rect, "solid": entry.get("solid", true),
				"layer": "floor", "tone": tone_over.get(entry.item, entry.get("tone", ""))})
		if entry.get("shop_counter", false):
			result.counter = rect
	for piece in _pieces(plan.object_grid, object_legend, "wall_item"):
		var entry: Dictionary = object_legend[piece.letter]
		if not _roll(rng, entry):
			continue
		var block: Rect2 = piece.block
		var width: float = block.size.x
		if entry.has("size"):
			width = float(entry.size[0]) * CELL
		var rect := Rect2(block.get_center().x - width / 2.0, block.end.y, width, FACE_H)
		result.items.append({"kind": entry.wall_item, "rect": rect, "solid": false, "layer": "wall",
				"tone": tone_over.get(entry.wall_item, entry.get("tone", ""))})

	# camada de detalhe: itens de cima de móvel, zonas, pessoas
	for piece in _pieces(plan.detail_grid, detail_legend, "on"):
		var entry: Dictionary = detail_legend[piece.letter]
		if not _roll(rng, entry):
			continue
		result.items.append({"kind": entry.on, "rect": _place(piece.block, entry), "solid": false, "layer": "on",
				"tone": tone_over.get(entry.on, entry.get("tone", ""))})
	for piece in _pieces(plan.detail_grid, detail_legend, "zone"):
		var entry: Dictionary = detail_legend[piece.letter]
		result.zones.append({"id": entry.zone, "rect": piece.block, "verb": entry.get("verb", "")})
	for y in dims.y:
		for x in dims.x:
			var d := _at(plan.detail_grid, x, y)
			if d == "." or not detail_legend[d].has("npc"):
				continue
			var entry: Dictionary = detail_legend[d]
			if not _roll(rng, entry):
				continue
			var position := _center(x, y)
			var route: Array[Vector2] = []
			if entry.has("route"):
				route.append(position)
				route.append_array(_route_points(plan, entry.route))
			result.npc_slots.append({"role": entry.npc, "position": position, "staff": entry.get("staff", false),
					"act": entry.get("act", "post"), "route": route, "facing": entry.get("facing", "down")})

	if mirrored:
		_mirror(result)
	return result


# --- ajudantes ---

static func _at(rows: Array, x: int, y: int) -> String:
	return (rows[y] as String)[x]


static func _cells(x: int, y: int, w: int, h: int) -> Rect2:
	return Rect2(x * CELL, y * CELL, w * CELL, h * CELL)


static func _center(x: int, y: int) -> Vector2:
	return Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)


## Parede cheia: "#" ou letra de item de parede.
static func _is_full_wall(plan: Dictionary, x: int, y: int) -> bool:
	var o := _at(plan.object_grid, x, y)
	if o == "#":
		return true
	var legend: Dictionary = plan.get("object_legend", {})
	return legend.has(o) and (legend[o] as Dictionary).has("wall_item")


## A célula tem parede ou móvel sólido?
static func _solid_at(plan: Dictionary, x: int, y: int) -> bool:
	var o := _at(plan.object_grid, x, y)
	if o == "#" or o == "|" or o == "-":
		return true
	var legend: Dictionary = plan.get("object_legend", {})
	if not legend.has(o):
		return false
	var entry: Dictionary = legend[o]
	return entry.has("wall_item") or (entry.has("item") and entry.get("solid", true))


## Célula -> tipo do móvel que a ocupa.
static func _kind_map(plan: Dictionary) -> Dictionary:
	var result := {}
	var legend: Dictionary = plan.get("object_legend", {})
	var dims: Vector2i = SIZES[plan.size]
	for y in dims.y:
		for x in dims.x:
			var o := _at(plan.object_grid, x, y)
			if legend.has(o) and (legend[o] as Dictionary).has("item"):
				result[Vector2i(x, y)] = legend[o].item
	return result


## Pontos da rota `letter` (centros das células, em ordem de leitura).
static func _route_points(plan: Dictionary, letter: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var legend: Dictionary = plan.get("detail_legend", {})
	var dims: Vector2i = SIZES[plan.size]
	for y in dims.y:
		for x in dims.x:
			var d := _at(plan.detail_grid, x, y)
			if d != "." and legend.has(d) and not legend[d].has("npc") and legend[d].get("route", "") == letter:
				points.append(_center(x, y))
	return points


## Componente conectado (4 vizinhos) a partir de `start` onde `accept` é verdadeiro.
static func _flood(dims: Vector2i, start: Vector2i, accept: Callable) -> Dictionary:
	var cells: Array[Vector2i] = [start]
	var seen := {start: true}
	var lo := start
	var hi := start
	var i := 0
	while i < cells.size():
		var c := cells[i]
		i += 1
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= dims.x or n.y >= dims.y or seen.has(n):
				continue
			if accept.call(n):
				seen[n] = true
				cells.append(n)
	return {"cells": cells, "min": lo, "max": hi}


## Peças (retângulos conectados da mesma letra) cuja legenda tem `key`, em ordem de leitura.
static func _pieces(rows: Array, legend: Dictionary, key: String) -> Array:
	var result := []
	var dims := Vector2i((rows[0] as String).length(), rows.size())
	var seen := {}
	for y in dims.y:
		for x in dims.x:
			var cell := Vector2i(x, y)
			var letter := _at(rows, x, y)
			if seen.has(cell) or not legend.has(letter) or not (legend[letter] as Dictionary).has(key):
				continue
			var comp := _flood(dims, cell, func(c: Vector2i) -> bool: return _at(rows, c.x, c.y) == letter)
			for c in comp.cells:
				seen[c] = true
			var w: int = comp.max.x - comp.min.x + 1
			var h: int = comp.max.y - comp.min.y + 1
			result.append({"letter": letter, "cell": cell, "block": _cells(comp.min.x, comp.min.y, w, h),
					"rectangular": comp.cells.size() == w * h})
	return result


## Retângulo real da peça dentro do bloco: `size` (em células) e `align`.
static func _place(block: Rect2, entry: Dictionary) -> Rect2:
	var real := block.size
	if entry.has("size"):
		real = Vector2(float(entry.size[0]), float(entry.size[1])) * CELL
	var pos := block.get_center() - real / 2.0
	match entry.get("align", "center"):
		"top":
			pos.y = block.position.y
		"bottom":
			pos.y = block.end.y - real.y
		"left":
			pos.x = block.position.x
		"right":
			pos.x = block.end.x - real.x
	return Rect2(pos, real)


## Sorteio dos opcionais: só consome a seed quando há `chance` menor que 1.
static func _roll(rng: RandomNumberGenerator, entry: Dictionary) -> bool:
	var chance: float = entry.get("chance", 1.0)
	return chance >= 1.0 or rng.randf() < chance


static func _mirror(result: Dictionary) -> void:
	var w: float = result.size.x
	var flip := func(r: Rect2) -> Rect2: return Rect2(w - r.end.x, r.position.y, r.size.x, r.size.y)
	for key in ["rooms", "floor_rects", "wall_faces", "items", "zones"]:
		for entry in result[key]:
			entry.rect = flip.call(entry.rect)
	for key in ["walls", "doors"]:
		var list: Array = result[key]
		for i in list.size():
			list[i] = flip.call(list[i])
	result.exit = flip.call(result.exit)
	if result.counter.size.x > 0.0:
		result.counter = flip.call(result.counter)
	result.spawn = Vector2(w - result.spawn.x, result.spawn.y)
	for slot in result.npc_slots:
		slot.position = Vector2(w - slot.position.x, slot.position.y)
		var route: Array[Vector2] = []
		for p in slot.route:
			route.append(Vector2(w - p.x, p.y))
		slot.route = route
		if slot.facing == "left":
			slot.facing = "right"
		elif slot.facing == "right":
			slot.facing = "left"
