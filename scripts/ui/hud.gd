extends CanvasLayer
## HUD de um jogador, no estilo retrô (fonte pixel e placas com borda):
## região, nível e lugar (canto superior esquerdo), relógio (topo, ao centro), pontos e
## dinheiro (superior direito), instrução de interação (inferior esquerdo), mãos
## (inferior, ao centro) e vida com barra (inferior direito).
## Setas na borda da tela apontam alvos fora de vista (pista de crime, criminosos revelados).

const PixelLabel := preload("res://scripts/ui/pixel_label.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const Palette := preload("res://scripts/art/palette.gd")

const MARGIN := 16
const LINE := 38.0
## Setas de alvo: distância da borda da tela, alvo mais perto que isto não ganha seta.
const ARROW_MARGIN := 90.0
const ARROW_MIN_DISTANCE := 260.0
const ARROW_SCALE := 3.0
const MAX_ARROWS := 4
## Pixels do mundo por metro (distância mostrada no ponto marcado).
const METER := 32.0

var _prompt: Control
var _region: Control
var _score: Control
var _health: Control
var _level: Control
var _hands: Control
var _money: Control
var _toast: Control
var _place: Control
var _clock: Control
var _toast_time := 0.0
var _arrows: Control
var _waypoint: Control
var _waypoint_dir := Vector2.ZERO
var _waypoint_active := false
## Trilha pontilhada da rota até o ponto ativo (pontos do mundo).
var _route_dots: Array[Vector2] = []
var _minimap: Control
var _arrow_dirs: Array[Vector2] = []


func _ready() -> void:
	layer = 10
	_region = _make_label(Control.PRESET_TOP_LEFT, "white", "light")
	_level = _make_label(Control.PRESET_TOP_LEFT, "amber", "amber", Vector2(0.0, LINE))
	_place = _make_label(Control.PRESET_TOP_LEFT, "ice", "sky", Vector2(0.0, LINE * 2.0))
	_score = _make_label(Control.PRESET_TOP_RIGHT, "white", "light")
	_money = _make_label(Control.PRESET_TOP_RIGHT, "neon_green", "green", Vector2(0.0, LINE))
	_clock = _make_label(Control.PRESET_CENTER_TOP, "cream", "amber")
	_toast = _make_label(Control.PRESET_CENTER_TOP, "amber", "orange", Vector2(0.0, LINE * 3.0 + 4.0))
	_toast.align = 1
	_toast.visible = false
	_hands = _make_label(Control.PRESET_CENTER_BOTTOM, "light", "slate")
	_health = _make_label(Control.PRESET_BOTTOM_RIGHT, "white", "red")
	_health.bar_ratio = 1.0
	_prompt = _make_label(Control.PRESET_BOTTOM_LEFT, "neon_cyan", "teal")
	_prompt.visible = false
	_waypoint = _make_label(Control.PRESET_CENTER_TOP, "neon_cyan", "teal", Vector2(0.0, LINE))
	_waypoint.visible = false
	_arrows = Control.new()
	_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)
	_minimap = Minimap.new()
	_minimap.visible = false
	add_child(_minimap)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -Minimap.SIDE - MARGIN
	_minimap.offset_right = -MARGIN
	_minimap.offset_top = MARGIN + LINE * 2.0 + 6.0
	_minimap.offset_bottom = _minimap.offset_top + Minimap.SIDE
	Score.changed.connect(set_score)
	set_score(Score.points)


func _process(delta: float) -> void:
	if not _route_dots.is_empty():
		_arrows.queue_redraw()  # a trilha acompanha a câmera
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false


