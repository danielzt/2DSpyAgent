extends "res://tests/base_test.gd"
## Identidade dos NPCs, card de conversa e tecla F.

const NpcIdentity := preload("res://scripts/npc/npc_identity.gd")
const DialogScript := preload("res://scripts/ui/dialog_card.gd")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const InputSetupScript := preload("res://scripts/autoload/input_setup.gd")

var extras: Array = []
var player


func before_each() -> void:
	var s = InputSetupScript.new()
	s._ready()
	s.free()
	Score.reset()


func after_each() -> void:
	for a in ["p1_talk", "p1_right", "p1_use_left"]:
		Input.action_release(a)
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	player = null
	await wait_frames(2)


func _spawn_player(pos: Vector2) -> Node:
	player = PLAYER_SCENE.instantiate()
	player.global_position = pos
	tree.root.add_child(player)
	extras.append(player)
	return player


func _spawn_npc(pos: Vector2, kind := "innocent", seed_value := 7) -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.kind = kind
	npc.ai_seed = seed_value
	npc.global_position = pos
	tree.root.add_child(npc)
	extras.append(npc)
	return npc


func _press_talk() -> void:
	Input.action_press("p1_talk")
	await wait_physics_frames(2)
	Input.action_release("p1_talk")
	await wait_physics_frames(2)


# --- identidade (pura) ---

func test_identity_is_deterministic() -> void:
	assert_eq(NpcIdentity.generate(5), NpcIdentity.generate(5))
	assert_ne(NpcIdentity.generate(5).name, NpcIdentity.generate(6).name)


func test_identity_fields() -> void:
	for s in range(1, 40):
		var id := NpcIdentity.generate(s, "innocent")
		assert_true((id.name as String).contains(" "), "nome e sobrenome")
		assert_true(id.age >= 18 and id.age <= 70)
		assert_eq(id.traits.size(), 2)
		assert_ne(id.traits[0], id.traits[1])
		assert_true(NpcIdentity.JOBS.has(id.job))
		assert_true(NpcIdentity.MOODS.has(id.mood))


func test_names_vary_across_seeds() -> void:
	var names := {}
	for s in range(1, 60):
		names[NpcIdentity.generate(s).name] = true
	assert_gt(names.size(), 30.0)


func test_every_question_has_an_answer() -> void:
	var id := NpcIdentity.generate(3)
	for q in NpcIdentity.QUESTIONS:
		assert_ne(NpcIdentity.answer(id, q.id), "", q.id)
		assert_ne(NpcIdentity.answer(id, q.id), "Hum? Não entendi.")


func test_answers_reflect_the_card() -> void:
	var id := NpcIdentity.generate(11)
	assert_true(NpcIdentity.answer(id, "job").contains(id.job))
	var about := NpcIdentity.answer(id, "about")
	assert_true(about.contains(id.name))
	assert_true(about.contains(str(id.age)))
	assert_true(NpcIdentity.answer(id, "greet").contains(NpcIdentity.TRAIT_SUFFIX[id.traits[0]]))


func test_criminal_deflects_suspicion_question() -> void:
	var id := NpcIdentity.generate(4, "criminal")
	assert_eq(NpcIdentity.answer(id, "suspicious"), "Não vi nada. E eu tenho pressa.")


func test_unknown_question_gets_fallback() -> void:
	assert_eq(NpcIdentity.answer(NpcIdentity.generate(1), "xyz"), "Hum? Não entendi.")


func test_summary_and_traits_text() -> void:
	var id := NpcIdentity.generate(2)
	assert_true(NpcIdentity.summary(id).contains(id.job))
	assert_true(NpcIdentity.traits_text(id).contains(id.traits[0]))


# --- NPC ---

func test_npc_has_name_from_its_seed() -> void:
	var npc := _spawn_npc(Vector2(0, 0), "innocent", 7)
	assert_eq(npc.display_name, NpcIdentity.generate(7).name)
	assert_eq(npc.identity.kind, "innocent")


func test_name_is_not_drawn_above_the_character() -> void:
	var npc := _spawn_npc(Vector2(0, 0))
	for c in npc.get_children():
		assert_false(c is Label, "o nome não deve flutuar sobre o NPC")
		assert_false(c is Label3D)


func test_only_civilians_can_be_talked_to() -> void:
	assert_true(_spawn_npc(Vector2(0, 0), "innocent").can_talk())
	assert_false(_spawn_npc(Vector2(500, 0), "criminal").can_talk())


# --- card (UI) ---

