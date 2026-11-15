extends "res://tests/base_test.gd"
## Ficha do jogador (C): nome, características, XP, níveis e atributos com efeito real.

const ProfileScript := preload("res://scripts/player/player_profile.gd")
const SheetScript := preload("res://scripts/ui/character_sheet.gd")
const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
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
	for a in ["p1_character", "p1_right", "p1_use_left", "p1_talk"]:
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


func _spawn_player(pos := Vector2(500, 500)) -> Node:
	player = PLAYER_SCENE.instantiate()
	player.global_position = pos
	tree.root.add_child(player)
	await wait_physics_frames(2)
	return player


# --- ficha (pura) ---

func test_starts_with_name_traits_and_points() -> void:
	var p = ProfileScript.new(1)
	assert_eq(p.player_name, "Dante Ramos")
	assert_eq(p.traits.size(), 2)
	assert_eq(p.level, 1)
	assert_eq(p.unspent, ProfileScript.START_POINTS)
	for s in ProfileScript.STATS:
		assert_eq(p.stat(s.id), 1)


func test_player_two_has_a_different_card() -> void:
	assert_ne(ProfileScript.new(2).player_name, ProfileScript.new(1).player_name)
	assert_ne(ProfileScript.new(2).traits, ProfileScript.new(1).traits)


func test_spend_points() -> void:
	var p = ProfileScript.new()
	assert_true(p.spend("strength"))
	assert_eq(p.stat("strength"), 2)
	assert_eq(p.unspent, ProfileScript.START_POINTS - 1)
	assert_false(p.spend("nope"))


func test_cannot_spend_without_points_or_above_max() -> void:
	var p = ProfileScript.new()
	p.unspent = 0
	assert_false(p.can_spend("speed"))
	p.unspent = 50
	for i in 20:
		p.spend("speed")
	assert_eq(p.stat("speed"), ProfileScript.MAX_STAT)
	assert_false(p.can_spend("speed"))


func test_xp_and_level_up_grant_points() -> void:
	var p = ProfileScript.new()
	assert_eq(p.xp_for_next(), 50)
	assert_eq(p.add_xp(30), 0)
	assert_eq(p.xp, 30)
	assert_eq(p.add_xp(30), 1)
	assert_eq(p.level, 2)
	assert_eq(p.xp, 10)
	assert_eq(p.unspent, ProfileScript.START_POINTS + ProfileScript.POINTS_PER_LEVEL)
	assert_eq(p.xp_for_next(), 100, "cada nível exige mais")


func test_big_xp_gain_can_skip_several_levels() -> void:
	var p = ProfileScript.new()
	assert_eq(p.add_xp(50 + 100 + 150 + 10), 3)
	assert_eq(p.level, 4)
	assert_eq(p.xp, 10)


func test_level_cap() -> void:
	var p = ProfileScript.new()
	p.add_xp(1000000)
	assert_eq(p.level, ProfileScript.MAX_LEVEL)
	assert_eq(p.add_xp(100), 0)
	assert_eq(p.level, ProfileScript.MAX_LEVEL)


func test_non_positive_xp_is_ignored() -> void:
	var p = ProfileScript.new()
	assert_eq(p.add_xp(0), 0)
	assert_eq(p.add_xp(-5), 0)
	assert_eq(p.xp, 0)


func test_every_stat_has_a_real_effect_that_grows() -> void:
	var p = ProfileScript.new()
	p.unspent = 20
	var before := {
		"speed": p.speed_multiplier(), "strength": p.damage_multiplier(),
		"vitality": p.max_health(), "intelligence": p.xp_multiplier()}
	for s in ProfileScript.STATS:
		p.spend(s.id)
		p.spend(s.id)
	assert_gt(p.speed_multiplier(), before.speed)
	assert_gt(p.damage_multiplier(), before.strength)
	assert_gt(p.max_health(), before.vitality)
	assert_gt(p.xp_multiplier(), before.intelligence)


