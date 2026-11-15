extends CanvasLayer
## Painel de loja: comprar o estoque e vender itens da mochila (por metade do preço).

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const ItemDefs := preload("res://scripts/items/item_defs.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")

signal closed

var _shop_id := ""
var _inventory: RefCounted = null
var _profile: RefCounted = null
var _is_open := false
var _title: Label
var _money: Label
var _message: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer


func _ready() -> void:
	layer = 21
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(680, 0)
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

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_title)
	_money = Label.new()
	box.add_child(_money)
	var buy_title := Label.new()
	buy_title.text = "Comprar"
	box.add_child(buy_title)
	_buy_list = VBoxContainer.new()
	box.add_child(_buy_list)
	box.add_child(HSeparator.new())
	var sell_title := Label.new()
	sell_title.text = "Vender (a loja paga metade do preço)"
	box.add_child(sell_title)
	_sell_list = VBoxContainer.new()
	box.add_child(_sell_list)
	box.add_child(HSeparator.new())
	_message = Label.new()
	box.add_child(_message)
	var close_button := Button.new()
	close_button.text = "Sair da loja (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	visible = false


func open(shop_id: String, inventory: RefCounted, profile: RefCounted) -> void:
	_disconnect()
	_shop_id = shop_id
	_inventory = inventory
	_profile = profile
	_inventory.changed.connect(refresh)
	_profile.changed.connect(refresh)
	_is_open = true
	visible = true
	_message.text = "Bem-vindo!"
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
	_title.text = ShopDefs.shop_name(_shop_id)
	_money.text = "Seu dinheiro: $%d" % _profile.money
	_clear(_buy_list)
	for item_id in ShopDefs.stock(_shop_id):
		var def := ItemDefs.get_def(item_id)
		var row := _row("%s — %s" % [def.name, def.description], "Comprar $%d" % ShopDefs.price_in(_shop_id, item_id))
		(row.get_child(1) as Button).pressed.connect(buy.bind(item_id))
		_buy_list.add_child(row)
	_clear(_sell_list)
	for item_id in _inventory.ids():
		var def := ItemDefs.get_def(item_id)
		var row := _row("%s ×%d" % [def.name, _inventory.count(item_id)], "Vender $%d" % ItemDefs.sell_price(item_id))
		(row.get_child(1) as Button).pressed.connect(sell.bind(item_id))
		_sell_list.add_child(row)


func buy(item_id: String) -> String:
	var result := ShopDefs.buy(_shop_id, item_id, _inventory, _profile)
	_message.text = ShopDefs.message_for(result, item_id)
	return result


func sell(item_id: String) -> String:
	var result := ShopDefs.sell(item_id, _inventory, _profile)
	_message.text = ShopDefs.message_for(result, item_id)
	return result


func title_text() -> String:
	return _title.text


func money_text() -> String:
	return _money.text


func message_text() -> String:
	return _message.text


func buy_row_count() -> int:
	return _buy_list.get_child_count()


func sell_row_count() -> int:
	return _sell_list.get_child_count()


func buy_button(index: int) -> Button:
	return _buy_list.get_child(index).get_child(1)


func _row(text: String, button_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(460, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var b := Button.new()
	b.text = button_text
	b.focus_mode = Control.FOCUS_NONE
	row.add_child(b)
	return row


func _clear(list: VBoxContainer) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()


func _disconnect() -> void:
	if _inventory != null and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	if _profile != null and _profile.changed.is_connected(refresh):
		_profile.changed.disconnect(refresh)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
