extends "res://tests/base_test.gd"
## Transição em íris (Fase 5): geometria, tempos, estado e integração com GameState.

const TransitionScript := preload("res://scripts/autoload/transition.gd")

const SCREEN := Vector2(1280, 720)


func _covered(rects: Array[Rect2], point: Vector2) -> bool:
	for r in rects:
		if r.has_point(point):
			return true
	return false


func _area(rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += r.size.x * r.size.y
	return total


func test_open_iris_covers_nothing_and_closed_covers_everything() -> void:
	assert_eq(TransitionScript.iris_rects(SCREEN, 1.0).size(), 0)
	var closed := TransitionScript.iris_rects(SCREEN, 0.0)
	assert_eq(closed.size(), 1)
	assert_eq(closed[0], Rect2(Vector2.ZERO, SCREEN))


func test_half_closed_iris_leaves_the_center_clear_and_covers_the_corners() -> void:
	var rects := TransitionScript.iris_rects(SCREEN, 0.5)
	assert_false(_covered(rects, SCREEN / 2.0), "centro coberto")
	assert_true(_covered(rects, Vector2(2, 2)), "canto de cima")
	assert_true(_covered(rects, SCREEN - Vector2(2, 2)), "canto de baixo")
	assert_true(_covered(rects, Vector2(2, 360)), "borda esquerda")


func test_iris_covered_area_shrinks_as_it_opens() -> void:
	var last := INF
	for step in range(0, 11):
		var area := _area(TransitionScript.iris_rects(SCREEN, step / 10.0))
		assert_true(area <= last + 0.001, "a área cresceu em %d" % step)
		last = area


func test_iris_is_symmetric_and_pixel_stepped() -> void:
	var rects := TransitionScript.iris_rects(SCREEN, 0.4)
	for r in rects:
		if r.position.x == 0.0 and r.size.x < SCREEN.x:
			# o vão do centro tem largura múltipla do degrau
			var gap := SCREEN.x - r.size.x * 2.0
			assert_almost_eq(fposmod(gap, TransitionScript.STRIP * 2.0), 0.0, 0.01)
	var left := 0.0
	var right := 0.0
	for r in rects:
		if r.size.x >= SCREEN.x:
			continue  # faixa inteira: simétrica por definição
		if r.get_center().x < SCREEN.x / 2.0:
			left += r.size.x * r.size.y
		else:
			right += r.size.x * r.size.y
	assert_almost_eq(left, right, 1.0)


func test_iris_rects_never_leave_the_screen() -> void:
	for step in range(0, 11):
		for r in TransitionScript.iris_rects(SCREEN, step / 10.0):
			assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(r), "retângulo fora da tela")


func test_close_and_open_take_a_quarter_of_a_second() -> void:
	assert_eq(TransitionScript.DURATION, 0.25)
	var t := TransitionScript.new()
	tree.root.add_child(t)
	await wait_frames(2)
	assert_eq(t.ratio, 1.0)
	t.close()
	assert_true(t.busy)
	await tree.create_timer(0.1).timeout
	assert_true(t.ratio < 1.0 and t.ratio > 0.0, "a meio caminho: %f" % t.ratio)
	await tree.create_timer(0.3).timeout
	assert_eq(t.ratio, 0.0)
	t.open()
	await tree.create_timer(0.4).timeout
	assert_eq(t.ratio, 1.0)
	assert_false(t.busy)
	t.queue_free()
	await wait_frames(1)


func test_canvas_is_visible_only_while_closing() -> void:
	var t := TransitionScript.new()
	tree.root.add_child(t)
	await wait_frames(2)
	assert_false(t._canvas.visible)
	t.set_ratio(0.5)
	assert_true(t._canvas.visible)
	t.set_ratio(1.0)
	assert_false(t._canvas.visible)
	t.queue_free()
	await wait_frames(1)


func test_reset_clears_busy_and_opens_the_screen() -> void:
	var t := TransitionScript.new()
	tree.root.add_child(t)
	await wait_frames(2)
	t.close()
	await tree.create_timer(0.05).timeout
	t.reset()
	assert_false(t.busy)
	assert_eq(t.ratio, 1.0)
	t.queue_free()
	await wait_frames(1)


func test_autoload_exists_above_the_hud() -> void:
	await wait_frames(2)
	assert_true(tree.root.has_node("Transition"))
	assert_gt(float(Transition.layer), 30.0, "acima de HUD e painéis")
	assert_false(Transition.busy)


func test_game_state_ignores_door_requests_while_a_transition_runs() -> void:
	Transition.busy = true
	GameState.go_inside(5, Vector2(10, 10))
	assert_false(GameState.is_inside())
	GameState.set_inside(6, Vector2.ZERO)
	GameState.go_outside()
	assert_true(GameState.is_inside(), "go_outside também espera")
	GameState.set_outside()


func test_state_changes_only_after_the_iris_closes() -> void:
	# `before` roda com a íris fechada: aqui, com a transição desligada, roda de imediato
	var t := TransitionScript.new()
	t.enabled = false
	tree.root.add_child(t)
	var ran := [false]
	t.go("res://scenes/title/title.tscn", func() -> void: ran[0] = true)
	assert_true(ran[0], "o ajuste de estado rodou")
	await wait_frames(3)
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	t.queue_free()
	await wait_frames(3)


func test_visiting_a_building_adds_it_to_the_map() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	assert_false(profile.known_buildings.has(77))
	GameState.set_inside(77, Vector2.ZERO)
	assert_true(profile.known_buildings.has(77))
	GameState.set_outside()


func test_new_game_resets_the_run() -> void:
	var profile: RefCounted = GameState.profile_for(1)
	profile.add_money(500)
	profile.know_building(4)
	Score.points = 99
	WorldClock.set_hour(22.0)
	GameState.has_return = true
	GameState.new_game()
	assert_eq(GameState.profile_for(1).money, GameState.profile_for(1).START_MONEY)
	assert_eq(GameState.profile_for(1).known_buildings.size(), 1, "só a casa do agente")
	assert_true(GameState.profile_for(1).known_buildings.has(GameState.world_layout().home().id))
	assert_eq(Score.points, 0)
	assert_eq(WorldClock.hour(), 8.0)
	assert_false(GameState.has_return)
