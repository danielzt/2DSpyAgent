extends "res://tests/base_test.gd"
## Save e opções (E2) e golpes corpo a corpo: cassetete e socos (E4).

const SaveGame := preload("res://scripts/save/save_game.gd")
const Options := preload("res://scripts/save/options.gd")
const ProfileScript := preload("res://scripts/player/player_profile.gd")
const InventoryScript := preload("res://scripts/items/inventory.gd")
const ItemDefs := preload("res://scripts/items/item_defs.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const TITLE_SCENE := preload("res://scenes/title/title.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var extras: Array = []


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	SaveGame.delete()


func after_each() -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	SaveGame.delete()
	GameState.autosave = false
	await wait_frames(2)


func _dirty_profile() -> RefCounted:
	var p = ProfileScript.new(2)
	p.money = 777
	p.level = 4
	p.xp = 12
	p.unspent = 5
	p.stats = {"speed": 3, "strength": 2, "vitality": 4, "intelligence": 1}
	p.talked = {41: true, 99: true}
	p.health = 6.5
	p.bank = 300
	p.prisoners = 2
	p.car_paint = "red"
	p.last_train_day = 3
	p.known_buildings = {7: true, 12: true}
	p.explored = {Vector2i(1, 2): true, Vector2i(3, 0): true}
	p.add_waypoint(Vector2(120.5, 800), "Casa")
	p.add_waypoint(Vector2(900, 40))
	return p


# --- ficha e inventário ---

func test_profile_roundtrips_through_json() -> void:
	var original := _dirty_profile()
	var text := JSON.stringify(original.to_dict())  # passa pelo JSON de verdade
	var copy = ProfileScript.new(1)
	copy.from_dict(JSON.parse_string(text))
	assert_eq(copy.player_name, original.player_name)
	assert_eq(copy.money, 777)
	assert_eq(copy.level, 4)
	assert_eq(copy.unspent, 5)
	assert_eq(copy.stats, original.stats)
	assert_eq(copy.talked, original.talked)
	assert_almost_eq(copy.health, 6.5)
	assert_eq(copy.bank, 300)
	assert_eq(copy.car_paint, "red")
	assert_eq(copy.known_buildings, original.known_buildings)
	assert_eq(copy.explored, original.explored)
	assert_eq(copy.waypoints, original.waypoints)
	assert_eq(copy.active_waypoint, original.active_waypoint)


func test_profile_from_dict_survives_missing_and_bad_fields() -> void:
	var p = ProfileScript.new(1)
	p.from_dict({"money": 5, "stats": {"speed": 99}, "explored": [[1]], "waypoints": [{"pos": "x"}], "active_waypoint": 9})
	assert_eq(p.money, 5)
	assert_eq(p.stat("speed"), ProfileScript.MAX_STAT, "o teto vale também ao carregar")
	assert_eq(p.explored.size(), 0)
	assert_eq(p.waypoints.size(), 0)
	assert_eq(p.active_waypoint, -1)


func test_inventory_roundtrips() -> void:
	var inv = InventoryScript.starter_kit()
	inv.remove("shotgun")
	var copy = InventoryScript.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_eq(copy.count("medkit"), 3)
	assert_eq(copy.count("shotgun"), 0)
	assert_eq(copy.equipped("left"), "pistol")
	assert_eq(copy.equipped("right"), "shield")
	assert_eq(copy.count("baton"), 1)


func test_inventory_load_drops_unknown_items_and_bad_hands() -> void:
	var inv = InventoryScript.new()
	inv.from_dict({"stacks": {"pistol": 1, "bazuca": 2, "medkit": 0}, "hands": {"left": "taser", "right": "pistol"}})
	assert_eq(inv.ids(), ["pistol"])
	assert_eq(inv.equipped("left"), "", "não segura o que não tem")
	assert_eq(inv.equipped("right"), "pistol")


# --- arquivo de save ---

func test_save_file_write_read_and_delete() -> void:
	assert_false(SaveGame.exists())
	assert_eq(SaveGame.read(), {})
	assert_true(SaveGame.write({"version": SaveGame.VERSION, "seed": 5}))
	assert_true(SaveGame.exists())
	assert_eq(int(SaveGame.read().seed), 5)
	SaveGame.delete()
	assert_false(SaveGame.exists())


func test_save_with_future_or_missing_version_is_rejected() -> void:
	assert_eq(SaveGame.migrate({"seed": 1}), {})
	assert_eq(SaveGame.migrate({"version": SaveGame.VERSION + 1}), {})
	assert_eq(SaveGame.migrate({"version": 0}), {})
	assert_eq(SaveGame.migrate({"version": "1"}), {})
	assert_eq(SaveGame.migrate({"version": float(SaveGame.VERSION)}).version, SaveGame.VERSION)


func test_corrupted_save_file_is_ignored() -> void:
	var file := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	file.store_string("{isto não é json")
	file.close()
	assert_true(SaveGame.exists())
	assert_eq(SaveGame.read(), {})
	assert_false(GameState.load_save())
	var list := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	list.store_string("[1, 2]")
	list.close()
	assert_eq(SaveGame.read(), {}, "JSON que não é um objeto")


func test_vec_helper() -> void:
	assert_eq(SaveGame.vec([3, 4.5]), Vector2(3, 4.5))
	assert_eq(SaveGame.vec(null), Vector2.ZERO)
	assert_eq(SaveGame.vec([1]), Vector2.ZERO)


# --- GameState: salvar e carregar a partida ---

func test_game_state_saves_and_loads_the_whole_run() -> void:
	GameState.new_game()
	var profile: RefCounted = GameState.profile_for(1)
	profile.money = 4242
	profile.add_xp(130)
	profile.explore(Vector2(3000, 3000))
	GameState.inventory_for(1).add("snack", 2)
	WorldClock.set_hour(15.0)
	Score.points = 350
	assert_true(GameState.save_now(Vector2(1500, 900)))
	var level: int = profile.level
	var explored: int = profile.explored.size()
	var seconds: float = WorldClock.seconds

	GameState.new_game()
	assert_eq(GameState.profile_for(1).money, ProfileScript.START_MONEY)
	assert_true(GameState.load_save())
	var loaded: RefCounted = GameState.profile_for(1)
	assert_eq(loaded.money, 4242)
	assert_eq(loaded.level, level)
	assert_eq(loaded.explored.size(), explored)
	assert_eq(GameState.inventory_for(1).count("snack"), 2)
	assert_almost_eq(WorldClock.seconds, seconds, 0.01)
	assert_eq(Score.points, 350)
	assert_true(GameState.has_return)
	assert_eq(GameState.consume_return_position(), Vector2(1500, 900))


func test_save_inside_a_building_returns_to_its_door() -> void:
	GameState.new_game()
	GameState.set_inside(3, Vector2(640, 320), "", "bar", "Bar", 240.0)
	assert_true(GameState.save_now(Vector2(9, 9)))
	GameState.set_outside()
	GameState.new_game()
	assert_true(GameState.load_save())
	assert_eq(GameState.consume_return_position(), Vector2(640, 320))


func test_save_keeps_the_world_seed() -> void:
	GameState.new_game()
	var seed_before: int = GameState.world_seed
	GameState.world_seed = 777
	assert_true(GameState.save_now(Vector2(100, 100)))
	GameState.world_seed = seed_before
	assert_true(GameState.load_save())
	assert_eq(GameState.world_seed, 777)
	GameState.world_seed = seed_before
	GameState._world_layout = null


func test_autosave_is_off_by_default_and_writes_when_on() -> void:
	GameState.new_game()
	assert_false(GameState.autosave)
	GameState.set_inside(3, Vector2(640, 320))
	GameState.set_outside()
	assert_false(SaveGame.exists(), "os testes não gravam save")
	GameState.autosave = true
	GameState.set_inside(3, Vector2(640, 320))
	assert_true(SaveGame.exists(), "entrar em um prédio grava")
	SaveGame.delete()
	GameState.set_outside()
	assert_true(SaveGame.exists(), "sair também")


# --- opções ---

func test_volume_cycles_in_steps_and_wraps_to_mute() -> void:
	assert_eq(Options.next_volume(0), 2)
	assert_eq(Options.next_volume(8), 10)
	assert_eq(Options.next_volume(10), 0)
	assert_eq(Options.volume_db(0), -80.0)
	assert_almost_eq(Options.volume_db(10), 0.0, 0.001)
	assert_true(Options.volume_db(4) < Options.volume_db(6))


func test_options_are_saved_and_loaded() -> void:
	Options.fullscreen = false
	Options.volume = 4
	Options.shake = false
	assert_true(Options.save_options())
	Options.volume = 10
	Options.shake = true
	Options.load_options()
	assert_eq(Options.volume, 4)
	assert_false(Options.shake)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Options.path))


