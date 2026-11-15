extends "res://tests/base_test.gd"
## Testes de integração: montam as cenas reais e verificam a estrutura.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const INTERIOR_SCENE := preload("res://scenes/interior/interior.tscn")
const WorldLayout := preload("res://scripts/world/world_layout.gd")
const InteriorLayout := preload("res://scripts/interior/interior_layout.gd")
const DoorScript := preload("res://scripts/world/door.gd")


func before_each() -> void:
	GameState.building_id = -1
	GameState.has_return = false


func after_each() -> void:
	GameState.building_id = -1
	GameState.has_return = false
	Input.action_release("p1_up")
	Input.action_release("p1_interact")


## Monta a cena principal. Por padrão remove NPCs e carros de trânsito para
## que os testes de portas/regiões não dependam de personagens andando por aí.
func _start_main(keep_actors := false) -> Node:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	if not keep_actors:
		for n in tree.get_nodes_in_group("npcs") + tree.get_nodes_in_group("traffic"):
			n.queue_free()
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node) -> void:
	main.queue_free()
	await wait_frames(3)
	# Limpa cenas criadas por trocas de cena durante o teste.
	for n in tree.root.get_children():
		if n.name == "Interior" or n.name == "Main":
			n.queue_free()
	await wait_frames(2)


func test_main_scene_builds_world_and_player() -> void:
	var main := await _start_main(true)
	var players := tree.get_nodes_in_group("players")
	assert_eq(players.size(), 1)
	assert_eq(players[0].global_position, WorldLayout.spawn_point())
	var layout := WorldLayout.new()
	assert_eq(tree.get_nodes_in_group("building_doors").size(), layout.buildings().size())
	assert_eq(tree.get_nodes_in_group("vehicles").size(), layout.vehicle_spawns().size() + layout.traffic_spawns().size())
	assert_eq(tree.get_nodes_in_group("traffic").size(), layout.traffic_spawns().size())
	assert_eq(tree.get_nodes_in_group("npcs").size(), layout.npcs.size())
	await _cleanup(main)


func test_player_camera_covers_whole_world() -> void:
	var main := await _start_main()
	var cam: Camera2D = tree.get_nodes_in_group("players")[0].get_node("Camera2D")
	assert_eq(cam.limit_right, int(WorldLayout.world_size().x))
	assert_eq(cam.limit_bottom, int(WorldLayout.world_size().y))
	await _cleanup(main)


func test_region_name_follows_player() -> void:
	var main := await _start_main()
	var player = tree.get_nodes_in_group("players")[0]
	await wait_frames(2)
	assert_eq(player.region_name, "Cidade")
	assert_eq(player.hud.region_text(), "Cidade")
	player.global_position = Vector2(WorldLayout.world_size().x - 300, 300)
	await wait_frames(2)
	assert_eq(player.region_name, "Campo")
	assert_eq(player.hud.region_text(), "Campo")
	await _cleanup(main)


func test_main_scene_respawns_player_at_return_position() -> void:
	var spot: Vector2 = WorldLayout.new().city.buildings[7].exit_spawn  # ponto livre
	GameState.set_inside(7, spot)
	GameState.set_outside()
	var main := await _start_main()
	assert_eq(tree.get_nodes_in_group("players")[0].global_position, spot)
	assert_false(GameState.has_return, "retorno deve ser consumido")
	await _cleanup(main)


func test_building_doors_know_their_building() -> void:
	var main := await _start_main()
	var layout := WorldLayout.new()
	var by_id := {}
	for b in layout.buildings():
		by_id[b.id] = b
	var ids := {}
	for d in tree.get_nodes_in_group("building_doors"):
		assert_false(d.exits)
		assert_true(d.verb.begins_with("entrar"))
		assert_eq(d.shop, by_id[d.building_id].shop)
		ids[d.building_id] = true
		assert_eq(d.return_position, by_id[d.building_id].exit_spawn)
	assert_eq(ids.size(), by_id.size())
	await _cleanup(main)


func test_touching_door_shows_prompt_but_does_not_enter() -> void:
	var main := await _start_main()
	var target: Dictionary = WorldLayout.new().city.buildings[12]
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = target.exit_spawn
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	assert_false(GameState.is_inside(), "entrou sem apertar E")
	assert_true(is_instance_valid(player.interactable), "porta não detectada")
	assert_true(player.current_prompt().contains("entrar"))
	assert_true(player.current_prompt().contains("E"))
	await wait_frames(1)
	assert_eq(player.hud.prompt_text(), player.current_prompt(), "HUD deve exibir a instrução")
	await _cleanup(main)


func test_pressing_interact_at_door_enters_building() -> void:
	var main := await _start_main()
	var target: Dictionary = WorldLayout.new().city.buildings[12]
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = target.exit_spawn
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_true(GameState.is_inside(), "E deveria entrar")
	assert_eq(GameState.building_id, 12)
	assert_eq(GameState.return_position, target.exit_spawn)
	await _cleanup(main)


