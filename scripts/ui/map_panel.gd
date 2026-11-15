extends CanvasLayer
## Mapa de tela cheia (tecla M): mostra a cidade ou o campo (a tecla de interagir alterna),
## com bairros coloridos e nomeados, ruas com nome (as horizontais à esquerda, as verticais no
## alto), ícone por tipo de prédio já visitado ou visto, legenda, o jogador (piscando) e os
## alvos de crime. Passar o mouse sobre um ícone mostra o nome do lugar.

const MapView := preload("res://scripts/ui/map_view.gd")
const MapIcons := preload("res://scripts/art/map_icons.gd")
const DistrictLayout := preload("res://scripts/world/district_layout.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

signal closed

const CITY := "city"
const COUNTRY := "country"

const MARGIN := 24.0
const TOP := 92.0
const STREET_ROWS := 4
const STREETS_TOP := 56.0          # espaço acima do mapa para os nomes das ruas verticais
const STREETS_LEFT := 170.0        # espaço à esquerda para os nomes das ruas horizontais
const LEGEND_WIDTH := 250.0
const ICON_SCALE := 1.0
const LEGEND_ICON_SCALE := 2.0
const ROW := 24.0
const HOVER_RADIUS := 12.0
## Um clique a até tanto (px da tela) de um ponto já marcado escolhe esse ponto.
const SNAP_PIXELS := 12.0
const BLINK_SECONDS := 0.4

var layout
var known := {}
var player_position := Vector2.ZERO
var player_index := 1
var targets: Array = []
var profile
## O que o mapa mostra: CITY ou COUNTRY.
var mode := CITY

var _is_open := false
var _canvas: Control


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)
	visible = false


func open(p_layout, p_known: Dictionary, p_position: Vector2, p_targets: Array, p_profile = null) -> void:
	profile = p_profile
	layout = p_layout
	known = p_known
	player_position = p_position
	targets = p_targets
	# abre na região onde o jogador está
	mode = COUNTRY if (layout.country.region_rect() as Rect2).has_point(player_position) else CITY
	_is_open = true
	visible = true
	_canvas.queue_redraw()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _is_open


## Alterna entre a cidade e o campo.
func toggle_mode() -> void:
	mode = COUNTRY if mode == CITY else CITY
	_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if not _is_open:
		return
	if Input.is_action_just_pressed("p%d_interact" % player_index):
		toggle_mode()
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Parte do mundo mostrada: a cidade (quadrada) ou o campo.
func view_rect() -> Rect2:
	if mode == COUNTRY:
		return layout.country.region_rect()
	return Rect2(Vector2.ZERO, Vector2(CityLayout.city_size(), CityLayout.city_size()))


## Área da tela onde o mapa cabe, entre os nomes das ruas, o título e a legenda.
func map_rect(screen: Vector2) -> Rect2:
	var area := Rect2(MARGIN + STREETS_LEFT, TOP + STREETS_TOP,
			screen.x - MARGIN * 2.0 - STREETS_LEFT - LEGEND_WIDTH, screen.y - TOP - STREETS_TOP - MARGIN)
	return MapView.fit(view_rect(), area)


## Centro (em px do mundo) do bairro: média dos quarteirões dele.
func district_center(id: String) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for cell in layout.city.districts.cells:
		if layout.city.districts.cells[cell] == id:
			sum += (Vector2(cell) + Vector2(0.5, 0.5)) * CityLayout.BLOCK
			n += 1
	return sum / n if n > 0 else Vector2.ZERO


func _text(content: String, color_name: String, pos: Vector2, text_scale := 2.0, align := 0, outline := "ink") -> void:
	var texture := SpriteFactory.text(content, color_name, outline, align)
	var size := Vector2(texture.get_size()) * text_scale
	var origin := pos
	if align == 1:
		origin.x -= size.x / 2.0
	elif align == 2:
		origin.x -= size.x
	_canvas.draw_texture_rect(texture, Rect2(origin.round(), size), false)


func _draw_map() -> void:
	var screen := _canvas.size
	var ink := Palette.get_color("ink")
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(ink.r, ink.g, ink.b, 0.94))
	_text("MAPA", "neon_cyan", Vector2(MARGIN, MARGIN), 4.0)
	_text("M ou Esc fecha. %s alterna cidade e campo." % _interact_key(), "gray", Vector2(MARGIN, MARGIN + 38.0), 2.0)
	_text("Clique: marcar ponto. Botão direito: tirar.", "gray", Vector2(MARGIN, MARGIN + 100.0), 1.0)
	if layout == null:
		return
	var view := view_rect()
	var dest := map_rect(screen)
	MapView.draw(_canvas, layout, known, view, dest, ICON_SCALE, profile)
	_canvas.draw_rect(dest.grow(2.0), Palette.get_color("neon_cyan"), false, 2.0)
	_text("CIDADE" if mode == CITY else "CAMPO", "amber", Vector2(MARGIN, MARGIN + 70.0), 3.0)
	if mode == CITY:
		_draw_district_names(view, dest)
		_draw_street_names(view, dest)
	_draw_markers(view, dest)
	_draw_legend(dest)
	_draw_hover(view, dest)