func test_options_apply_shake_to_the_game() -> void:
	Options.shake = false
	Options.apply()
	assert_false(GameState.screen_shake)
	Options.shake = true
	Options.apply()
	assert_true(GameState.screen_shake)
	assert_eq(Options.shake_text(), "Tremor de câmera: SIM")
	assert_eq(Options.volume_text(), "Volume: %d" % Options.volume)


# --- título ---

func test_title_offers_continue_only_with_a_save() -> void:
	assert_false(TitleScreen.menu_items().has(TitleScreen.CONTINUE))
	SaveGame.write({"version": SaveGame.VERSION})
	assert_eq(TitleScreen.menu_items()[0], TitleScreen.CONTINUE)


func test_title_options_submenu_opens_and_goes_back() -> void:
	var title := TITLE_SCENE.instantiate()
	tree.root.add_child(title)
	extras.append(title)
	await wait_frames(2)
	title.menu().chosen.emit(title.menu().items.find(TitleScreen.OPTIONS))
	assert_true(title.options_open)
	assert_eq(title.menu().items, TitleScreen.option_items())
	title.menu().chosen.emit(1)  # volume
	assert_eq(Options.volume, 0, "10 volta ao mudo")
	assert_eq(title.menu().items[1], "Volume: 0")
	title.menu().chosen.emit(TitleScreen.option_items().size() - 1)
	assert_false(title.options_open)
	assert_true(title.menu().items.has(TitleScreen.NEW_GAME))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Options.path))


