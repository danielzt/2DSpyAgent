extends Control
## Tela de título (Fase 5): a cidade à noite ao fundo, o nome do jogo e o menu
## (Novo jogo, Controles, Sair). É a cena inicial do projeto.

const TitleArt := preload("res://scripts/art/title_art.gd")
const PixelMenu := preload("res://scripts/ui/pixel_menu.gd")
const ControlsText := preload("res://scripts/ui/controls_text.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")

const GAME_NAME := "2DGTA"
const TAGLINE := "Um agente. Uma cidade. Zero discrição."
const VERSION_TEXT := "Protótipo"
const NEW_GAME := 0
const CONTROLS := 1
const QUIT := 2
const BLINK_SECONDS := 0.6

var controls_open := false

var _menu: Control
var _scene: ImageTexture
var _blink := true
var _blink_timer := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scene = SpriteFactory.custom("title/scene", func() -> RefCounted: return TitleArt.canvas())
	_menu = PixelMenu.new()
	add_child(_menu)
	_menu.set_items(menu_items())
	_menu.chosen.connect(_on_chosen)
	resized.connect(_place_menu)
	_place_menu()


## Itens do menu ("Sair" não existe no navegador).
static func menu_items() -> Array[String]:
	var items: Array[String] = ["Novo jogo", "Controles"]
	if not OS.has_feature("web"):
		items.append("Sair")
	return items


func menu() -> Control:
	return _menu


func _place_menu() -> void:
	if _menu != null:
		_menu.position = Vector2((size.x - _menu.size.x) / 2.0, size.y * 0.58).round()


func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= BLINK_SECONDS:
		_blink_timer = 0.0
		_blink = not _blink
		queue_redraw()
	if controls_open:
		for n in PixelMenu.PLAYERS:
			if Input.is_action_just_pressed("p%d_interact" % n) or Input.is_action_just_pressed("ui_cancel"):
				_set_controls(false)


func _unhandled_input(event: InputEvent) -> void:
	if controls_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		_set_controls(false)
		get_viewport().set_input_as_handled()


func _on_chosen(index: int) -> void:
	match index:
		NEW_GAME:
			GameState.start_game()
		CONTROLS:
			_set_controls(true)
		QUIT:
			get_tree().quit()


func _set_controls(open: bool) -> void:
	controls_open = open
	_menu.active = not open
	_menu.visible = not open
	queue_redraw()


func _text(content: String, color_name: String, outline: String, text_scale: float, center: Vector2) -> void:
	var texture := SpriteFactory.text(content, color_name, outline, 1)
	var size_px := Vector2(texture.get_size()) * text_scale
	draw_texture_rect(texture, Rect2((center - size_px / 2.0).round(), size_px), false)


func _draw() -> void:
	# a cena cobre a tela inteira, sem distorcer (corta o excesso)
	var k := maxf(size.x / TitleArt.WIDTH, size.y / TitleArt.HEIGHT)
	var scene_size := Vector2(TitleArt.WIDTH, TitleArt.HEIGHT) * k
	draw_texture_rect(_scene, Rect2((size - scene_size) / 2.0, scene_size), false)
	var ink := Palette.get_color("ink")
	if controls_open:
		_draw_controls(ink)
		return
	var title_scale := floorf(clampf(size.x / 160.0, 4.0, 10.0))
	var title_y := size.y * 0.20
	var tagline_y := title_y + title_scale * 9.0 + 44.0
	# placas escuras atrás dos textos: a cidade ao fundo é cheia de janelas acesas
	_plate(Rect2(size.x / 2.0 - 400.0, title_y - title_scale * 5.0 - 14.0, 800.0, tagline_y - title_y + title_scale * 5.0 + 36.0))
	_plate(Rect2(_menu.position - Vector2(24.0, 12.0), _menu.size + Vector2(40.0, 24.0)))
	_text(GAME_NAME, "neon_cyan", "navy", title_scale, Vector2(size.x / 2.0, title_y))
	_text("AGENTE SECRETO", "amber", "ink", 4.0, Vector2(size.x / 2.0, title_y + title_scale * 9.0))
	_text(TAGLINE, "cream", "ink", 2.0, Vector2(size.x / 2.0, tagline_y))
	if _blink:
		_text("W S e E para escolher", "light", "ink", 2.0, Vector2(size.x / 2.0, size.y - 60.0))
	_text(VERSION_TEXT, "gray", "ink", 2.0, Vector2(size.x - 80.0, size.y - 24.0))


func _plate(rect: Rect2) -> void:
	var ink := Palette.get_color("ink")
	draw_rect(rect, Color(ink.r, ink.g, ink.b, 0.78))
	draw_rect(rect, Palette.get_color("slate"), false, 2.0)


func _draw_controls(ink: Color) -> void:
	var panel := Rect2(size.x * 0.1, size.y * 0.12, size.x * 0.8, size.y * 0.76)
	draw_rect(panel, Color(ink.r, ink.g, ink.b, 0.92))
	draw_rect(panel, Palette.get_color("neon_cyan"), false, 4.0)
	_text("CONTROLES", "amber", "ink", 4.0, Vector2(size.x / 2.0, panel.position.y + 40.0))
	for column in 2:
		var player_index := column + 1
		var x := panel.position.x + 40.0 + column * panel.size.x / 2.0
		var y := panel.position.y + 92.0
		_text("Jogador %d" % player_index, "neon_cyan", "ink", 3.0, Vector2(x + 90.0, y))
		y += 34.0
		for pair in ControlsText.lines(player_index):
			var label := SpriteFactory.text(pair[0], "light", "ink", 0)
			draw_texture_rect(label, Rect2(Vector2(x, y).round(), Vector2(label.get_size()) * 2.0), false)
			var keys := SpriteFactory.text(pair[1], "neon_cyan", "ink", 2)
			var keys_size := Vector2(keys.get_size()) * 2.0
			draw_texture_rect(keys, Rect2(Vector2(x + panel.size.x / 2.0 - 100.0 - keys_size.x, y + 14.0).round(), keys_size), false)
			y += 36.0
	_text("E ou Esc para voltar", "gray", "ink", 2.0, Vector2(size.x / 2.0, panel.end.y - 28.0))
