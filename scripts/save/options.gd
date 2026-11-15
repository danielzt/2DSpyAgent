extends RefCounted
## Opções do jogo (E2): tela cheia, volume e tremor de câmera. Ficam em `user://options.cfg`,
## separadas do save da partida.

const DEFAULT_PATH := "user://options.cfg"
const MAX_VOLUME := 10
const VOLUME_STEP := 2

static var path := DEFAULT_PATH
static var fullscreen := false
## 0 a MAX_VOLUME (0 = mudo). Ainda não há áudio: o valor já vale para o bus principal.
static var volume := MAX_VOLUME
static var shake := true


static func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	volume = clampi(int(cfg.get_value("audio", "volume", MAX_VOLUME)), 0, MAX_VOLUME)
	shake = bool(cfg.get_value("comfort", "shake", true))


static func save_options() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("comfort", "shake", shake)
	return cfg.save(path) == OK


## Volume em dB para o bus principal.
static func volume_db(value: int) -> float:
	if value <= 0:
		return -80.0
	return linear_to_db(float(value) / MAX_VOLUME)


## Próximo volume ao escolher a opção no menu (sobe de 2 em 2 e volta a 0 depois do máximo).
static func next_volume(value: int) -> int:
	if value >= MAX_VOLUME:
		return 0
	return mini(value + VOLUME_STEP, MAX_VOLUME)


## Aplica ao jogo: janela, bus de áudio e o tremor (que vive no GameState).
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, volume_db(volume))
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node_or_null("GameState")
	if state != null:
		state.screen_shake = shake
	if DisplayServer.get_name() == "headless":
		return
	var window: Window = tree.root.get_window()
	var is_full: bool = window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED


static func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save_options()


static func cycle_volume() -> void:
	volume = next_volume(volume)
	apply()
	save_options()


static func toggle_shake() -> void:
	shake = not shake
	apply()
	save_options()


static func fullscreen_text() -> String:
	return "Tela cheia: %s" % ("SIM" if fullscreen else "NÃO")


static func volume_text() -> String:
	return "Volume: %d" % volume


static func shake_text() -> String:
	return "Tremor de câmera: %s" % ("SIM" if shake else "NÃO")