# --- corpo a corpo ---

func _player() -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.global_position = Vector2(500, 500)
	tree.root.add_child(player)
	extras.append(player)
	await wait_physics_frames(2)
	player.face(Vector2.RIGHT)
	return player


func _npc(pos: Vector2) -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.kind = "innocent"
	npc.ai_seed = 3
	npc.global_position = pos
	tree.root.add_child(npc)
	extras.append(npc)
	return npc


func test_baton_hurts_what_is_in_front_and_in_reach() -> void:
	var player = await _player()
	player.inventory.equip("left", "baton")
	var front := _npc(Vector2(540, 500))
	var behind := _npc(Vector2(460, 500))
	var far := _npc(Vector2(700, 500))
	assert_eq(player.melee_hand("left"), 1)
	assert_almost_eq(front.health, 2.0, 0.001, "3 de vida menos 1 de dano")
	assert_almost_eq(behind.health, 3.0, 0.001, "atrás não é atingido")
	assert_almost_eq(far.health, 3.0, 0.001, "fora do alcance")


func test_baton_has_a_cooldown() -> void:
	var player = await _player()
	player.inventory.equip("left", "baton")
	var target := _npc(Vector2(540, 500))
	assert_eq(player.melee_hand("left"), 1)
	assert_eq(player.melee_hand("left"), -1, "ainda recarregando o golpe")
	assert_almost_eq(target.health, 2.0, 0.001)


func test_empty_left_hand_punches_for_less_damage() -> void:
	var player = await _player()
	player.inventory.unequip("left")
	var target := _npc(Vector2(530, 500))
	assert_eq(player.punch(), 1)
	assert_almost_eq(target.health, 2.5, 0.001)


func test_no_punch_while_holding_something() -> void:
	var player = await _player()
	_npc(Vector2(530, 500))
	assert_eq(player.punch(), -1, "a pistola está na mão esquerda")
	assert_eq(player.melee_hand("left"), -1, "pistola não é arma de golpe")


func test_strength_makes_melee_hit_harder() -> void:
	var player = await _player()
	player.profile.stats["strength"] = 6
	player.inventory.equip("left", "baton")
	var target := _npc(Vector2(540, 500))
	player.melee_hand("left")
	assert_almost_eq(target.health, 1.0, 0.001, "+100% de dano: 1.0 vira 2.0")


func test_melee_ignores_the_dead_and_can_kill() -> void:
	var player = await _player()
	player.inventory.equip("left", "baton")
	player.profile.stats["strength"] = 10
	var target := _npc(Vector2(540, 500))
	assert_eq(player.melee_hand("left"), 1)
	player._cooldowns["left"] = 0.0
	assert_eq(player.melee_hand("left"), 1)
	assert_true(target.dead, "dois golpes de 2,8 matam quem tem 3 de vida")
	player._cooldowns["left"] = 0.0
	assert_eq(player.melee_hand("left"), 0, "não bate em quem já morreu")


func test_melee_does_nothing_while_a_panel_is_open() -> void:
	var player = await _player()
	player.inventory.equip("left", "baton")
	var target := _npc(Vector2(540, 500))
	player.toggle_inventory()
	assert_eq(player.melee_hand("left"), -1)
	assert_almost_eq(target.health, 3.0, 0.001)


func test_baton_is_in_the_kit_and_the_armory() -> void:
	assert_eq(InventoryScript.starter_kit().count("baton"), 1)
	assert_eq(ItemDefs.get_def("baton").kind, "melee")
	assert_true(preload("res://scripts/items/shop_defs.gd").stock("armory").has("baton"))
	assert_eq(ItemDefs.FISTS.kind, "melee")
