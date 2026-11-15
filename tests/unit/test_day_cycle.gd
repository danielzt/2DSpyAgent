extends "res://tests/base_test.gd"
## Relógio do mundo e ciclo de dia e noite: avanço, fases, horários, cor ambiente com piso
## de luminosidade e as horas em que cada luz acende e apaga.

const DayCycle := preload("res://scripts/world/day_cycle.gd")
const WorldClockScript := preload("res://scripts/autoload/world_clock.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")

var clock
var hours: Array = []
var phases: Array = []


func before_each() -> void:
	clock = WorldClockScript.new()
	hours.clear()
	phases.clear()


func after_each() -> void:
	clock.free()


# --- avanço (V7) ---

func test_day_lasts_24_real_minutes_and_starts_at_eight() -> void:
	assert_almost_eq(DayCycle.DAY_SECONDS, 12.0 * 60.0)
	assert_almost_eq(DayCycle.seconds_per_hour(), 30.0)
	assert_almost_eq(clock.hour(), DayCycle.START_HOUR)
	assert_eq(clock.day(), 0)
	assert_eq(clock.text(), "08:00")


func test_hour_and_day_from_seconds() -> void:
	assert_almost_eq(DayCycle.hour_of(0.0), 0.0)
	assert_almost_eq(DayCycle.hour_of(360.0), 12.0)
	assert_almost_eq(DayCycle.hour_of(720.0 + 45.0), 1.5)
	assert_eq(DayCycle.day_of(719.0), 0)
	assert_eq(DayCycle.day_of(720.0), 1)
	assert_eq(DayCycle.day_of(720.0 * 3.5), 3)


func test_clock_advances_with_time() -> void:
	clock.advance_seconds(15.0)
	assert_almost_eq(clock.hour(), 8.5)
	assert_eq(clock.text(), "08:30")
	clock._process(30.0)
	assert_almost_eq(clock.hour(), 9.5)
	clock.paused = true
	clock._process(600.0)
	assert_almost_eq(clock.hour(), 9.5, 0.001, "pausado não anda")
	clock.paused = false
	clock.time_scale = 2.0
	clock._process(15.0)
	assert_almost_eq(clock.hour(), 10.5)
	clock.advance_seconds(-50.0)
	assert_almost_eq(clock.hour(), 10.5, 0.001, "o relógio não volta")


func test_clock_rolls_over_midnight() -> void:
	clock.advance_hours(17.0)
	assert_almost_eq(clock.hour(), 1.0, 0.001)
	assert_eq(clock.day(), 1)


func test_advance_to_always_goes_forward() -> void:
	clock.set_hour(22.0)
	clock.advance_to(7.0)
	assert_almost_eq(clock.hour(), 7.0, 0.001)
	assert_eq(clock.day(), 1)
	clock.advance_to(13.0)
	assert_almost_eq(clock.hour(), 13.0, 0.001)
	assert_eq(clock.day(), 1, "mais tarde no mesmo dia")
	clock.advance_to(13.0)
	assert_eq(clock.day(), 2, "a mesma hora é só amanhã")
	assert_almost_eq(DayCycle.hours_until(22.0, 7.0), 9.0)
	assert_almost_eq(DayCycle.hours_until(7.0, 22.0), 15.0)


func test_set_hour_keeps_the_day_and_reset_goes_back_to_the_start() -> void:
	clock.advance_hours(30.0)
	clock.set_hour(3.25)
	assert_eq(clock.day(), 1)
	assert_eq(clock.text(), "03:15")
	clock.paused = true
	clock.reset()
	assert_almost_eq(clock.hour(), DayCycle.START_HOUR)
	assert_eq(clock.day(), 0)
	assert_false(clock.paused)


func test_clock_text() -> void:
	assert_eq(DayCycle.clock_text(0.0), "00:00")
	assert_eq(DayCycle.clock_text(9.5), "09:30")
	assert_eq(DayCycle.clock_text(23.99), "23:59")
	assert_eq(DayCycle.clock_text(24.0), "00:00")
	assert_eq(DayCycle.clock_text(18.0 + 5.0 / 60.0), "18:05")


func test_signals_fire_when_hour_and_phase_change() -> void:
	clock._ready()
	clock.hour_changed.connect(func(h: int): hours.append(h))
	clock.phase_changed.connect(func(p: String): phases.append(p))
	clock.advance_seconds(15.0)
	assert_eq(hours, [])
	clock.advance_seconds(20.0)
	assert_eq(hours, [9])
	clock.set_hour(18.0)
	assert_eq(phases, ["entardecer"])
	clock.set_hour(20.0)
	clock.set_hour(20.5)
	assert_eq(phases, ["entardecer", "noite"])
	assert_eq(hours, [9, 18, 20])


