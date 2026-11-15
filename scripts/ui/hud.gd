extends CanvasLayer
## HUD de um jogador, no estilo retrô (fonte pixel e placas com borda):
## região, nível e lugar (canto superior esquerdo), relógio (topo, ao centro), pontos e
## dinheiro (superior direito), instrução de interação (inferior esquerdo), mãos
## (inferior, ao centro) e vida com barra (inferior direito).
## O lugar (bairro e rua) e o relógio ficam ocultos até os sistemas existirem.

const PixelLabel := preload("res://scripts/ui/pixel_label.gd")

const MARGIN := 16
const LINE := 38.0

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


func _ready() -> void:
	layer = 10
	_region = _make_label(Control.PRESET_TOP_LEFT, "white", "light")
	_level = _make_label(Control.PRESET_TOP_LEFT, "amber", "amber", Vector2(0.0, LINE))
	_place = _make_label(Control.PRESET_TOP_LEFT, "ice", "sky", Vector2(0.0, LINE * 2.0))
	_score = _make_label(Control.PRESET_TOP_RIGHT, "white", "light")
	_money = _make_label(Control.PRESET_TOP_RIGHT, "neon_green", "green", Vector2(0.0, LINE))
	_clock = _make_label(Control.PRESET_CENTER_TOP, "cream", "amber")
	_toast = _make_label(Control.PRESET_CENTER_TOP, "amber", "orange", Vector2(0.0, LINE + 12.0))
	_toast.align = 1
	_toast.visible = false
	_hands = _make_label(Control.PRESET_CENTER_BOTTOM, "light", "slate")
	_health = _make_label(Control.PRESET_BOTTOM_RIGHT, "white", "red")
	_health.bar_ratio = 1.0
	_prompt = _make_label(Control.PRESET_BOTTOM_LEFT, "neon_cyan", "teal")
	_prompt.visible = false
	Score.changed.connect(set_score)
	set_score(Score.points)


func _process(delta: float) -> void:
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


## Bairro e rua (vazio esconde). Preenchido a partir da Fase 2.
func set_place(text: String) -> void:
	_place.text = text


func place_text() -> String:
	return _place.text


## Hora do mundo (vazio esconde). Preenchido a partir da Fase 4.
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