func test_pressing_interact_away_from_door_does_nothing() -> void:
	var main := await _start_main()
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_false(GameState.is_inside())
	await _cleanup(main)


func test_farmhouse_door_is_reachable_in_country() -> void:
	var main := await _start_main()
	var farm: Dictionary = WorldLayout.new().country.buildings[0]
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = farm.exit_spawn
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	assert_true(is_instance_valid(player.interactable))
	assert_eq(player.interactable.building_id, farm.id)
	await _cleanup(main)


func test_interior_scene_builds_room() -> void:
	GameState.set_inside(3, Vector2.ZERO)
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	await wait_frames(2)
	var players := tree.get_nodes_in_group("players")
	assert_eq(players.size(), 1)
	assert_eq(players[0].global_position, InteriorLayout.spawn_point())
	assert_eq(players[0].region_name, "Interior")
	var exits := tree.get_nodes_in_group("exit_doors")
	assert_eq(exits.size(), 1)
	assert_true(exits[0].exits)
	assert_eq(exits[0].verb, "sair")
	interior.queue_free()
	await wait_frames(2)


func test_interior_exit_requires_pressing_interact() -> void:
	GameState.set_inside(3, Vector2(100, 100))
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	await wait_physics_frames(2)
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = InteriorLayout.exit_door().get_center()
	await wait_physics_frames(3)
	assert_true(GameState.is_inside(), "saiu sem apertar E")
	assert_true(player.current_prompt().contains("sair"))
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_false(GameState.is_inside(), "E deveria sair")
	await _cleanup(interior)


func test_interior_uses_building_id_for_furniture() -> void:
	GameState.set_inside(9, Vector2.ZERO)
	var interior := INTERIOR_SCENE.instantiate()
	tree.root.add_child(interior)
	await wait_frames(2)
	assert_eq(interior.layout.furniture, InteriorLayout.new(9).furniture)
	interior.queue_free()
	await wait_frames(2)


func test_door_touch_without_interact_does_nothing() -> void:
	GameState.set_outside()
	var door := Area2D.new()
	door.set_script(DoorScript)
	door.building_id = 2
	tree.root.add_child(door)
	door._on_body_entered(Node2D.new())  # não é jogador: ignorado
	assert_false(GameState.is_inside())
	door.queue_free()
	await wait_frames(1)


# --- cidade com contexto (Fase 2) ---

func test_hud_shows_district_and_street() -> void:
	var main := await _start_main()
	var player = tree.get_nodes_in_group("players")[0]
	var layout := WorldLayout.new()
	await wait_frames(2)
	assert_eq(player.place_name, layout.place_text(player.global_position))
	assert_eq(player.hud.place_text(), player.place_name)
	assert_true(player.place_name.contains(layout.district_at(player.global_position)))
	assert_true(player.place_name.contains("×"), "o jogador nasce em um cruzamento")
	player.global_position = Vector2(WorldLayout.world_size().x - 300, 300)
	await wait_frames(2)
	assert_eq(player.hud.place_text(), "", "longe da estrada do campo não há rua")
	await _cleanup(main)


func test_door_prompt_names_the_building() -> void:
	var main := await _start_main()
	var layout := WorldLayout.new()
	for d in tree.get_nodes_in_group("building_doors"):
		var b: Dictionary = layout.building_by_id(d.building_id)
		assert_eq(d.building_name, b.name)
		assert_eq(d.building_type, b.type)
		assert_true(d.verb.contains(b.name), d.verb)
	var target: Dictionary = layout.city.buildings[12]
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = target.exit_spawn
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	assert_true(player.current_prompt().contains(target.name), player.current_prompt())
	await _cleanup(main)


func test_entering_a_building_records_its_type_and_name() -> void:
	var main := await _start_main()
	var target: Dictionary = WorldLayout.new().city.buildings[12]
	var player = tree.get_nodes_in_group("players")[0]
	player.global_position = target.exit_spawn
	Input.action_press("p1_up")
	await wait_physics_frames(30)
	Input.action_release("p1_up")
	Input.action_press("p1_interact")
	await wait_physics_frames(2)
	Input.action_release("p1_interact")
	assert_eq(GameState.building_type, target.type)
	assert_eq(GameState.building_name, target.name)
	await wait_frames(3)
	await _cleanup(main)
	GameState.set_outside()


func test_world_civilians_know_where_they_work_and_live() -> void:
	var main := await _start_main(true)
	var layout := WorldLayout.new()
	var linked := 0
	for npc in tree.get_nodes_in_group("npcs"):
		if npc.kind != "innocent":
			continue
		assert_ne(npc.identity.get("work_name", ""), "", "civil sem trabalho")
		assert_false(layout.building_by_id(npc.identity.work_id).is_empty())
		assert_false(layout.building_by_id(npc.identity.home_id).is_empty())
		linked += 1
	assert_eq(linked, WorldLayout.CITY_PEDESTRIANS + WorldLayout.COUNTRY_CIVILIANS)
	await _cleanup(main)
