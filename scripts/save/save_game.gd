extends RefCounted
## Save do jogo (E2): um arquivo JSON em `user://` (funciona no navegador). Guarda só o estado
## do jogador (ficha, inventário, relógio, pontos) e a seed: o mundo é regenerado pela seed.
## O arquivo leva uma versão; `migrate` leva saves antigos até a versão atual.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"

## Caminho do arquivo. Os testes apontam para outro, para não tocar no save de verdade.
static var path := DEFAULT_PATH


## Monta o dicionário do save a partir do estado atual.
## `players`: índice -> {profile, inventory}. `position`: onde o jogador reaparece no mundo.
static func snapshot(seed_value: int, players: Dictionary, clock_seconds: float, points: int, position: Vector2) -> Dictionary:
	var list := {}
	for index in players:
		list[str(index)] = {
			"profile": players[index].profile.to_dict(),
			"inventory": players[index].inventory.to_dict(),
		}
	return {
		"version": VERSION,
		"seed": seed_value,
		"clock": clock_seconds,
		"points": points,
		"position": [position.x, position.y],
		"players": list,
	}


## Leva um save antigo até a versão atual. Retorna {} se for inválido ou de uma versão futura.
static func migrate(data: Dictionary) -> Dictionary:
	if not data.has("version") or not (data.version is int or data.version is float):
		return {}
	var version := int(data.version)
	if version < 1 or version > VERSION:
		return {}
	# Aqui entram os passos de migração: `if version < 2: ...; version = 2`.
	data["version"] = version
	return data


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


## Lê e migra o save. Retorna {} se não existir ou estiver corrompido.
static func read() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return migrate(parsed)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Vector2 a partir de [x, y] (volta Vector2.ZERO se a forma estiver errada).
static func vec(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