func test_effect_formulas() -> void:
	var p = ProfileScript.new()
	assert_eq(p.speed_multiplier(), 1.0)
	assert_eq(p.damage_multiplier(), 1.0)
	assert_eq(p.max_health(), 10.0)
	assert_eq(p.xp_multiplier(), 1.0)
	p.unspent = 10
	for i in 3:
		p.spend("speed")
		p.spend("strength")
		p.spend("vitality")
	assert_almost_eq(p.speed_multiplier(), 1.18, 0.001)
	assert_almost_eq(p.damage_multiplier(), 1.6, 0.001)
	assert_almost_eq(p.max_health(), 16.0, 0.001)


func test_intelligence_reveals_traits_progressively() -> void:
	var p = ProfileScript.new()
	assert_eq(p.visible_trait_count(), 0)
	p.unspent = 10
	p.spend("intelligence")
	assert_eq(p.visible_trait_count(), 1)
	p.spend("intelligence")
	assert_eq(p.visible_trait_count(), 2)
	p.spend("intelligence")
	assert_eq(p.visible_trait_count(), 2, "limite de 2 traços")


func test_changed_signal_on_xp_and_spend() -> void:
	var p = ProfileScript.new()
	var n := [0]
	p.changed.connect(func(): n[0] += 1)
	p.spend("speed")
	p.add_xp(5)
	assert_eq(n[0], 2)


func test_effect_text_mentions_values() -> void:
	var p = ProfileScript.new()
	p.unspent = 5
	p.spend("vitality")
	assert_true(p.effect_text("vitality").contains("12"))
	assert_true(p.effect_text("strength").contains("0%"))
	assert_eq(p.effect_text("???"), "")


func test_trait_text_hides_what_player_cannot_see() -> void:
	var id := NpcIdentity.generate(3)
	var none := NpcIdentity.traits_text(id, 0)
	assert_true(none.contains("???, ???"))
	var one := NpcIdentity.traits_text(id, 1)
	assert_true(one.contains(id.traits[0]))
	assert_false(one.contains(id.traits[1]))
	var both := NpcIdentity.traits_text(id, 2)
	assert_true(both.contains(id.traits[0]) and both.contains(id.traits[1]))
	assert_false(both.contains("???"))


# --- painel ---

func test_sheet_shows_name_traits_level() -> void:
	var sheet := SheetScript.new()
	tree.root.add_child(sheet)
	extras.append(sheet)
	var p = ProfileScript.new(1)
	sheet.open(p)
	assert_true(sheet.visible)
	assert_eq(sheet.name_text(), "Dante Ramos")
	assert_true(sheet._traits.text.contains(p.traits[0]))
	assert_true(sheet.level_text().contains("Nível 1"))
	assert_true(sheet.unspent_text().contains("3"))
	sheet.close()
	assert_false(sheet.is_open())


func test_sheet_plus_button_spends_a_point_and_refreshes() -> void:
	var sheet := SheetScript.new()
	tree.root.add_child(sheet)
	extras.append(sheet)
	var p = ProfileScript.new()
	sheet.open(p)
	sheet.plus_button("strength").pressed.emit()
	assert_eq(p.stat("strength"), 2)
	assert_true(sheet.stat_text("strength").contains("2/10"))
	assert_true(sheet.unspent_text().contains("2"))


func test_sheet_disables_plus_without_points() -> void:
	var sheet := SheetScript.new()
	tree.root.add_child(sheet)
	extras.append(sheet)
	var p = ProfileScript.new()
	p.unspent = 0
	sheet.open(p)
	for s in ProfileScript.STATS:
		assert_true(sheet.plus_button(s.id).disabled, s.id)
	p.add_xp(50)  # sobe de nível: ganha pontos
	for s in ProfileScript.STATS:
		assert_false(sheet.plus_button(s.id).disabled, s.id)


