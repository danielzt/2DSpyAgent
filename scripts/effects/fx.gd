extends RefCounted
## Efeitos visuais da Fase 5 (só enfeite, sem efeito no jogo): clarão e cápsula do tiro,
## faíscas e poeira de impacto, poeira de carro. Cada função recebe o nó onde o efeito
## nasce (o mundo ou o interior) e cria partículas de vida curta.
## O sorteio usa uma seed fixa: o mesmo tiro faz o mesmo desenho.

const Particle := preload("res://scripts/effects/particle.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")
const Palette := preload("res://scripts/art/palette.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const CountryLayout := preload("res://scripts/world/country_layout.gd")

## Acima dos atores (3) e do projétil (4).
const FX_Z := 5
const MUZZLE_FRAME := 1.0 / 30.0     # cada quadro do clarão dura 2 quadros do jogo
const MUZZLE_REACH := 8.0
const CASING_LIFE := 2.0
const CASING_FADE := 0.5
const SPARKS_MIN := 4
const SPARKS_MAX := 6
const SPARK_LIFE := 0.25
const SPARK_SPEED := 200.0
const GROUND_PUFFS := 3
const DUST_LIFE := 0.55
## Teto de partículas ao mesmo tempo (nunca pesa no desempenho).
const MAX_PARTICLES := 160

static var _rng := RandomNumberGenerator.new()
static var _seeded := false
static var _count := 0


static func _random() -> RandomNumberGenerator:
	if not _seeded:
		_seeded = true
		_rng.seed = 5150
	return _rng


## Zera o contador e o sorteio (usado entre testes).
static func reset() -> void:
	_count = 0
	_seeded = false


## Partículas vivas agora.
static func active_count() -> int:
	return _count


static func _spawn(parent: Node, sprite_id: String, pos: Vector2, life: float, fade := 0.0, tint := Color.WHITE) -> Sprite2D:
	if parent == null or not parent.is_inside_tree() or _count >= MAX_PARTICLES:
		return null
	var p := Particle.new()
	p.texture = SpriteFactory.fx(sprite_id)
	p.position = pos
	p.life = life
	p.fade_time = fade
	p.tint = tint
	p.z_index = FX_Z
	p.tree_exiting.connect(_on_particle_gone)
	_count += 1
	parent.add_child(p)
	return p


static func _on_particle_gone() -> void:
	_count = maxi(_count - 1, 0)


## Tiro: clarão de 2 quadros na ponta da arma (o grande, depois o menor) e cápsula que
## cai ao lado e some em 2 s.
static func shot(parent: Node, origin: Vector2, dir: Vector2, with_casing := true) -> void:
	var rng := _random()
	var tip := origin + dir * MUZZLE_REACH
	var big := _spawn(parent, "muzzle/0", tip, MUZZLE_FRAME)
	if big != null:
		big.rotation = dir.angle()
	var small := _spawn(parent, "muzzle/1", tip + dir * 4.0, MUZZLE_FRAME * 2.0)
	if small != null:
		small.rotation = dir.angle()
		small.z_index = FX_Z + 1
	if with_casing:
		var casing := _spawn(parent, "casing", origin, CASING_LIFE, CASING_FADE)
		if casing != null:
			var side := dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
			(casing as Particle).velocity = side * rng.randf_range(70.0, 110.0) + dir * rng.randf_range(-20.0, 10.0)
			(casing as Particle).drag = 260.0
			casing.rotation = rng.randf_range(0.0, TAU)


## Impacto em parede ou carro: 4 a 6 faíscas voltando contra a direção do tiro.
## Retorna quantas nasceram.
static func sparks(parent: Node, pos: Vector2, bullet_dir: Vector2) -> int:
	var rng := _random()
	var made := 0
	var count := rng.randi_range(SPARKS_MIN, SPARKS_MAX)
	for i in count:
		var life := SPARK_LIFE * rng.randf_range(0.7, 1.0)
		var p := _spawn(parent, "spark/%d" % rng.randi_range(0, 2), pos, life, SPARK_LIFE * 0.5)
		var dir := (-bullet_dir).rotated(rng.randf_range(-1.1, 1.1))
		var speed := SPARK_SPEED * rng.randf_range(0.5, 1.0)
		if p == null:
			continue
		(p as Particle).velocity = dir * speed
		(p as Particle).drag = 500.0
		made += 1
	return made


## Impacto no chão (o tiro acabou o alcance): algumas nuvens de poeira. Retorna quantas nasceram.
static func ground_hit(parent: Node, pos: Vector2) -> int:
	var rng := _random()
	var made := 0
	for i in GROUND_PUFFS:
		var jitter := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		if puff(parent, pos + jitter, Vector2.ZERO, "sand", 0.45) != null:
			made += 1
	return made


## Uma nuvem de poeira que se espalha e esmaece. `color_name`: cor da paleta que a tinge.
static func puff(parent: Node, pos: Vector2, drift: Vector2, color_name := "sand", alpha := 0.6) -> Sprite2D:
	var rng := _random()
	var c := Palette.get_color(color_name)
	var life := DUST_LIFE * rng.randf_range(0.8, 1.1)
	var p := _spawn(parent, "dust/%d" % rng.randi_range(0, 2), pos, life, DUST_LIFE * 0.8, Color(c.r, c.g, c.b, alpha))
	if p != null:
		(p as Particle).velocity = drift + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
		(p as Particle).drag = 40.0
		(p as Particle).grow = 1.4
	return p


## O ponto é terra batida (o campo fora da estrada)?
static func is_dirt(pos: Vector2) -> bool:
	if pos.x < CityLayout.city_size():
		return false
	return absf(pos.y - CountryLayout.ROAD_Y) > CountryLayout.ROAD_WIDTH / 2.0