func test_world_clock_autoload_exists_and_is_reset_between_tests() -> void:
	assert_true(tree.root.has_node("WorldClock"))
	assert_true(WorldClock.hour() >= DayCycle.START_HOUR and WorldClock.hour() < DayCycle.START_HOUR + 1.0)
	assert_eq(WorldClock.day(), 0)
	assert_eq(WorldClock.phase(), "dia")
	assert_false(WorldClock.is_night())
	assert_eq(WorldClock.ambient_color(), Color.WHITE)


# --- fases ---

func test_phases_of_the_day() -> void:
	var expected := {0.0: "madrugada", 4.9: "madrugada", 5.0: "amanhecer", 7.9: "amanhecer", 8.0: "dia",
		16.9: "dia", 17.0: "entardecer", 19.4: "entardecer", 19.5: "noite", 23.9: "noite", 24.0: "madrugada"}
	for hour in expected:
		assert_eq(DayCycle.phase_of(hour), expected[hour], "às %s" % str(hour))
		assert_true(DayCycle.PHASES.has(DayCycle.phase_of(hour)))


func test_night_goes_from_dusk_end_to_dawn() -> void:
	for hour in [19.5, 22.0, 0.0, 3.0, 4.99]:
		assert_true(DayCycle.is_night(hour), str(hour))
	for hour in [5.0, 8.0, 12.0, 17.0, 19.4]:
		assert_false(DayCycle.is_night(hour), str(hour))


func test_in_range_handles_midnight() -> void:
	assert_true(DayCycle.in_range(10.0, 9.0, 17.0))
	assert_false(DayCycle.in_range(17.0, 9.0, 17.0))
	assert_true(DayCycle.in_range(23.0, 21.0, 5.0))
	assert_true(DayCycle.in_range(2.0, 21.0, 5.0))
	assert_false(DayCycle.in_range(5.0, 21.0, 5.0))
	assert_false(DayCycle.in_range(12.0, 21.0, 5.0))
	assert_true(DayCycle.in_range(26.0, 1.0, 3.0), "hora acima de 24 dá a volta")


# --- horários de funcionamento (V8) ---

func test_opening_hours_follow_the_clock() -> void:
	var open_at := {"bank": [9.0, 12.0, 16.5], "bar": [17.0, 23.0, 1.0, 2.9], "club": [21.0, 0.0, 4.5], "cinema": [13.0, 23.5]}
	var closed_at := {"bank": [8.9, 17.0, 22.0, 3.0], "bar": [3.0, 9.0, 16.9], "club": [5.0, 12.0, 20.9], "cinema": [0.5, 12.9]}
	for type in open_at:
		for hour in open_at[type]:
			assert_true(BuildingDefs.is_open(type, hour), "%s às %s" % [type, str(hour)])
		for hour in closed_at[type]:
			assert_false(BuildingDefs.is_open(type, hour), "%s às %s" % [type, str(hour)])
	for type in ["police", "hospital", "hotel", "hq", "house", "apartment", "gas_station"]:
		for hour in [0.0, 4.0, 12.0, 20.0]:
			assert_true(BuildingDefs.is_open(type, hour), type)


func test_opening_text() -> void:
	assert_eq(BuildingDefs.opening_hour("bank"), 9)
	assert_eq(BuildingDefs.opening_hour("bar"), 17)
	assert_eq(BuildingDefs.closed_text("bank"), "Fechado — abre às 09:00")
	assert_true(BuildingDefs.always_open("police"))
	assert_false(BuildingDefs.always_open("bank"))


# --- cor ambiente (V9) ---

func test_ambient_is_white_by_day() -> void:
	for hour in [8.0, 10.0, 12.0, 16.9, 17.0]:
		assert_eq(DayCycle.ambient_color(hour), Color.WHITE, str(hour))
		assert_almost_eq(DayCycle.darkness(hour), 0.0, 0.001)


func test_ambient_never_goes_below_the_luminance_floor() -> void:
	# percorre o dia inteiro, minuto a minuto
	var darkest := 1.0
	for minute in 24 * 60:
		var hour := minute / 60.0
		var color := DayCycle.ambient_color(hour)
		var lum := DayCycle.luminance(color)
		darkest = minf(darkest, lum)
		if lum < DayCycle.MIN_LUMINANCE or color.r < DayCycle.MIN_CHANNEL or color.g < DayCycle.MIN_CHANNEL or color.b < DayCycle.MIN_CHANNEL:
			assert_true(false, "escuro demais às %s: %s" % [DayCycle.clock_text(hour), str(color)])
			return
	assert_true(darkest < 0.6, "a noite precisa escurecer de verdade (mínimo %.2f)" % darkest)
	assert_true(darkest >= DayCycle.MIN_LUMINANCE)