## Aviso temporário no topo da tela.
func show_toast(text: String, seconds := 5.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = seconds


func toast_text() -> String:
	return _toast.text


func toast_visible() -> bool:
	return _toast.visible


func set_money(amount: int) -> void:
	_money.text = "$ %d" % amount


func money_text() -> String:
	return _money.text


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func prompt_text() -> String:
	return _prompt.text


func set_region(text: String) -> void:
	_region.text = text


func region_text() -> String:
	return _region.text


## Bairro e rua, ou o nome do prédio em um interior (vazio esconde).
func set_place(text: String) -> void:
	_place.text = text


func place_text() -> String:
	return _place.text


## Setas na borda da tela apontando os alvos (posições no mundo), vistos de `from`.
## Alvo já perto do jogador não ganha seta.
func set_targets(from: Vector2, targets: Array) -> void:
	var dirs: Array[Vector2] = []
	for target in targets:
		var to: Vector2 = (target as Vector2) - from
		if to.length() >= ARROW_MIN_DISTANCE and dirs.size() < MAX_ARROWS:
			dirs.append(to.normalized())
	if dirs != _arrow_dirs:
		_arrow_dirs = dirs
		_arrows.queue_redraw()


func target_arrow_count() -> int:
	return _arrow_dirs.size()


## Ponto marcado no mapa: seta ciano na borda da tela e, no alto, o nome e a distância
## (1 m = 32 px). Sem ponto ativo, passe um dicionário vazio. Perto do ponto a seta some.
func set_waypoint(from: Vector2, waypoint: Dictionary) -> void:
	if waypoint.is_empty():
		if _waypoint_active:
			_waypoint_active = false
			_waypoint.visible = false
			_arrows.queue_redraw()
		return
	var to: Vector2 = (waypoint.pos as Vector2) - from
	_waypoint.text = "%s  %d m" % [waypoint.name, roundi(to.length() / METER)]
	_waypoint.visible = true
	var dir := to.normalized() if to.length() >= ARROW_MIN_DISTANCE else Vector2.ZERO
	if dir != _waypoint_dir or not _waypoint_active:
		_waypoint_dir = dir
		_arrows.queue_redraw()
	_waypoint_active = true


## Trilha da rota (pontos do mundo, já espaçados); vazio esconde.
func set_route(dots: Array[Vector2]) -> void:
	if dots.is_empty() and _route_dots.is_empty():
		return
	_route_dots = dots
	_arrows.queue_redraw()


func route_dot_count() -> int:
	return _route_dots.size()


func waypoint_text() -> String:
	return _waypoint.text if _waypoint.visible else ""


func waypoint_arrow_visible() -> bool:
	return _waypoint_active and _waypoint_dir != Vector2.ZERO


func _draw_arrows() -> void:
	var texture := SpriteFactory.prop("target_arrow")
	var half := _arrows.size / 2.0
	if not _route_dots.is_empty():
		var to_screen: Transform2D = get_viewport().get_canvas_transform()
		var view := Rect2(Vector2(-8, -8), _arrows.size + Vector2(16, 16))
		var cyan := Palette.get_color("neon_cyan")
		for dot in _route_dots:
			var screen := to_screen * dot
			if view.has_point(screen):
				_arrows.draw_rect(Rect2((screen - Vector2(3, 3)).round(), Vector2(6, 6)), cyan)
	if _waypoint_active and _waypoint_dir != Vector2.ZERO:
		var wpos := half + Vector2(_waypoint_dir.x * (half.x - ARROW_MARGIN), _waypoint_dir.y * (half.y - ARROW_MARGIN))
		_arrows.draw_set_transform(wpos, _waypoint_dir.angle(), Vector2(ARROW_SCALE + 1.0, ARROW_SCALE + 1.0))
		_arrows.draw_texture(texture, -Vector2(texture.get_size()) / 2.0, Palette.get_color("neon_cyan"))
	for dir in _arrow_dirs:
		var pos := half + Vector2(dir.x * (half.x - ARROW_MARGIN), dir.y * (half.y - ARROW_MARGIN))
		_arrows.draw_set_transform(pos, dir.angle(), Vector2(ARROW_SCALE, ARROW_SCALE))
		_arrows.draw_texture(texture, -Vector2(texture.get_size()) / 2.0)


## Minimapa no canto superior direito (fica escondido dentro de prédios).
func set_minimap(layout, known: Dictionary, center: Vector2, targets: Array, delta := 0.0, profile = null) -> void:
	_minimap.visible = true
	_minimap.set_state(layout, known, center, targets, delta, profile)


func hide_minimap() -> void:
	_minimap.visible = false


func minimap_visible() -> bool:
	return _minimap.visible


func minimap() -> Control:
	return _minimap


## Hora do mundo (vazio esconde).
func set_clock(text: String) -> void:
	_clock.text = text


func clock_text() -> String:
	return _clock.text


func set_score(points: int) -> void:
	_score.text = "Pontos: %d" % points


func set_health(current: float, maximum: float) -> void:
	_health.text = "Vida: %d/%d" % [ceili(current), ceili(maximum)]
	_health.bar_ratio = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func set_level(text: String) -> void:
	_level.text = text


func level_text() -> String:
	return _level.text


func set_hands(text: String) -> void:
	_hands.text = text


func hands_text() -> String:
	return _hands.text


func health_text() -> String:
	return _health.text


func score_text() -> String:
	return _score.text


func _make_label(preset: Control.LayoutPreset, color_name: String, accent_name: String, shift := Vector2.ZERO) -> Control:
	var label: Control = PixelLabel.new()
	label.color_name = color_name
	label.accent_name = accent_name
	add_child(label)
	label.place(preset, MARGIN, shift)
	return label
