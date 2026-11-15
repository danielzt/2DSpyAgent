extends "res://tests/base_test.gd"

const ScoreScript := preload("res://scripts/autoload/score_keeper.gd")

var score
var _last_emitted := 0


func before_each() -> void:
	score = ScoreScript.new()
	_last_emitted = 0
	score.changed.connect(func(p: int): _last_emitted = p)


func after_each() -> void:
	score.free()


func test_starts_at_zero() -> void:
	assert_eq(score.points, 0)


func test_killing_innocent_loses_points() -> void:
	var delta: int = score.register_kill("innocent")
	assert_eq(delta, -ScoreScript.INNOCENT_PENALTY)
	assert_eq(score.points, -100)


func test_killing_criminal_gains_points() -> void:
	score.register_kill("criminal")
	assert_eq(score.points, ScoreScript.CRIMINAL_REWARD)


func test_points_accumulate_and_can_go_negative() -> void:
	score.register_kill("criminal")
	score.register_kill("innocent")
	score.register_kill("innocent")
	assert_eq(score.points, 50 - 200)


func test_changed_signal_emitted_with_new_total() -> void:
	score.register_kill("innocent")
	assert_eq(_last_emitted, -100)


func test_unknown_kind_changes_nothing() -> void:
	assert_eq(score.register_kill("alien"), 0)
	assert_eq(score.points, 0)


func test_reset() -> void:
	score.register_kill("criminal")
	score.reset()
	assert_eq(score.points, 0)
	assert_eq(_last_emitted, 0)