func test_sheet_has_a_row_per_stat() -> void:
	var sheet := SheetScript.new()
	tree.root.add_child(sheet)
	extras.append(sheet)
	sheet.open(ProfileScript.new())
	assert_eq(sheet._rows.get_child_count(), ProfileScript.STATS.size())


# --- jogador: tecla C ---

func test_character_key_toggles_sheet_and_blocks_actions() -> void:
	await _spawn_player()
	Input.action_press("p1_character")
	await wait_physics_frames(2)
	Input.action_release("p1_character")
	assert_true(player.character_sheet.is_open())
	assert_eq(player.character_sheet.name_text(), player.profile.player_name)
	var start: Vector2 = player.global_position
	Input.action_press("p1_right")
	Input.action_press("p1_use_left")
	await wait_physics_frames(15)
	Input.action_release("p1_right")
	Input.action_release("p1_use_left")
	assert_eq(player.global_position, start)
	assert_eq(tree.get_nodes_in_group("bullets").size(), 0)
	await wait_physics_frames(2)
	Input.action_press("p1_character")
	await wait_physics_frames(2)
	Input.action_release("p1_character")
	assert_false(player.character_sheet.is_open())


func test_profile_persists_across_player_instances() -> void:
	await _spawn_player()
	player.profile.spend("speed")
	player.inventory.add("pistol")
	player.queue_free()
	await wait_frames(2)
	await _spawn_player()
	assert_eq(player.profile.stat("speed"), 2, "troca de cena não pode perder a ficha")
	assert_eq(player.inventory.count("pistol"), 2)


func test_player_two_has_separate_profile_and_inventory() -> void:
	await _spawn_player()
	var other := PLAYER_SCENE.instantiate()
	other.player_index = 2
	other.global_position = Vector2(900, 900)
	tree.root.add_child(other)
	extras.append(other)
	await wait_physics_frames(2)
	assert_ne(other.profile, player.profile)
	assert_ne(other.inventory, player.inventory)
	player.profile.spend("speed")
	assert_eq(other.profile.stat("speed"), 1)


# --- efeitos no jogo ---

func test_speed_stat_makes_the_player_faster() -> void:
	await _spawn_player()
	Input.action_press("p1_right")
	await wait_physics_frames(5)
	var base_speed: float = player.velocity.length()
	Input.action_release("p1_right")
	player.profile.unspent = 5
	for i in 4:
		player.profile.spend("speed")
	Input.action_press("p1_right")
	await wait_physics_frames(5)
	assert_gt(player.velocity.length(), base_speed * 1.2)
	assert_almost_eq(player.velocity.length(), player.speed * 1.24, 0.5)


func test_strength_stat_increases_bullet_damage() -> void:
	await _spawn_player()
	var base_bullet = player.fire_hand("left")
	assert_eq(base_bullet.damage, 1.0)
	await wait_physics_frames(20)
	player.profile.unspent = 5
	for i in 5:
		player.profile.spend("strength")
	var strong = player.fire_hand("left")
	assert_almost_eq(strong.damage, 2.0, 0.001)


func test_strength_makes_enemies_die_faster() -> void:
	await _spawn_player()
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 2
	npc.global_position = Vector2(560, 500)
	tree.root.add_child(npc)
	extras.append(npc)
	npc.set_physics_process(false)
	player.profile.unspent = 5
	for i in 5:
		player.profile.spend("strength")  # dano 2,0: dois tiros matam (vida 3)
	player.face(Vector2.RIGHT)
	player.fire_hand("left")
	await wait_physics_frames(20)
	assert_eq(npc.health, 1.0)
	player.fire_hand("left")
	await wait_physics_frames(2)
	for i in 30:
		await tree.physics_frame
	assert_true(not is_instance_valid(npc) or npc.dead)


