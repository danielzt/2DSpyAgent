extends CanvasLayer
## Card de conversa com um NPC: nome, resumo, personalidade, resposta e perguntas.
## Perguntas por clique ou pelas teclas 1-4. Esc fecha.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")

signal closed

var _identity: Dictionary = {}
var _is_open := false
var _last_answer := ""

var _name: Label
var _info: Label
var _traits: Label
var _response: Label
var _buttons: VBoxContainer


func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(520, 0)
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
	_info = Label.new()
	box.add_child(_info)
	_traits = Label.new()
	box.add_child(_traits)
	box.add_child(HSeparator.new())
	_response = Label.new()
	_response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_response.custom_minimum_size = Vector2(480, 70)
	box.add_child(_response)
	box.add_child(HSeparator.new())

	_buttons = VBoxContainer.new()
	box.add_child(_buttons)
	for i in NpcIdentity.QUESTIONS.size():
		var q: Dictionary = NpcIdentity.QUESTIONS[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, q.text]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(ask.bind(q.id))
		_buttons.add_child(b)
	var close_button := Button.new()
	close_button.text = "Encerrar conversa (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	visible = false


func open(identity: Dictionary, reveal_traits := 2) -> void:
	_identity = identity
	_name.text = identity.name
	_info.text = NpcIdentity.summary(identity)
	_traits.text = NpcIdentity.traits_text(identity, reveal_traits)
	_last_answer = ""
	_response.text = "Escolha uma pergunta."
	_is_open = true
	visible = true


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func ask(question_id: String) -> void:
	if not _is_open:
		return
	_last_answer = NpcIdentity.answer(_identity, question_id)
	_response.text = "“%s”" % _last_answer


func is_open() -> bool:
	return _is_open


func name_text() -> String:
	return _name.text


func response_text() -> String:
	return _last_answer


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < NpcIdentity.QUESTIONS.size():
			ask(NpcIdentity.QUESTIONS[index].id)
			get_viewport().set_input_as_handled()
