extends "res://tests/base_test.gd"
## Regras de arte da Fase 5: nenhum retângulo placeholder e nenhuma cor fora da paleta nos
## scripts e nas cenas. O teste varre os arquivos; se alguém reintroduzir `ColorRect` ou
## uma cor solta, ele falha apontando o arquivo e a linha.

## Arquivos que podem ter cores próprias: a paleta e a tinta do ambiente (que não é pixel art).
const COLOR_ALLOWED := ["scripts/art/palette.gd", "scripts/world/day_cycle.gd"]
## Nós de desenho de formas soltas, proibidos nas cenas e nos scripts.
const FORBIDDEN_NODES := ["ColorRect", "Polygon2D", "Line2D"]
## Cor solta: Color("..."), Color8(...), Color(0x...) ou Color(r, g, b...) com três números.
const LITERAL_COLOR := r'Color\("|Color8\(|Color\(0x|Color\(\s*[0-9.]+\s*,\s*[0-9.]+\s*,\s*[0-9.]+'


func _files(dir: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(extension):
			result.append("%s/%s" % [dir, name])
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(_files("%s/%s" % [dir, sub], extension))
	return result


func _code_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped.begins_with("##"):
			continue
		lines.append(line)
	return lines


func _relative(path: String) -> String:
	return path.trim_prefix("res://")


func test_no_placeholder_shape_nodes_in_scripts() -> void:
	for path in _files("res://scripts", ".gd"):
		var lines := _code_lines(path)
		for i in lines.size():
			for node in FORBIDDEN_NODES:
				assert_false(lines[i].contains(node + ".new") or lines[i].contains('"%s"' % node),
						"%s:%d usa %s" % [_relative(path), i + 1, node])


func test_no_placeholder_shape_nodes_in_scenes() -> void:
	var scenes := _files("res://scenes", ".tscn")
	assert_gt(scenes.size(), 3.0)
	for path in scenes:
		var text := FileAccess.get_file_as_string(path)
		for node in FORBIDDEN_NODES:
			assert_false(text.contains('type="%s"' % node), "%s tem um nó %s" % [_relative(path), node])


func test_scripts_use_only_palette_colors() -> void:
	var literal := RegEx.new()
	literal.compile(LITERAL_COLOR)
	var checked := 0
	for path in _files("res://scripts", ".gd"):
		if COLOR_ALLOWED.has(_relative(path)):
			continue
		checked += 1
		var lines := _code_lines(path)
		for i in lines.size():
			var line: String = lines[i]
			if literal.search(line) == null:
				continue
			# a cor totalmente transparente e o branco com transparência (luz aditiva) são neutros
			if line.contains("Color(0, 0, 0, 0)") or line.contains("Color(1, 1, 1,"):
				continue
			assert_true(false, "%s:%d tem cor fora da paleta: %s" % [_relative(path), i + 1, line.strip_edges()])
	assert_gt(checked, 50.0, "o teste precisa varrer os scripts")


func test_the_scanner_catches_a_violation() -> void:
	# garante que a regra funciona: um trecho com cor solta deve ser pego
	var literal := RegEx.new()
	literal.compile(LITERAL_COLOR)
	assert_true(literal.search('var c := Color("e8b339")') != null)
	assert_true(literal.search("var c := Color(0.2, 0.4, 0.6)") != null)
	assert_true(literal.search('var c := Palette.get_color("red")') == null)