func test_vitality_raises_max_health_and_heals_the_difference() -> void:
	await _spawn_player()
	player.take_damage(4)
	assert_eq(player.health, 6.0)
	player.profile.spend("vitality")
	assert_eq(player.max_health(), 12.0)
	assert_eq(player.health, 8.0, "ganha a vida extra na hora")
	await wait_frames(2)
	assert_eq(player.hud.health_text(), "Vida: 8/12")


func test_death_restores_to_the_raised_max_health() -> void:
	await _spawn_player()
	player.profile.spend("vitality")
	player.profile.spend("vitality")
	player.take_damage(1000)
	assert_eq(player.health, 14.0)


func test_killing_a_criminal_gives_xp_boosted_by_intelligence() -> void:
	await _spawn_player()
	var npc := NPC_SCENE.instantiate()
	npc.kind = "criminal"
	npc.global_position = Vector2(900, 900)
	tree.root.add_child(npc)
	extras.append(npc)
	npc.take_damage(5, player)
	assert_eq(player.profile.xp, 25)
	player.profile.unspent = 5
	for i in 5:
		player.profile.spend("intelligence")  # inteligência 6: +50%
	var npc2 := NPC_SCENE.instantiate()
	npc2.kind = "criminal"
	npc2.global_position = Vector2(950, 900)
	tree.root.add_child(npc2)
	extras.append(npc2)
	var xp_before: int = player.profile.xp + (player.profile.level - 1) * 0
	var level_before: int = player.profile.level
	npc2.take_damage(5, player)
	var gained: int = (player.profile.level - level_before) * 50 + player.profile.xp - xp_before
	assert_eq(gained, 38, "25 de XP base +50%")


func test_killing_innocents_gives_no_xp() -> void:
	await _spawn_player()
	var npc := NPC_SCENE.instantiate()
	npc.global_position = Vector2(900, 900)
	tree.root.add_child(npc)
	extras.append(npc)
	npc.take_damage(5, player)
	assert_eq(player.profile.xp, 0)


func test_level_up_signal_and_hud() -> void:
	await _spawn_player()
	var level := [0]
	player.leveled_up.connect(func(l): level[0] = l)
	player.gain_xp(60)
	assert_eq(level[0], 2)
	await wait_frames(2)
	assert_true(player.hud.level_text().contains("Nível 2"))


func test_first_conversation_with_each_npc_gives_xp_once() -> void:
	await _spawn_player(Vector2(0, 0))
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 5
	npc.global_position = Vector2(40, 0)
	tree.root.add_child(npc)
	extras.append(npc)
	await wait_physics_frames(3)
	assert_true(player.start_conversation(npc))
	assert_eq(player.profile.xp, 5)
	player.end_conversation()
	assert_true(player.start_conversation(npc))
	assert_eq(player.profile.xp, 5, "só a primeira conversa dá XP")


func test_conversation_card_hides_traits_until_intelligence_is_raised() -> void:
	await _spawn_player(Vector2(0, 0))
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 5
	npc.global_position = Vector2(40, 0)
	tree.root.add_child(npc)
	extras.append(npc)
	await wait_physics_frames(3)
	player.start_conversation(npc)
	assert_true(player.dialog._traits.text.contains("???"))
	player.end_conversation()
	player.profile.unspent = 5
	player.profile.spend("intelligence")
	player.profile.spend("intelligence")
	player.start_conversation(npc)
	assert_false(player.dialog._traits.text.contains("???"))
	assert_true(player.dialog._traits.text.contains(npc.identity.traits[1]))


func test_cannot_open_sheet_while_driving_or_talking() -> void:
	await _spawn_player(Vector2(0, 0))
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = 5
	npc.global_position = Vector2(40, 0)
	tree.root.add_child(npc)
	extras.append(npc)
	await wait_physics_frames(3)
	player.start_conversation(npc)
	Input.action_press("p1_character")
	await wait_physics_frames(3)
	Input.action_release("p1_character")
	assert_false(player.character_sheet.is_open(), "conversando: ficha fechada")
