extends "res://tests/base_test.gd"
## Paleta fixa e tela de pixel art (base da fábrica de arte).

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")


# --- paleta ---

func test_palette_has_32_unique_colors() -> void:
	assert_eq(Palette.COLORS.size(), 32)
	var seen := {}
	for n in Palette.COLORS:
		seen[(Palette.COLORS[n] as Color).to_html(false)] = true
	assert_eq(seen.size(), 32, "cores repetidas na paleta")


func test_legend_letters_point_to_palette_colors() -> void:
	var letters := {}
	for letter in Palette.LEGEND:
		assert_eq((letter as String).length(), 1)
		assert_true(Palette.has_color(Palette.LEGEND[letter]), "letra %s" % letter)
		letters[letter] = true
	assert_eq(letters.size(), Palette.LEGEND.size())
	assert_false(Palette.LEGEND.has("."), "ponto é transparente")
	for digit in ["1", "2", "3", "4", "5", "6"]:
		assert_false(Palette.LEGEND.has(digit), "dígitos são cores trocáveis")


func test_ramps_and_tones_use_three_palette_colors() -> void:
	for group in [Palette.RAMPS, Palette.TONES]:
		for key in group:
			assert_eq((group[key] as Array).size(), 3, key)
			for n in group[key]:
				assert_true(Palette.has_color(n), "%s usa %s" % [key, n])
	assert_eq(Palette.tone("red")[1], Palette.get_color("red"))
	assert_eq(Palette.ramp("asphalt")[1], Palette.get_color("asphalt"))


func test_contains_recognizes_only_palette_colors() -> void:
	assert_true(Palette.contains(Palette.get_color("teal")))
	assert_true(Palette.contains(Palette.cast_shadow()), "sombra é tinta translúcida")
	assert_false(Palette.contains(Color(0.5, 0.123, 0.9)))


func test_legend_overrides_replace_swappable_letters() -> void:
	var legend := Palette.legend({"1": "red", "2": Color(0, 0, 0, 0)})
	assert_eq(legend["1"], Palette.get_color("red"))
	assert_eq(legend["2"], Color(0, 0, 0, 0))
	assert_eq(legend["k"], Palette.get_color("ink"))


func test_cast_shadow_is_translucent_ink() -> void:
	var s := Palette.cast_shadow()
	assert_almost_eq(s.a, Palette.SHADOW_ALPHA)
	assert_almost_eq(s.r, Palette.get_color("ink").r)


# --- tela ---

func test_stamp_draws_letters_and_skips_dots() -> void:
	var c: RefCounted = PixelCanvas.new(3, 2)
	c.stamp(["k.r", ".w."], Palette.legend())
	assert_eq(c.get_px(0, 0), Palette.get_color("ink"))
	assert_eq(c.get_px(2, 0), Palette.get_color("red"))
	assert_eq(c.get_px(1, 1), Palette.get_color("white"))
	assert_true(c.is_empty_at(1, 0))
	assert_eq(c.opaque_count(), 3)


func test_drawing_outside_the_canvas_is_ignored() -> void:
	var c: RefCounted = PixelCanvas.new(4, 4)
	c.px(-1, 0, Color.WHITE)
	c.px(9, 9, Color.WHITE)
	c.rect(-3, -3, 5, 5, Palette.get_color("red"))
	assert_eq(c.opaque_count(), 4, "só a parte de dentro do retângulo")
	assert_true(c.is_empty_at(-5, -5))


func test_outline_surrounds_opaque_texels() -> void:
	var c: RefCounted = PixelCanvas.new(5, 5)
	c.px(2, 2, Palette.get_color("red"))
	c.outline(Palette.get_color("ink"))
	for p in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		assert_eq(c.get_px(p.x, p.y), Palette.get_color("ink"))
	assert_eq(c.get_px(2, 2), Palette.get_color("red"), "o miolo fica igual")
	assert_true(c.is_empty_at(1, 1), "contorno em cruz, sem diagonais")
	assert_eq(c.opaque_count(), 5)