func test_night_is_blue_and_dusk_is_warm() -> void:
	var night := DayCycle.ambient_color(23.0)
	assert_gt(night.b, night.r + 0.2, "noite azul/roxa, nunca cinza")
	assert_gt(night.b, night.g + 0.2)
	var dusk := DayCycle.ambient_color(18.5)
	assert_gt(dusk.r, dusk.b + 0.2, "entardecer alaranjado")
	var dawn := DayCycle.ambient_color(6.25)
	assert_gt(dawn.r, dawn.g, "amanhecer rosado")
	assert_gt(dawn.b, dawn.g)


func test_ambient_changes_smoothly() -> void:
	var previous := DayCycle.ambient_color(0.0)
	for minute in range(1, 24 * 60 + 1):
		var color := DayCycle.ambient_color(minute / 60.0)
		var step := absf(color.r - previous.r) + absf(color.g - previous.g) + absf(color.b - previous.b)
		assert_true(step < 0.03, "salto de cor às %s" % DayCycle.clock_text(minute / 60.0))
		previous = color


func test_darkness_peaks_at_night() -> void:
	assert_almost_eq(DayCycle.darkness(23.0), 1.0, 0.001)
	assert_almost_eq(DayCycle.darkness(2.0), 1.0, 0.001)
	assert_true(DayCycle.darkness(18.5) > 0.2 and DayCycle.darkness(18.5) < 0.8)
	assert_gt(DayCycle.darkness(19.5), DayCycle.darkness(18.5))


# --- luzes (V10) ---

func test_lights_turn_on_and_off_at_the_table_hours() -> void:
	for kind in ["lamp", "headlight"]:
		assert_false(DayCycle.light_on(kind, 17.9), kind)
		assert_true(DayCycle.light_on(kind, 18.0), kind)
		assert_true(DayCycle.light_on(kind, 0.0), kind)
		assert_true(DayCycle.light_on(kind, 6.4), kind)
		assert_false(DayCycle.light_on(kind, 6.5), kind)
		assert_false(DayCycle.light_on(kind, 12.0), kind)
	assert_false(DayCycle.light_on("player", 19.4))
	assert_true(DayCycle.light_on("player", 19.5))
	assert_true(DayCycle.light_on("player", 5.9))
	assert_false(DayCycle.light_on("player", 6.0))
	assert_true(DayCycle.light_on("sign", 20.0))
	assert_false(DayCycle.light_on("sign", 10.0))
	assert_false(DayCycle.light_on("lareira", 22.0), "tipo de luz desconhecido fica apagado")


func test_windows_depend_on_the_use_of_the_building() -> void:
	for use in ["", "home", "office"]:
		assert_false(DayCycle.windows_on(use, 12.0), use)
		assert_true(DayCycle.windows_on(use, 19.0), use)
	# moradias dormem; escritórios fecham às 20:00; o resto fica aceso a noite toda
	assert_true(DayCycle.windows_on("home", 22.9))
	assert_false(DayCycle.windows_on("home", 23.0))
	assert_false(DayCycle.windows_on("home", 3.0))
	assert_true(DayCycle.windows_on("office", 19.9))
	assert_false(DayCycle.windows_on("office", 20.0))
	assert_true(DayCycle.windows_on("", 3.0))
	assert_false(DayCycle.windows_on("", 6.0))


# --- efeito no mundo ---

func test_fewer_pedestrians_and_cars_at_night() -> void:
	assert_eq(DayCycle.city_pedestrians(12.0), 110)
	assert_eq(DayCycle.city_pedestrians(19.0), 110)
	assert_eq(DayCycle.city_pedestrians(20.0), 60)
	assert_eq(DayCycle.city_pedestrians(22.9), 60)
	assert_eq(DayCycle.city_pedestrians(23.0), 25)
	assert_eq(DayCycle.city_pedestrians(3.0), 25)
	assert_eq(DayCycle.city_pedestrians(6.0), 110)
	assert_eq(DayCycle.traffic_cars(12.0), 10)
	assert_eq(DayCycle.traffic_cars(22.0), 6)


func test_city_crimes_are_more_frequent_at_night() -> void:
	assert_almost_eq(DayCycle.crime_interval_factor(12.0, "Cidade"), 1.0)
	assert_almost_eq(25.0 * DayCycle.crime_interval_factor(22.0, "Cidade"), 16.0, 0.01)
	assert_almost_eq(DayCycle.crime_interval_factor(22.0, "Campo"), 1.0)
