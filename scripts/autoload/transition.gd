extends CanvasLayer
## Transição em íris (Fase 5): a tela fecha em um círculo de pixels em 0,25 s, a cena troca,
## e abre em 0,25 s. Usada ao entrar e sair de prédios e ao ir do título para o jogo.
## O desenho é em faixas de STRIP px (degraus de pixel), com a cor tinta da paleta.

const Palette := preload("res://scripts/art/palette.gd")

const DURATION := 0.25
const STRIP := 8.0
const LAYER := 100

signal closed
signal opened

## 1 = tela aberta; 0 = fechada.
var ratio := 1.0
var busy := false
## Falso nos testes que trocam de cena sem esperar a animação.
var enabled := true

var _canvas: Control
var _tween: Tween


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_iris)
	_canvas.visible = false
	add_child(_canvas)


## Retângulos (em px da tela) que cobrem tudo fora do círculo da íris. `ratio` 1 não cobre
## nada; 0 cobre a tela inteira. O círculo parte do centro e cresce até a diagonal.
static func iris_rects(size: Vector2, p_ratio: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if p_ratio >= 1.0:
		return rects
	if p_ratio <= 0.0:
		rects.append(Rect2(Vector2.ZERO, size))
		return rects
	var center := size / 2.0
	var radius := center.length() * p_ratio
	var y := 0.0
	while y < size.y:
		var strip_h := minf(STRIP, size.y - y)
		var dy := absf(y + strip_h / 2.0 - center.y)
		if dy >= radius:
			rects.append(Rect2(0.0, y, size.x, strip_h))
		else:
			var half := sqrt(radius * radius - dy * dy)
			half = floorf(half / STRIP) * STRIP  # degraus de pixel
			if center.x - half > 0.0:
				rects.append(Rect2(0.0, y, center.x - half, strip_h))
				rects.append(Rect2(center.x + half, y, size.x - center.x - half, strip_h))
		y += strip_h
	return rects


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	if _canvas != null:
		_canvas.visible = ratio < 1.0
		_canvas.queue_redraw()


func _draw_iris() -> void:
	var color := Palette.get_color("ink")
	for rect in iris_rects(_canvas.size, ratio):
		_canvas.draw_rect(rect, color)


func _animate(from: float, to: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	set_ratio(from)
	_tween = create_tween()
	_tween.tween_method(set_ratio, from, to, DURATION)
	await _tween.finished


## Volta ao estado inicial: tela aberta, sem transição em andamento (usado entre testes).
func reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	busy = false
	set_ratio(1.0)


## Fecha a íris (0,25 s).
func close() -> void:
	busy = true
	await _animate(1.0, 0.0)
	closed.emit()


## Abre a íris (0,25 s).
func open() -> void:
	await _animate(0.0, 1.0)
	busy = false
	opened.emit()


## Troca de cena com a íris: fecha, roda `before` (ajuste de estado), troca, abre.
func go(path: String, before := Callable()) -> void:
	await run(func() -> void: get_tree().change_scene_to_file(path), before)


## Como `go`, mas a troca é feita por `change` (ex.: estacionar o mundo e montar um interior).
func run(change: Callable, before := Callable()) -> void:
	if busy:
		return
	if not enabled or not is_inside_tree():
		if before.is_valid():
			before.call()
		change.call()
		return
	await close()
	if before.is_valid():
		before.call()
	change.call()
	# espera a cena nova existir antes de abrir
	await get_tree().process_frame
	await get_tree().process_frame
	await open()
