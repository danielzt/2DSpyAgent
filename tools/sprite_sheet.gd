extends SceneTree
## Ferramenta de desenvolvimento: gera uma folha com os sprites e tiles da fábrica de arte,
## ampliada 4x, para conferir o visual sem abrir o jogo.
## Uso: godot --headless --path . -s tools/sprite_sheet.gd -- <arquivo.png>

const Palette := preload("res://scripts/art/palette.gd")
const PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
const PixelFont := preload("res://scripts/art/pixel_font.gd")
const CharacterSprites := preload("res://scripts/art/character_sprites.gd")
const CarSprites := preload("res://scripts/art/car_sprites.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")
const TileFactory := preload("res://scripts/art/tile_factory.gd")

const SHEET := Vector2i(400, 330)
const ZOOM := 4

var _sheet: RefCounted
var _x := 2
var _y := 2
var _row_h := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://docs/img/sprites.png"
	_sheet = PixelCanvas.new(SHEET.x, SHEET.y)
	_sheet.fill(Palette.get_color("green"))

	var looks := [CharacterSprites.agent_look(1), CharacterSprites.agent_look(2), CharacterSprites.criminal_look(3)]
	for i in 9:
		looks.append(CharacterSprites.civilian_look(100 + i))
	for look in looks:
		for d in ["down", "right", "up"]:
			_place(CharacterSprites.build(look, d, 0))
	_newline()
	for d in CharacterSprites.DIRECTIONS:
		for f in CharacterSprites.FRAMES:
			_place(CharacterSprites.build(looks[0], d, f))
	for d in ["down", "right"]:
		for f in CharacterSprites.FRAMES:
			_place(CharacterSprites.build(looks[2], d, f))
	_newline()
	for model in CarSprites.MODELS:
		_place(CarSprites.frame(model, "red", 0))
	for i in 4:
		_place(CarSprites.frame("sedan", CarSprites.TONES[i + 1], 0))
	_newline()
	for d in range(0, 32, 3):
		_place(CarSprites.frame("sedan", "blue", d))
	_newline()
	for id in PropSprites.ids():
		_place(PropSprites.canvas(id))
	_newline()
	for id in TileFactory.IDS:
		_place(TileFactory.canvas(id))
	for tone in ["blue", "teal", "pink", "yellow", "white", "purple"]:
		_place(TileFactory.canvas("wall/" + tone))
	_newline()
	_place(PixelFont.render("ARMARIA FARMÁCIA LOJA DO AGENTE", Palette.get_color("white"), Palette.get_color("ink")))
	_newline()
	_place(PixelFont.render("AÇÃO ÀS 08:30! NÍVEL 1 • XP 0/50 — $ 200", Palette.get_color("amber"), Palette.get_color("ink")))
	_newline()
	_place(PixelFont.render("ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ÁÂÃÉÊÍÓÔÕÚÇ", Palette.get_color("neon_cyan"), Palette.get_color("ink")))

	var out: RefCounted = _sheet.scaled(ZOOM)
	print("save=", out.image.save_png(path))
	quit()


func _place(canvas: RefCounted) -> void:
	if _x + canvas.width + 2 > SHEET.x:
		_newline()
	_sheet.blit(canvas, _x, _y)
	_x += canvas.width + 2
	_row_h = maxi(_row_h, canvas.height)


func _newline() -> void:
	_x = 2
	_y += _row_h + 3
	_row_h = 0