## Clique esquerdo: marca um ponto (ou ativa o que já estiver perto). Retorna o índice, ou -1
## se o clique foi fora do mapa ou não há ficha.
func place_waypoint(screen_point: Vector2, screen: Vector2) -> int:
	if profile == null or layout == null:
		return -1
	var view := view_rect()
	var dest := map_rect(screen)
	if not dest.has_point(screen_point):
		return -1
	var world := MapView.to_world(screen_point, view, dest)
	var near: int = profile.waypoint_near(world, SNAP_PIXELS / (dest.size.x / view.size.x))
	if near >= 0:
		profile.active_waypoint = near
		return near
	return profile.add_waypoint(world)


## Clique direito: tira o ponto mais perto do clique. Retorna true se tirou.
func remove_waypoint_at(screen_point: Vector2, screen: Vector2) -> bool:
	if profile == null or layout == null:
		return false
	var view := view_rect()
	var dest := map_rect(screen)
	var near: int = profile.waypoint_near(MapView.to_world(screen_point, view, dest), SNAP_PIXELS / (dest.size.x / view.size.x))
	if near < 0:
		return false
	profile.remove_waypoint(near)
	return true


func _on_canvas_input(event: InputEvent) -> void:
	if not _is_open or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		place_waypoint(event.position, _canvas.size)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		remove_waypoint_at(event.position, _canvas.size)


func _interact_key() -> String:
	return InputSetupScript.key_label("p%d_interact" % player_index)


func _draw_district_names(view: Rect2, dest: Rect2) -> void:
	for id in DistrictLayout.IDS:
		var pos := district_center(id)
		if pos == Vector2.ZERO:
			continue
		_text(layout.city.districts.name_of(id), "white", MapView.to_screen(pos, view, dest), 2.0, 1)


func _draw_street_names(view: Rect2, dest: Rect2) -> void:
	var names: Dictionary = layout.city.street_names
	if names.is_empty():
		return
	var tick := Palette.get_color("slate")
	for line in names.h.size():
		var y := MapView.to_screen(Vector2(0.0, line * CityLayout.BLOCK), view, dest).y
		_text(names.h[line], "light", Vector2(dest.position.x - 8.0, y - 4.0), 1.0, 2)
	for line in names.v.size():
		var x := MapView.to_screen(Vector2(line * CityLayout.BLOCK, 0.0), view, dest).x
		var row: int = line % STREET_ROWS
		var label_y: float = dest.position.y - 14.0 - row * 12.0
		_canvas.draw_line(Vector2(x, label_y + 8.0), Vector2(x, dest.position.y), tick, 1.0)
		_text(names.v[line], "light", Vector2(x, label_y), 1.0, 1)


func _draw_markers(view: Rect2, dest: Rect2) -> void:
	var bounds := dest.grow(20.0)
	for target in targets:
		if view.has_point(target):
			MapView.draw_glyph(_canvas, "alert", MapView.to_screen(target, view, dest), 2.0, bounds)
	if view.has_point(player_position) and int(Time.get_ticks_msec() / (BLINK_SECONDS * 1000.0)) % 2 == 0:
		MapView.draw_glyph(_canvas, "you", MapView.to_screen(player_position, view, dest), 2.0, bounds)


func _draw_legend(dest: Rect2) -> void:
	var x := dest.end.x + MARGIN
	var everything := Rect2(Vector2.ZERO, _canvas.size)
	_text("LEGENDA", "amber", Vector2(x, TOP), 2.0)
	var y := TOP + ROW + 6.0
	for glyph in MapIcons.LABELS:
		MapView.draw_glyph(_canvas, glyph, Vector2(x + 9.0, y + 9.0), LEGEND_ICON_SCALE, everything)
		_text(MapIcons.label_of(glyph), "light", Vector2(x + 28.0, y + 2.0), 2.0)
		y += ROW
	MapView.draw_glyph(_canvas, "you", Vector2(x + 9.0, y + 9.0), LEGEND_ICON_SCALE, everything)
	_text("Você", "neon_cyan", Vector2(x + 28.0, y + 2.0), 2.0)
	y += ROW
	MapView.draw_glyph(_canvas, "alert", Vector2(x + 9.0, y + 9.0), LEGEND_ICON_SCALE, everything)
	_text("Crime", "red", Vector2(x + 28.0, y + 2.0), 2.0)


## Ícone conhecido mais perto do ponto da tela (dentro de HOVER_RADIUS), ou {}.
func icon_near(screen_point: Vector2, screen: Vector2) -> Dictionary:
	if layout == null:
		return {}
	var view := view_rect()
	var dest := map_rect(screen)
	var best := {}
	var best_d := HOVER_RADIUS
	for icon in MapView.known_icons(layout, known):
		if not view.has_point(icon.pos):
			continue
		var d := MapView.to_screen(icon.pos, view, dest).distance_to(screen_point)
		if d < best_d:
			best_d = d
			best = icon
	return best


func _draw_hover(view: Rect2, dest: Rect2) -> void:
	var icon := icon_near(_canvas.get_local_mouse_position(), _canvas.size)
	if icon.is_empty():
		return
	var at := MapView.to_screen(icon.pos, view, dest) + Vector2(14.0, -26.0)
	var texture := SpriteFactory.text(icon.name, "white", "ink", 0)
	var size := Vector2(texture.get_size()) * 2.0
	var plate := Rect2(at - Vector2(6, 4), size + Vector2(12, 8))
	_canvas.draw_rect(plate, Palette.get_color("ink"))
	_canvas.draw_rect(plate, Palette.get_color("amber"), false, 2.0)
	_canvas.draw_texture_rect(texture, Rect2(at, size), false)
