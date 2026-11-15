extends CanvasLayer
## Painel de inventário (tecla I): mostra as mãos e a mochila; cada item pode ser
## equipado na mão esquerda (botão esquerdo do mouse) ou na direita (botão direito).

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const ItemDefs := preload("res://scripts/items/item_defs.gd")

signal closed

var _inventory: RefCounted = null
var _is_open := false
var _hands_label: Label
var _list: VBoxContainer


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

	var title := Label.new()
	title.text = "Inventário"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_hands_label = Label.new()
	box.add_child(_hands_label)
	var hand_buttons := HBoxContainer.new()
	box.add_child(hand_buttons)
	for hand in ["left", "right"]:
		var b := Button.new()
		b.text = "Guardar mão %s" % ("esquerda" if hand == "left" else "direita")
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_unequip.bind(hand))
		hand_buttons.add_child(b)
	box.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	box.add_child(_list)
	box.add_child(HSeparator.new())
	var close_button := Button.new()
	close_button.text = "Fechar (I / Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	visible = false


func open(inventory: RefCounted) -> void:
	if _inventory != null and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = inventory
	_inventory.changed.connect(refresh)
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
	if _inventory == null:
		return
	_hands_label.text = "Mão esquerda: %s\nMão direita: %s" % [_hand_name("left"), _hand_name("right")]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for id in _inventory.ids():
		var def := ItemDefs.get_def(id)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s ×%d — %s" % [def.name, _inventory.count(id), def.description]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(400, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for hand in ["left", "right"]:
			var b := Button.new()
			b.text = "Esquerda" if hand == "left" else "Direita"
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_equip.bind(hand, id))
			row.add_child(b)
		_list.add_child(row)


func row_count() -> int:
	return _list.get_child_count()


func hands_text() -> String:
	return _hands_label.text


func _hand_name(hand: String) -> String:
	var def: Dictionary = _inventory.equipped_def(hand)
	return def.name if not def.is_empty() else "(vazia)"


func _equip(hand: String, id: String) -> void:
	_inventory.equip(hand, id)


func _unequip(hand: String) -> void:
	_inventory.unequip(hand)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
