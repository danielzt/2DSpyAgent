extends Node
## Relógio do mundo (autoload). Só acumula o tempo e avisa quando a hora ou a fase mudam;
## toda regra que depende da hora fica em DayCycle (lógica pura).
## Vive entre trocas de cena. Determinístico: o estado inteiro é `seconds`; no multiplayer
## o anfitrião envia esse valor.

const DayCycle := preload("res://scripts/world/day_cycle.gd")

signal hour_changed(hour: int)
signal phase_changed(phase: String)

## Segundos desde 00:00 do primeiro dia.
var seconds := DayCycle.START_HOUR * DayCycle.DAY_SECONDS / 24.0
var paused := false
## Velocidade do relógio (1 = normal).
var time_scale := 1.0

var _last_hour := -1
var _last_phase := ""


func _ready() -> void:
	_last_hour = int(hour())
	_last_phase = phase()


func _process(delta: float) -> void:
	if not paused:
		advance_seconds(delta * time_scale)


func hour() -> float:
	return DayCycle.hour_of(seconds)


func day() -> int:
	return DayCycle.day_of(seconds)


func phase() -> String:
	return DayCycle.phase_of(hour())


func is_night() -> bool:
	return DayCycle.is_night(hour())


func text() -> String:
	return DayCycle.clock_text(hour())


func ambient_color() -> Color:
	return DayCycle.ambient_color(hour())


func advance_seconds(amount: float) -> void:
	if amount <= 0.0:
		return
	seconds += amount
	_notify()


func advance_hours(hours: float) -> void:
	advance_seconds(hours * DayCycle.seconds_per_hour())


## Avança até a próxima vez em que o relógio marcar `target` (sempre para a frente).
func advance_to(target: float) -> void:
	var wait := DayCycle.hours_until(hour(), target)
	advance_hours(wait if wait > 0.0001 else 24.0)


## Põe o relógio em uma hora do dia atual (ferramentas e testes).
func set_hour(value: float) -> void:
	seconds = day() * DayCycle.DAY_SECONDS + fposmod(value, 24.0) * DayCycle.seconds_per_hour()
	_notify()


## Volta ao início do primeiro dia (novo jogo / testes).
func reset() -> void:
	seconds = DayCycle.START_HOUR * DayCycle.seconds_per_hour()
	paused = false
	time_scale = 1.0
	_last_hour = int(hour())
	_last_phase = phase()


func _notify() -> void:
	var current_hour := int(hour())
	if current_hour != _last_hour:
		_last_hour = current_hour
		hour_changed.emit(current_hour)
	var current_phase := phase()
	if current_phase != _last_phase:
		_last_phase = current_phase
		phase_changed.emit(current_phase)
