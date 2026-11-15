extends "res://tests/base_test.gd"
## Fonte pixel própria (letreiros e HUD).

const Palette := preload("res://scripts/art/palette.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const ItemDefs := preload("res://scripts/items/item_defs.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")


func test_every_glyph_has_seven_rows_of_five_bits() -> void:
	for letter in PixelFont.GLYPHS:
		var rows := (PixelFont.GLYPHS[letter] as String).split(" ")
		assert_eq(rows.size(), PixelFont.GLYPH_H, "letra %s" % letter)
		for row in rows:
			assert_eq(row.length(), PixelFont.GLYPH_W, "letra %s" % letter)
			assert_eq(row.replace("0", "").replace("1", ""), "", "letra %s só tem 0 e 1" % letter)


func test_alphabet_digits_and_portuguese_accents_exist() -> void:
	for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ÁÀÂÃÉÊÍÓÔÕÚÇ .,:!?-/$%()•×—":
		assert_true(PixelFont.has_glyph(letter), "falta a letra %s" % letter)
	for letter in PixelFont.ACCENTED:
		assert_true(PixelFont.GLYPHS.has(PixelFont.ACCENTED[letter][0]))


## Todo texto que o jogo já mostra precisa ter letra na fonte.
func test_game_texts_are_covered() -> void:
	var texts: Array[String] = ["Cidade", "Campo", "Interior", "Pontos: -100", "Vida: 10/10",
		"Nível 20 • XP 950/1000", "$ 200", "Esq: —    Dir: Escudo balístico ×2",
		"Pressione E para entrar na Farmácia", "Crime em andamento: Tráfico de drogas — a 65 m a sudeste",
		"Mochila cheia", "+$40"]
	for shop_id in ShopDefs.SHOPS:
		texts.append(ShopDefs.shop_name(shop_id))
	for item_id in ItemDefs.ITEMS:
		texts.append(ItemDefs.get_def(item_id).get("name", ""))
	for first in NpcIdentity.FIRST_NAMES:
		texts.append(first)
	for last in NpcIdentity.LAST_NAMES:
		texts.append(last)
	for text in texts:
		for letter in PixelFont.normalize(text):
			assert_true(PixelFont.has_glyph(letter) or letter == "\n", "'%s' em '%s'" % [letter, text])


func test_measure_single_and_multi_line() -> void:
	assert_eq(PixelFont.measure("AB"), Vector2i(2 * PixelFont.ADVANCE - 1, PixelFont.CELL_H))
	var two := PixelFont.measure("AB\nABCD")
	assert_eq(two.x, 4 * PixelFont.ADVANCE - 1)
	assert_eq(two.y, PixelFont.CELL_H * 2 + PixelFont.LINE_GAP)


func test_text_is_drawn_in_upper_case() -> void:
	var lower: RefCounted = PixelFont.render("loja", Palette.get_color("white"))
	var upper: RefCounted = PixelFont.render("LOJA", Palette.get_color("white"))
	assert_eq(lower.image.get_data(), upper.image.get_data())
	assert_gt(upper.opaque_count(), 20.0)


func test_accent_and_cedilla_add_texels_outside_the_letter() -> void:
	var plain: RefCounted = PixelFont.render("A", Palette.get_color("white"), Color(0, 0, 0, 0), 0)
	var acute: RefCounted = PixelFont.render("Á", Palette.get_color("white"), Color(0, 0, 0, 0), 0)
	assert_gt(acute.opaque_count(), plain.opaque_count())
	var top_rows := 0
	for y in PixelFont.ACCENT_ROWS:
		for x in acute.width:
			if not acute.is_empty_at(x, y):
				top_rows += 1
	assert_gt(top_rows, 0.0, "acento fica acima da letra")
	var cedilla: RefCounted = PixelFont.render("Ç", Palette.get_color("white"), Color(0, 0, 0, 0), 0)
	assert_false(cedilla.is_empty_at(2, PixelFont.CELL_H - 1), "cedilha fica abaixo da letra")


func test_render_with_outline_adds_ink_around() -> void:
	var plain: RefCounted = PixelFont.render("I", Palette.get_color("white"))
	var outlined: RefCounted = PixelFont.render("I", Palette.get_color("white"), Palette.get_color("ink"))
	assert_gt(outlined.opaque_count(), plain.opaque_count())
	assert_true(outlined.only_palette_colors())


func test_unknown_letter_draws_a_box_instead_of_failing() -> void:
	assert_false(PixelFont.has_glyph("@"))
	var c: RefCounted = PixelFont.render("@", Palette.get_color("white"))
	assert_gt(c.opaque_count(), 10.0)


func test_centered_lines_are_aligned_inside_the_widest() -> void:
	var c: RefCounted = PixelCanvas.new(40, 30)
	PixelFont.draw_text(c, "I\nAAAA", 0, 0, Palette.get_color("white"), 1)
	var first_line_left := 99
	for x in c.width:
		for y in range(PixelFont.ACCENT_ROWS, PixelFont.CELL_H):
			if not c.is_empty_at(x, y):
				first_line_left = mini(first_line_left, x)
	assert_gt(first_line_left, 5.0, "a linha curta fica centrada")