func test_dialog_opens_with_name_and_clears_on_close() -> void:
	var dlg := DialogScript.new()
	tree.root.add_child(dlg)
	extras.append(dlg)
	var closed := [false]
	dlg.closed.connect(func(): closed[0] = true)
	var id := NpcIdentity.generate(9)
	dlg.open(id)
	assert_true(dlg.is_open())
	assert_true(dlg.visible)
	assert_eq(dlg.name_text(), id.name)
	dlg.close()
	assert_false(dlg.is_open())
	assert_false(dlg.visible)
	assert_true(closed[0])


func test_dialog_asks_questions() -> void:
	var dlg := DialogScript.new()
	tree.root.add_child(dlg)
	extras.append(dlg)
	var id := NpcIdentity.generate(9)
	dlg.open(id)
	dlg.ask("job")
	assert_eq(dlg.response_text(), NpcIdentity.answer(id, "job"))
	dlg.close()
	dlg.ask("job")
	assert_eq(dlg.response_text(), NpcIdentity.answer(id, "job"), "fechado: não muda")


func test_dialog_has_a_button_per_question() -> void:
	var dlg := DialogScript.new()
	tree.root.add_child(dlg)
	extras.append(dlg)
	assert_eq(dlg._buttons.get_child_count(), NpcIdentity.QUESTIONS.size())


func test_number_keys_ask_questions_and_escape_closes() -> void:
	var dlg := DialogScript.new()
	tree.root.add_child(dlg)
	extras.append(dlg)
	var id := NpcIdentity.generate(9)
	dlg.open(id)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	dlg._unhandled_input(key)
	assert_eq(dlg.response_text(), NpcIdentity.answer(id, "job"))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	dlg._unhandled_input(esc)
	assert_false(dlg.is_open())


# --- jogador + F ---

func test_approaching_npc_shows_name_prompt_without_starting_talk() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	assert_eq(player.talk_target, npc)
	assert_true(player.current_prompt().contains(npc.display_name))
	assert_true(player.current_prompt().contains("F"))
	assert_eq(player.talking_with, null, "só conversa ao apertar F")
	assert_false(player.dialog.is_open())


func test_walking_away_clears_prompt() -> void:
	_spawn_player(Vector2(0, 0))
	_spawn_npc(Vector2(40, 0)).set_physics_process(false)
	await wait_physics_frames(3)
	player.global_position = Vector2(600, 600)
	await wait_physics_frames(3)
	assert_eq(player.talk_target, null)
	assert_eq(player.current_prompt(), "")


func test_pressing_f_opens_card_and_freezes_both() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	await _press_talk()
	assert_eq(player.talking_with, npc)
	assert_true(player.dialog.is_open())
	assert_eq(player.dialog.name_text(), npc.display_name)
	assert_true(npc.talking)
	var npc_pos: Vector2 = npc.global_position
	var player_pos: Vector2 = player.global_position
	Input.action_press("p1_right")
	await wait_physics_frames(20)
	Input.action_release("p1_right")
	assert_eq(player.global_position, player_pos, "jogador parado durante a conversa")
	assert_eq(npc.global_position, npc_pos, "NPC parado durante a conversa")
	assert_eq(player.current_prompt(), "")


func test_cannot_shoot_while_talking() -> void:
	_spawn_player(Vector2(0, 0))
	_spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	await _press_talk()
	assert_eq(player.fire(), null)


func test_pressing_f_again_ends_conversation() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	await _press_talk()
	await _press_talk()
	assert_eq(player.talking_with, null)
	assert_false(player.dialog.is_open())
	assert_false(npc.talking)


func test_closing_card_resumes_movement() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(200, 0))
	npc.set_physics_process(false)
	player.global_position = Vector2(160, 0)
	await wait_physics_frames(3)
	await _press_talk()
	player.dialog.close()
	assert_eq(player.talking_with, null)
	assert_false(npc.talking)
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(2)
	Input.action_press("p1_right")
	await wait_physics_frames(10)
	Input.action_release("p1_right")
	assert_gt(player.global_position.x, 10.0)


func test_cannot_talk_to_criminals() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0), "criminal")
	npc.set_physics_process(false)
	await wait_physics_frames(3)
	await _press_talk()
	assert_eq(player.talking_with, null)
	assert_false(player.current_prompt().contains("falar"))


func test_attacked_npc_ends_conversation() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	await _press_talk()
	npc.take_damage(1, null)
	await wait_physics_frames(3)
	assert_eq(player.talking_with, null)
	assert_false(player.dialog.is_open())


func test_npc_removed_during_conversation_ends_it() -> void:
	_spawn_player(Vector2(0, 0))
	var npc := _spawn_npc(Vector2(40, 0))
	await wait_physics_frames(3)
	await _press_talk()
	npc.take_damage(99, null)
	await wait_physics_frames(3)
	assert_eq(player.talking_with, null)
	assert_false(player.dialog.is_open())
