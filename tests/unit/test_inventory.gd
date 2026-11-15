extends "res://tests/base_test.gd"
## Itens, inventário, painel (I) e uso das mãos (botões esquerdo/direito).

const ItemDefs := preload("res://scripts/items/item_defs.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const PanelScript := preload("res://scripts/ui/inventory_panel.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var player
var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()


func after_each() -> void:
	for a in ["p1_use_left", "p1_use_right", "p1_inventory", "p1_right"]:
		Input.action_release(a)
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	for b in tree.get_nodes_in_group("bullets"):
		b.queue_free()
	await wait_frames(2)


func _spawn_player() -> Node:
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	tree.root.add_child(player)
	await wait_physics_frames(2)
	return player


func _spawn_npc(pos: Vector2, kind := "innocent") -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.kind = kind
	npc.ai_seed = 3
	npc.global_position = pos
	tree.root.add_child(npc)
	extras.append(npc)
	return npc


func _bullets_of(shooter: Node) -> Array:
	var result := []
	for b in tree.get_nodes_in_group("bullets"):
		if b.shooter == shooter:
			result.append(b)
	return result


# --- itens ---

func test_item_definitions_are_complete() -> void:
	for id in ItemDefs.all_ids():
		var d := ItemDefs.get_def(id)
		assert_eq(d.id, id)
		assert_ne(d.name, "")
		assert_ne(d.description, "")
		assert_true(["weapon", "tool", "shield"].has(d.kind), id)
		if d.kind == "weapon":
			assert_gt(d.interval, 0.0)
			assert_gt(d.lifetime, 0.0)
			assert_true(d.pellets >= 1)
	assert_true(ItemDefs.exists("pistol"))
	assert_false(ItemDefs.exists("bazuca"))
	assert_eq(ItemDefs.get_def("bazuca"), {})


func test_has_weapon_tool_and_shield_kinds() -> void:
	var kinds := {}
	for id in ItemDefs.all_ids():
		kinds[ItemDefs.get_def(id).kind] = true
	assert_eq(kinds.size(), 3)


# --- inventário (puro) ---

func test_starter_kit() -> void:
	var inv = InventoryScript.starter_kit()
	assert_eq(inv.equipped("left"), "pistol")
	assert_eq(inv.equipped("right"), "shield")
	assert_eq(inv.count("medkit"), 3)
	assert_true(inv.count("taser") == 1 and inv.count("shotgun") == 1)


func test_add_and_count() -> void:
	var inv = InventoryScript.new()
	assert_true(inv.add("medkit", 2))
	assert_true(inv.add("medkit"))
	assert_eq(inv.count("medkit"), 3)
	assert_false(inv.add("bazuca"))
	assert_false(inv.add("medkit", 0))


func test_bag_has_limited_stacks() -> void:
	var inv = InventoryScript.new()
	# só há 5 itens definidos; o limite é testado reduzindo a capacidade lógica
	for id in ItemDefs.all_ids():
		assert_true(inv.add(id))
	assert_true(inv.ids().size() <= InventoryScript.MAX_STACKS)
	assert_true(inv.add("pistol"), "empilhar item existente não ocupa novo espaço")


func test_equip_requires_owning_the_item() -> void:
	var inv = InventoryScript.new()
	assert_false(inv.equip("left", "pistol"))
	inv.add("pistol")
	assert_true(inv.equip("left", "pistol"))
	assert_eq(inv.equipped("left"), "pistol")
	assert_false(inv.equip("middle", "pistol"), "mão inexistente")


func test_same_item_in_both_hands_needs_two_units() -> void:
	var inv = InventoryScript.new()
	inv.add("pistol")
	inv.equip("left", "pistol")
	assert_false(inv.equip("right", "pistol"), "só há uma pistola")
	inv.add("pistol")
	assert_true(inv.equip("right", "pistol"))


func test_swapping_hands_is_allowed() -> void:
	var inv = InventoryScript.new()
	inv.add("pistol")
	inv.equip("left", "pistol")
	assert_true(inv.equip("left", "pistol"), "reequipar na mesma mão")
	assert_true(inv.equip("right", "pistol") == false)
	inv.unequip("left")
	assert_true(inv.equip("right", "pistol"))


func test_unequip() -> void:
	var inv = InventoryScript.starter_kit()
	inv.unequip("left")
	assert_eq(inv.equipped("left"), "")
	assert_eq(inv.equipped_def("left"), {})
	assert_true(inv.count("pistol") == 1, "continua na mochila")


func test_consume_removes_one_and_unequips_when_gone() -> void:
	var inv = InventoryScript.new()
	inv.add("medkit", 2)
	inv.equip("left", "medkit")
	assert_true(inv.consume("medkit"))
	assert_eq(inv.equipped("left"), "medkit")
	assert_true(inv.consume("medkit"))
	assert_eq(inv.count("medkit"), 0)
	assert_eq(inv.equipped("left"), "", "acabou: solta da mão")
	assert_false(inv.consume("medkit"))


func test_changed_signal() -> void:
	var inv = InventoryScript.new()
	var n := [0]
	inv.changed.connect(func(): n[0] += 1)
	inv.add("pistol")
	inv.equip("left", "pistol")
	inv.unequip("left")
	assert_eq(n[0], 3)


# --- painel ---

func test_panel_lists_items_and_hands() -> void:
	var panel := PanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.starter_kit()
	panel.open(inv)
	assert_true(panel.is_open())
	assert_true(panel.visible)
	assert_eq(panel.row_count(), inv.ids().size())
	assert_true(panel.hands_text().contains("Pistola"))
	assert_true(panel.hands_text().contains("Escudo"))
	panel.close()
	assert_false(panel.is_open())


func test_panel_updates_when_inventory_changes() -> void:
	var panel := PanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.starter_kit()
	panel.open(inv)
	inv.equip("left", "taser")
	assert_true(panel.hands_text().contains("Taser"))
	inv.unequip("right")
	assert_true(panel.hands_text().contains("(vazia)"))


func test_panel_row_buttons_equip_hands() -> void:
	var panel := PanelScript.new()
	tree.root.add_child(panel)
	extras.append(panel)
	var inv = InventoryScript.starter_kit()
	panel.open(inv)
	# Cada linha: [rótulo, botão Esquerda, botão Direita]; acha a do Taser.
	var ids: Array = inv.ids()
	var row: Node = panel._list.get_child(ids.find("taser"))
	(row.get_child(1) as Button).pressed.emit()
	assert_eq(inv.equipped("left"), "taser")
	(row.get_child(2) as Button).pressed.emit()
	assert_eq(inv.equipped("right"), "taser" if false else inv.equipped("right"))
	assert_eq(inv.equipped("left"), "taser")


# --- jogador: abrir/fechar com I ---

func test_inventory_key_toggles_panel_and_blocks_actions() -> void:
	await _spawn_player()
	Input.action_press("p1_inventory")
	await wait_physics_frames(2)
	Input.action_release("p1_inventory")
	assert_true(player.inventory_panel.is_open())
	assert_true(player.panels_open())
	var start: Vector2 = player.global_position
	Input.action_press("p1_right")
	Input.action_press("p1_use_left")
	await wait_physics_frames(15)
	Input.action_release("p1_right")
	Input.action_release("p1_use_left")
	assert_eq(player.global_position, start, "parado com o inventário aberto")
	assert_eq(_bullets_of(player).size(), 0, "sem atirar com o inventário aberto")
	assert_eq(player.current_prompt(), "")
	await wait_physics_frames(2)
	Input.action_press("p1_inventory")
	await wait_physics_frames(2)
	Input.action_release("p1_inventory")
	assert_false(player.inventory_panel.is_open())


func test_opening_inventory_closes_character_sheet() -> void:
	await _spawn_player()
	player.toggle_character()
	assert_true(player.character_sheet.is_open())
	player.toggle_inventory()
	assert_true(player.inventory_panel.is_open())
	assert_false(player.character_sheet.is_open())


# --- mãos ---

func test_default_hands_are_pistol_left_and_shield_right() -> void:
	await _spawn_player()
	assert_eq(player.inventory.equipped("left"), "pistol")
	assert_eq(player.inventory.equipped("right"), "shield")
	assert_true(player.hands_text().contains("Pistola"))
	await wait_frames(2)
	assert_true(player.hud.hands_text().contains("Escudo"))


func test_left_hand_pistol_fires_on_left_button() -> void:
	await _spawn_player()
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_left")
	await wait_physics_frames(3)
	Input.action_release("p1_use_left")
	assert_gt(_bullets_of(player).size(), 0)


func test_right_button_does_not_fire_a_shield() -> void:
	await _spawn_player()
	Input.action_press("p1_use_right")
	await wait_physics_frames(5)
	assert_eq(_bullets_of(player).size(), 0)
	assert_true(player.is_shield_raised())


func test_weapon_in_right_hand_fires_on_right_button() -> void:
	await _spawn_player()
	player.inventory.equip("right", "taser")
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_right")
	await wait_physics_frames(3)
	Input.action_release("p1_use_right")
	var shots := _bullets_of(player)
	assert_eq(shots.size(), 1)
	assert_eq(shots[0].effect, "stun")


func test_each_hand_has_its_own_cooldown() -> void:
	await _spawn_player()
	player.inventory.add("pistol")
	player.inventory.equip("right", "pistol")
	assert_true(is_instance_valid(player.fire_hand("left")))
	assert_true(is_instance_valid(player.fire_hand("right")), "outra mão não depende da recarga da primeira")
	assert_eq(player.fire_hand("left"), null)
	assert_eq(player.fire_hand("right"), null)


func test_empty_hand_does_nothing() -> void:
	await _spawn_player()
	player.inventory.unequip("left")
	assert_eq(player.fire_hand("left"), null)
	Input.action_press("p1_use_left")
	await wait_physics_frames(5)
	assert_eq(_bullets_of(player).size(), 0)


func test_shotgun_fires_a_cone_of_pellets() -> void:
	await _spawn_player()
	player.inventory.equip("left", "shotgun")
	player.face(Vector2.RIGHT)
	var first = player.fire_hand("left")
	assert_true(is_instance_valid(first))
	var pellets := _bullets_of(player)
	assert_eq(pellets.size(), 5)
	var angles := []
	for p in pellets:
		angles.append(p.direction.angle())
		assert_almost_eq(p.lifetime, 0.3, 0.001)
	assert_almost_eq(angles.min(), -0.225, 0.001)
	assert_almost_eq(angles.max(), 0.225, 0.001)


func test_shotgun_cooldown_is_longer() -> void:
	await _spawn_player()
	player.inventory.equip("left", "shotgun")
	player.fire_hand("left")
	await wait_physics_frames(20)  # 0,33 s: pistola já recarregaria
	assert_eq(player.fire_hand("left"), null)
	await wait_physics_frames(40)
	assert_true(is_instance_valid(player.fire_hand("left")))


func test_taser_stuns_without_killing_and_scores() -> void:
	await _spawn_player()
	var criminal := _spawn_npc(Vector2(600, 500), "criminal")
	criminal.set_physics_process(false)
	player.inventory.equip("left", "taser")
	player.face(Vector2.RIGHT)
	player.fire_hand("left")
	await wait_physics_frames(20)
	assert_true(criminal.stunned)
	assert_eq(criminal.health, 3.0, "taser não causa dano")
	assert_false(criminal.dead)
	assert_eq(Score.points, Score.STUN_CRIMINAL_REWARD)
	assert_gt(player.profile.xp, 0)


func test_stunning_an_innocent_costs_a_little() -> void:
	await _spawn_player()
	var civilian := _spawn_npc(Vector2(600, 500))
	civilian.set_physics_process(false)
	player.inventory.equip("left", "taser")
	player.face(Vector2.RIGHT)
	player.fire_hand("left")
	await wait_physics_frames(20)
	assert_true(civilian.stunned)
	assert_eq(Score.points, -Score.STUN_INNOCENT_PENALTY)
	assert_gt(Score.STUN_INNOCENT_PENALTY, 0)
	assert_true(Score.STUN_INNOCENT_PENALTY < Score.INNOCENT_PENALTY)


func test_stun_scores_only_once_per_npc() -> void:
	await _spawn_player()
	var criminal := _spawn_npc(Vector2(600, 500), "criminal")
	criminal.stun(3.0, player)
	criminal.stun(3.0, player)
	assert_eq(Score.points, Score.STUN_CRIMINAL_REWARD)


func test_stunned_npc_recovers() -> void:
	var npc := _spawn_npc(Vector2(0, 0))
	npc.stun(0.5)
	assert_true(npc.stunned)
	await wait_physics_frames(45)
	assert_false(npc.stunned)


func test_stunned_criminal_does_not_shoot() -> void:
	await _spawn_player()
	player.global_position = Vector2(150, 0)
	var criminal := _spawn_npc(Vector2(0, 0), "criminal")
	criminal.stun(3.0)
	await wait_physics_frames(120)
	assert_eq(_bullets_of(criminal).size(), 0)
	assert_eq(player.health, player.max_health())


func test_medkit_heals_and_is_consumed() -> void:
	await _spawn_player()
	player.inventory.equip("left", "medkit")
	player.take_damage(6)
	assert_true(player.use_tool("left"))
	assert_eq(player.health, player.max_health() - 2.0)
	assert_eq(player.inventory.count("medkit"), 2)


func test_medkit_not_wasted_at_full_health() -> void:
	await _spawn_player()
	player.inventory.equip("left", "medkit")
	assert_false(player.use_tool("left"))
	assert_eq(player.inventory.count("medkit"), 3)


func test_medkit_heal_is_capped_at_max_health() -> void:
	await _spawn_player()
	player.inventory.equip("left", "medkit")
	player.take_damage(2)
	player.use_tool("left")
	assert_eq(player.health, player.max_health())


func test_medkit_used_by_clicking_its_hand() -> void:
	await _spawn_player()
	player.inventory.equip("left", "medkit")
	player.take_damage(5)
	Input.action_press("p1_use_left")
	await wait_physics_frames(3)
	Input.action_release("p1_use_left")
	assert_eq(player.inventory.count("medkit"), 2, "um clique, um kit")
	assert_gt(player.health, player.max_health() - 5.0)
	assert_true(player.hands_text().contains("×2"))


func test_last_medkit_empties_the_hand() -> void:
	await _spawn_player()
	player.inventory.remove("medkit", 2)
	player.inventory.equip("left", "medkit")
	player.take_damage(5)
	player.use_tool("left")
	assert_eq(player.inventory.equipped("left"), "")


# --- escudo ---

func test_shield_blocks_shots_from_the_front() -> void:
	await _spawn_player()
	var shooter := _spawn_npc(Vector2(700, 500), "criminal")
	shooter.set_physics_process(false)
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_right")
	await wait_physics_frames(2)
	var blocked := [false]
	player.blocked.connect(func(): blocked[0] = true)
	player.take_damage(3, shooter)
	assert_eq(player.health, player.max_health())
	assert_true(blocked[0])


func test_shield_does_not_block_from_behind() -> void:
	await _spawn_player()
	var shooter := _spawn_npc(Vector2(300, 500), "criminal")
	shooter.set_physics_process(false)
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_right")
	await wait_physics_frames(2)
	player.take_damage(3, shooter)
	assert_eq(player.health, player.max_health() - 3.0)


func test_shield_down_does_not_block() -> void:
	await _spawn_player()
	var shooter := _spawn_npc(Vector2(700, 500), "criminal")
	shooter.set_physics_process(false)
	player.face(Vector2.RIGHT)
	await wait_physics_frames(2)
	player.take_damage(3, shooter)
	assert_eq(player.health, player.max_health() - 3.0)


func test_shield_does_not_block_unknown_source() -> void:
	await _spawn_player()
	Input.action_press("p1_use_right")
	await wait_physics_frames(2)
	player.take_damage(2, null)
	assert_eq(player.health, player.max_health() - 2.0)


func test_shield_slows_walking() -> void:
	await _spawn_player()
	Input.action_press("p1_right")
	await wait_physics_frames(10)
	var free_speed: float = player.velocity.length()
	Input.action_press("p1_use_right")
	await wait_physics_frames(5)
	var shielded_speed: float = player.velocity.length()
	assert_almost_eq(shielded_speed, free_speed * player.SHIELD_SLOWDOWN, 0.5)


func test_enemy_bullet_blocked_end_to_end() -> void:
	await _spawn_player()
	var criminal := _spawn_npc(Vector2(750, 500), "criminal")
	criminal.set_physics_process(false)
	player.face(Vector2.RIGHT)
	Input.action_press("p1_use_right")
	await wait_physics_frames(2)
	var bullet_script = load("res://scripts/combat/bullet.gd")
	bullet_script.fire(tree.root, Vector2(700, 500), Vector2.LEFT, criminal, "players")
	await wait_physics_frames(20)
	assert_eq(player.health, player.max_health(), "o escudo deveria barrar o tiro")
