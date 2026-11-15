extends "res://tests/base_test.gd"

const GameStateScript := preload("res://scripts/autoload/game_state.gd")

var gs


func before_each() -> void:
	gs = GameStateScript.new()


func after_each() -> void:
	gs.free()


func test_starts_outside() -> void:
	assert_false(gs.is_inside())
	assert_false(gs.has_return)


func test_set_inside_stores_building_and_return() -> void:
	gs.set_inside(5, Vector2(100, 200))
	assert_true(gs.is_inside())
	assert_eq(gs.building_id, 5)
	assert_true(gs.has_return)


func test_building_zero_counts_as_inside() -> void:
	gs.set_inside(0, Vector2.ZERO)
	assert_true(gs.is_inside())


func test_set_outside_keeps_pending_return() -> void:
	gs.set_inside(5, Vector2(100, 200))
	gs.set_outside()
	assert_false(gs.is_inside())
	assert_true(gs.has_return)


func test_consume_return_position_clears_flag() -> void:
	gs.set_inside(5, Vector2(100, 200))
	gs.set_outside()
	assert_eq(gs.consume_return_position(), Vector2(100, 200))
	assert_false(gs.has_return)
