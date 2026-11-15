extends CanvasLayer
## Ficha do jogador (tecla C): nome, características, nível, XP e atributos com botão "+".

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const ProfileScript := preload("res://scripts/player/player_profile.gd")

signal closed

var _profile: RefCounted = null
var _is_open := false
var _name: Label
var _identity: Label
var _traits: Label
var _level: Label
var _unspent: Label
var _rows: VBoxContainer
var _stat_labels := {}
var _plus_buttons := {}


func _ready() -> void:
	layer = 21
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(620, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 30)
	box.add_child(_name)
	_identity = Label.new()
	box.add_child(_identity)
	_traits = Label.new()
	box.add_child(_traits)
	box.add_child(HSeparator.new())
	_level = Label.new()
	box.add_child(_level)
	_unspent = Label.new()
	box.add_child(_unspent)

	_rows = VBoxContainer.new()
	box.add_child(_rows)
	for s in ProfileScript.STATS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(500, 0)
		row.add_child(label)
		var plus := Button.new()
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(_spend.bind(s.id))
		row.add_child(plus)
		_rows.add_child(row)
		_stat_labels[s.id] = label
		_plus_buttons[s.id] = plus
	box.add_child(HSeparator.new())
	var close_button := Button.new()
	close_button.text = "Fechar (C / Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	visible = false


func open(profile: RefCounted) -> void:
	if _profile != null and _profile.changed.is_connected(refresh):
		_profile.changed.disconnect(refresh)
	_profile = profile
	_profile.changed.connect(refresh)
	_is_open = true
	visible = true
	refresh()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _is_open


func refresh() -> void:
	if _profile == null:
		return
	_name.text = _profile.player_name
	_identity.text = "Codinome \"%s\" • %s" % [_profile.codename, _profile.background]
	_traits.text = "Características: %s" % ", ".join(_profile.traits)
	_level.text = "Nível %d • XP %d/%d" % [_profile.level, _profile.xp, _profile.xp_for_next()]
	_unspent.text = "Pontos de atributo disponíveis: %d" % _profile.unspent
	for s in ProfileScript.STATS:
		_stat_labels[s.id].text = "%s %d/%d — %s\n    (%s)" % [
			s.name, _profile.stat(s.id), ProfileScript.MAX_STAT, _profile.effect_text(s.id), s.effect]
		(_plus_buttons[s.id] as Button).disabled = not _profile.can_spend(s.id)


func name_text() -> String:
	return _name.text


func level_text() -> String:
	return _level.text


func unspent_text() -> String:
	return _unspent.text


func stat_text(id: String) -> String:
	return _stat_labels[id].text


func plus_button(id: String) -> Button:
	return _plus_buttons[id]


func _spend(id: String) -> void:
	_profile.spend(id)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