func test_flipped_h_mirrors_without_changing_the_original() -> void:
	var c: RefCounted = PixelCanvas.new(3, 1)
	c.px(0, 0, Palette.get_color("red"))
	var f: RefCounted = c.flipped_h()
	assert_eq(f.get_px(2, 0), Palette.get_color("red"))
	assert_true(f.is_empty_at(0, 0))
	assert_eq(c.get_px(0, 0), Palette.get_color("red"))


func test_rotated_keeps_the_shape_size() -> void:
	var c: RefCounted = PixelCanvas.new(10, 4)
	c.fill(Palette.get_color("blue"))
	var same: RefCounted = c.rotated(0.0, 12)
	assert_eq(same.opaque_count(), 40)
	var quarter: RefCounted = c.rotated(PI / 2.0, 12)
	assert_eq(quarter.opaque_count(), 40, "90 graus não perde texels")
	assert_false(quarter.is_empty_at(6, 1), "ficou em pé")
	assert_true(quarter.is_empty_at(1, 6))
	var diagonal: RefCounted = c.rotated(PI / 4.0, 12)
	assert_gt(diagonal.opaque_count(), 30.0)


func test_tile_fill_repeats_the_tile() -> void:
	var tile: RefCounted = PixelCanvas.new(2, 2)
	tile.px(0, 0, Palette.get_color("red"))
	tile.px(1, 1, Palette.get_color("blue"))
	var c: RefCounted = PixelCanvas.new(5, 3)
	c.tile_fill(tile, 0, 0, 5, 3)
	assert_eq(c.get_px(0, 0), Palette.get_color("red"))
	assert_eq(c.get_px(2, 0), Palette.get_color("red"))
	assert_eq(c.get_px(4, 2), Palette.get_color("red"))
	assert_eq(c.get_px(3, 1), Palette.get_color("blue"))


func test_silhouette_and_scaled() -> void:
	var c: RefCounted = PixelCanvas.new(2, 2)
	c.px(0, 0, Palette.get_color("red"))
	c.px(1, 1, Palette.get_color("blue"))
	var s: RefCounted = c.silhouette(Palette.get_color("ink"))
	assert_eq(s.get_px(1, 1), Palette.get_color("ink"))
	assert_eq(s.opaque_count(), 2)
	var big: RefCounted = c.scaled(3)
	assert_eq(Vector2i(big.width, big.height), Vector2i(6, 6))
	assert_eq(big.get_px(2, 2), Palette.get_color("red"))
	assert_eq(big.opaque_count(), 18)


func test_speckle_is_deterministic_and_only_on_opaque_texels() -> void:
	var a: RefCounted = PixelCanvas.new(16, 16)
	a.rect(0, 0, 8, 16, Palette.get_color("green"))
	var b: RefCounted = a.duplicate_canvas()
	a.speckle(Palette.get_color("lime"), 0.3, 5)
	b.speckle(Palette.get_color("lime"), 0.3, 5)
	assert_eq(a.image.get_data(), b.image.get_data())
	assert_eq(a.opaque_count(), 128, "não pinta o que era transparente")
	assert_eq(a.used_colors().size(), 2)


func test_only_palette_colors_detects_foreign_colors() -> void:
	var c: RefCounted = PixelCanvas.new(2, 1)
	c.px(0, 0, Palette.get_color("pink"))
	assert_true(c.only_palette_colors())
	c.px(1, 0, Color(0.11, 0.99, 0.33))
	assert_false(c.only_palette_colors())


func test_ellipse_is_round() -> void:
	var c: RefCounted = PixelCanvas.new(10, 10)
	c.ellipse(0, 0, 10, 10, Palette.get_color("blue"))
	assert_true(c.is_empty_at(0, 0), "cantos ficam vazios")
	assert_false(c.is_empty_at(5, 5))
	assert_false(c.is_empty_at(0, 5))
