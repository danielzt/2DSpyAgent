extends "res://tests/base_test.gd"

const HudScript := preload("res://scripts/ui/hud.gd")

var hud


func before_each() -> void:
	Score.reset()
	hud = HudScript.new()
	tree.root.add_child(hud)
	await wait_frames(1)


func after_each() -> void:
	hud.queue_free()
	Score.reset()
	await wait_frames(1)


func test_prompt_hidden_when_empty() -> void:
	hud.set_prompt("")
	assert_eq(hud.prompt_text(), "")
	assert_false(hud._prompt.visible)


func test_prompt_shown_with_text() -> void:
	hud.set_prompt("Pressione E para entrar")
	assert_eq(hud.prompt_text(), "Pressione E para entrar")
	assert_true(hud._prompt.visible)


func test_prompt_is_in_bottom_left_corner() -> void:
	assert_eq(hud._prompt.anchor_left, 0.0)
	assert_eq(hud._prompt.anchor_top, 1.0)


func test_region_label() -> void:
	hud.set_region("Campo")
	assert_eq(hud.region_text(), "Campo")


func test_score_label_follows_score_changes() -> void:
	assert_eq(hud.score_text(), "Pontos: 0")
	Score.register_kill("innocent")
	assert_eq(hud.score_text(), "Pontos: -100")


func test_health_label() -> void:
	hud.set_health(7, 10)
	assert_eq(hud.health_text(), "Vida: 7/10")
	assert_eq(hud._health.anchor_left, 1.0)
	assert_eq(hud._health.anchor_top, 1.0)
