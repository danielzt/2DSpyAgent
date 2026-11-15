extends "res://tests/base_test.gd"
## Itens no chão, dinheiro, loot, lojas (lógica, painel, interior) e avisos.

const PickupScript := preload("res://scripts/items/pickup.gd")
const ShopDefs := preload("res://scripts/items/shop_defs.gd")
const ItemDefs := preload("res://scripts/items/item_defs.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const ProfileScript := preload("res://scripts/player/player_profile.gd")
const ShopPanelScript := preload("res://scripts/ui/shop_panel.gd")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var player
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	GameState.set_outside()
	GameState.has_return = false


func after_each() -> void:
	for a in ["p1_interact", "p1_right"]:
		Input.action_release(a)
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	for p in tree.get_nodes_in_group("pickups"):
		p.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	GameState.set_outside()
	await wait_frames(2)


func _spawn_player(pos := Vector2(500, 500)) -> Node:
	player = PLAYER_SCENE.instantiate()
	player.global_position = pos
	tree.root.add_child(player)
	await wait_physics_frames(2)
	return player


func _pickup(item: String, amount: int, pos: Vector2) -> Node:
	var p = PickupScript.spawn(tree.root, pos, item, amount)
	extras.append(p)
	return p


# --- preços e economia (puro) ---

func test_every_item_has_a_price_and_sells_for_half() -> void:
	for id in ItemDefs.all_ids():
		assert_gt(ItemDefs.price(id), 0.0, id)
		assert_eq(ItemDefs.sell_price(id), int(ItemDefs.price(id) / 2.0))
		assert_true(ItemDefs.sell_price(id) < ItemDefs.price(id))


func test_shops_sell_known_items_only() -> void:
	for shop_id in ShopDefs.SHOPS:
		assert_ne(ShopDefs.shop_name(shop_id), "")
		assert_gt(ShopDefs.stock(shop_id).size(), 0.0)
		for item in ShopDefs.stock(shop_id):
			assert_true(ItemDefs.exists(item), "%s vende item inexistente %s" % [shop_id, item])


func test_each_shop_type_has_a_different_stock() -> void:
	assert_ne(ShopDefs.stock("armory"), ShopDefs.stock("pharmacy"))
	assert_true(ShopDefs.stock("pharmacy").has("medkit"))
	assert_true(ShopDefs.stock("armory").has("shotgun"))
	assert_eq(ShopDefs.stock("nao_existe"), [])


func test_buy_spends_money_and_adds_the_item() -> void:
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	profile.money = 500
	assert_eq(ShopDefs.buy("armory", "pistol", inv, profile), "ok")
	assert_eq(profile.money, 500 - ItemDefs.price("pistol"))
	assert_eq(inv.count("pistol"), 1)


func test_buy_fails_without_money_and_changes_nothing() -> void:
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	profile.money = 10
	assert_eq(ShopDefs.buy("armory", "shotgun", inv, profile), "no_money")
	assert_eq(profile.money, 10)
	assert_eq(inv.count("shotgun"), 0)


func test_buy_fails_when_the_shop_does_not_sell_it() -> void:
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	assert_eq(ShopDefs.buy("pharmacy", "shotgun", inv, profile), "not_sold")
	assert_eq(profile.money, ProfileScript.START_MONEY)


func test_buy_fails_when_stack_is_full_without_charging() -> void:
	var inv = InventoryScript.new()
	inv.add("medkit", InventoryScript.MAX_COUNT)
	var profile = ProfileScript.new()
	assert_eq(ShopDefs.buy("pharmacy", "medkit", inv, profile), "no_space")
	assert_eq(profile.money, ProfileScript.START_MONEY, "não cobra se não coube")


func test_sell_pays_half_and_removes_the_item() -> void:
	var inv = InventoryScript.starter_kit()
	var profile = ProfileScript.new()
	assert_eq(ShopDefs.sell("taser", inv, profile), "ok")
	assert_eq(profile.money, ProfileScript.START_MONEY + ItemDefs.sell_price("taser"))
	assert_eq(inv.count("taser"), 0)
	assert_eq(ShopDefs.sell("taser", inv, profile), "not_owned")


func test_selling_an_equipped_item_empties_the_hand() -> void:
	var inv = InventoryScript.starter_kit()
	var profile = ProfileScript.new()
	ShopDefs.sell("pistol", inv, profile)
	assert_eq(inv.equipped("left"), "")


func test_buy_then_sell_loses_money() -> void:
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	profile.money = 1000
	ShopDefs.buy("armory", "pistol", inv, profile)
	ShopDefs.sell("pistol", inv, profile)
	assert_true(profile.money < 1000)


func test_messages() -> void:
	assert_true(ShopDefs.message_for("ok", "pistol").contains("Pistola"))
	assert_true(ShopDefs.message_for("no_money").contains("insuficiente"))
	assert_ne(ShopDefs.message_for("no_space"), "")
	assert_eq(ShopDefs.message_for("???"), "")


func test_inventory_stack_limit() -> void:
	var inv = InventoryScript.new()
	assert_true(inv.add("medkit", InventoryScript.MAX_COUNT))
	assert_false(inv.add("medkit"))
	assert_eq(inv.count("medkit"), InventoryScript.MAX_COUNT)


func test_money_math() -> void:
	var profile = ProfileScript.new()
	assert_eq(profile.money, ProfileScript.START_MONEY)
	assert_true(profile.spend_money(50))
	assert_eq(profile.money, ProfileScript.START_MONEY - 50)
	assert_false(profile.spend_money(100000))
	assert_false(profile.spend_money(-5))
	profile.add_money(70)
	assert_eq(profile.money, ProfileScript.START_MONEY + 20)
	profile.add_money(-1000000)
	assert_eq(profile.money, 0, "dinheiro nunca fica negativo")


# --- painel de loja ---

func test_shop_panel_lists_stock_and_inventory() -> void:
	var panel := ShopPanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.starter_kit()
	var profile = ProfileScript.new()
	panel.open("agent_store", inv, profile)
	assert_true(panel.is_open())
	assert_eq(panel.title_text(), "Loja do Agente")
	assert_eq(panel.buy_row_count(), ShopDefs.stock("agent_store").size())
	assert_eq(panel.sell_row_count(), inv.ids().size())
	assert_true(panel.money_text().contains(str(profile.money)))
	panel.close()
	assert_false(panel.is_open())


func test_shop_panel_buy_button_works_and_updates() -> void:
	var panel := ShopPanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	profile.money = 300
	panel.open("pharmacy", inv, profile)
	panel.buy_button(0).pressed.emit()
	assert_eq(inv.count("medkit"), 1)
	assert_eq(profile.money, 300 - ItemDefs.price("medkit"))
	assert_true(panel.money_text().contains(str(profile.money)))
	assert_eq(panel.sell_row_count(), 1, "lista de venda atualiza")
	assert_true(panel.message_text().contains("Kit médico"))


func test_shop_panel_reports_insufficient_money() -> void:
	var panel := ShopPanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.new()
	var profile = ProfileScript.new()
	profile.money = 1
	panel.open("armory", inv, profile)
	assert_eq(panel.buy("shotgun"), "no_money")
	assert_true(panel.message_text().contains("insuficiente"))


func test_shop_panel_sell() -> void:
	var panel := ShopPanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.starter_kit()
	var profile = ProfileScript.new()
	panel.open("armory", inv, profile)
	assert_eq(panel.sell("shotgun"), "ok")
	assert_eq(inv.count("shotgun"), 0)
	assert_eq(panel.sell_row_count(), inv.ids().size())


# --- jogador e loja ---

func test_player_open_shop_blocks_actions_and_closes_other_panels() -> void:
	await _spawn_player()
	player.toggle_inventory()
	assert_true(player.open_shop("pharmacy"))
	assert_true(player.shop_panel.is_open())
	assert_false(player.inventory_panel.is_open())
	assert_true(player.panels_open())
	var start: Vector2 = player.global_position
	Input.action_press("p1_right")
	await wait_physics_frames(15)
	Input.action_release("p1_right")
	assert_eq(player.global_position, start)
	assert_eq(player.current_prompt(), "")


func test_player_cannot_open_unknown_shop() -> void:
	await _spawn_player()
	assert_false(player.open_shop("nao_existe"))
	assert_false(player.shop_panel.is_open())


func test_inventory_key_closes_the_shop() -> void:
	await _spawn_player()
	player.open_shop("pharmacy")
	player.toggle_inventory()
	assert_false(player.shop_panel.is_open())
	assert_true(player.inventory_panel.is_open())


# --- itens no chão ---

func test_item_pickup_requires_pressing_e() -> void:
	await _spawn_player()
	var p = _pickup("medkit", 1, Vector2(525, 500))
	await wait_physics_frames(3)
	assert_eq(player.interactable, p)
	assert_true(player.current_prompt().contains("pegar Kit médico"))
	assert_true(player.current_prompt().contains("E"))
	assert_eq(player.inventory.count("medkit"), 3, "não pega sozinho")
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(player.inventory.count("medkit"), 4)
	await wait_frames(2)
	assert_false(is_instance_valid(p), "o item some do chão")
	assert_true(player.hud.toast_text().contains("Pegou Kit médico"))


func test_cash_is_collected_by_walking_over_it() -> void:
	await _spawn_player()
	var before: int = player.profile.money
	var p = _pickup("cash", 55, Vector2(520, 500))
	await wait_physics_frames(3)
	assert_eq(player.profile.money, before + 55)
	await wait_frames(2)
	assert_false(is_instance_valid(p))
	assert_true(player.hud.toast_text().contains("+$55"))


func test_cash_does_not_set_an_interaction_prompt() -> void:
	await _spawn_player()
	_pickup("cash", 10, Vector2(900, 900))
	assert_eq(player.current_prompt(), "")


func test_full_bag_refuses_item_and_keeps_it_on_the_ground() -> void:
	await _spawn_player()
	player.inventory.add("medkit", 6)  # 9 no total
	var p = _pickup("medkit", 1, Vector2(525, 500))
	await wait_physics_frames(3)
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(player.inventory.count("medkit"), 9)
	assert_true(is_instance_valid(p) and not p.is_queued_for_deletion())
	assert_true(player.hud.toast_text().contains("Mochila cheia"))


func test_pickup_amount_is_part_of_the_name() -> void:
	var p = _pickup("medkit", 2, Vector2(0, 0))
	assert_true(p.display_name().contains("×2"))
	assert_eq(_pickup("cash", 30, Vector2(50, 0)).display_name(), "$30")


func test_pickup_is_in_group() -> void:
	var p = _pickup("taser", 1, Vector2(0, 0))
	assert_true(p.is_in_group("pickups"))


# --- loot ---

func test_killed_criminal_drops_cash() -> void:
	var npc := NPC_SCENE.instantiate()
	npc.kind = "criminal"
	npc.ai_seed = 9
	npc.global_position = Vector2(300, 300)
	tree.root.add_child(npc)
	extras.append(npc)
	await wait_physics_frames(1)
	var loot_min: int = npc.LOOT_CASH_MIN
	var loot_max: int = npc.LOOT_CASH_MAX
	npc.take_damage(5, null)
	await wait_frames(2)
	var cash := []
	for p in tree.get_nodes_in_group("pickups"):
		if p.item_id == "cash":
			cash.append(p)
	assert_eq(cash.size(), 1)
	assert_true(cash[0].amount >= loot_min and cash[0].amount <= loot_max)
	assert_true(cash[0].global_position.distance_to(Vector2(300, 300)) < 5.0)


func test_killed_civilian_drops_nothing() -> void:
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 9
	npc.global_position = Vector2(300, 300)
	tree.root.add_child(npc)
	extras.append(npc)
	await wait_physics_frames(1)
	npc.take_damage(5, null)
	await wait_frames(2)
	assert_eq(tree.get_nodes_in_group("pickups").size(), 0)


func test_stunned_criminal_does_not_drop_loot() -> void:
	var npc := NPC_SCENE.instantiate()
	npc.kind = "criminal"
	npc.global_position = Vector2(300, 300)
	tree.root.add_child(npc)
	extras.append(npc)
	npc.stun(3.0)
	await wait_frames(2)
	assert_eq(tree.get_nodes_in_group("pickups").size(), 0)


# --- interior de loja ---

func test_shop_interior_layout_keeps_counter_area_clear() -> void:
	for id in 30:
		var layout := InteriorLayout.new(id, true)
		assert_eq(layout.furniture.size(), InteriorLayout.SHOP_FURNITURE_COUNT)
		for r in layout.furniture:
			assert_false(r.intersects(InteriorLayout.SHOP_ZONE))
			assert_false(r.intersects(InteriorLayout.CLEAR_ZONE))


func test_counter_zone_is_in_front_of_the_counter_and_reachable() -> void:
	var zone := InteriorLayout.counter_zone()
	assert_almost_eq(zone.position.y, InteriorLayout.COUNTER.end.y, 0.001)
	assert_true(Rect2(Vector2.ZERO, InteriorLayout.SIZE).encloses(zone))
	assert_true(InteriorLayout.merchant_position().y < InteriorLayout.COUNTER.position.y)
	assert_false(zone.intersects(InteriorLayout.COUNTER))


func test_regular_interior_is_unchanged() -> void:
	assert_eq(InteriorLayout.new(3).furniture.size(), InteriorLayout.FURNITURE_COUNT)
	assert_eq(InteriorLayout.new(3).furniture, InteriorLayout.new(3, false).furniture)


func test_shop_interior_scene_has_counter_and_buy_prompt() -> void:
	GameState.set_inside(5, Vector2.ZERO, "pharmacy")
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	extras.append(interior)
	await wait_physics_frames(3)
	var zones := tree.get_nodes_in_group("shop_zones")
	assert_eq(zones.size(), 1)
	var p: Node = tree.get_nodes_in_group("players")[0]
	p.global_position = InteriorLayout.counter_zone().get_center()
	await wait_physics_frames(4)
	assert_true(p.current_prompt().contains("comprar na Farmácia"))
	assert_false(p.shop_panel.is_open(), "só abre ao apertar E")
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_true(p.shop_panel.is_open())
	assert_eq(p.shop_panel.title_text(), "Farmácia")


func test_plain_interior_has_no_shop_zone() -> void:
	GameState.set_inside(5, Vector2.ZERO, "")
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	extras.append(interior)
	await wait_physics_frames(2)
	assert_eq(tree.get_nodes_in_group("shop_zones").size(), 0)


func test_game_state_keeps_the_shop_kind_until_exit() -> void:
	GameState.set_inside(7, Vector2.ZERO, "armory")
	assert_eq(GameState.building_shop, "armory")
	GameState.set_outside()
	assert_eq(GameState.building_shop, "")


# --- HUD ---

func test_hud_shows_money_and_toast() -> void:
	await _spawn_player()
	await wait_frames(2)
	assert_eq(player.hud.money_text(), "$ %d" % player.profile.money)
	player.profile.add_money(25)
	await wait_frames(2)
	assert_eq(player.hud.money_text(), "$ %d" % player.profile.money)
	player.notify("Olá", 0.2)
	assert_true(player.hud.toast_visible())
	assert_eq(player.hud.toast_text(), "Olá")
	await wait_frames(30)
	assert_false(player.hud.toast_visible(), "aviso some depois do tempo")
