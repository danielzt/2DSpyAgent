extends Node2D
## Luzes de um quarteirão da cidade, na camada de luz (que não é tingida pela noite).
## Dois modos: "emissive" redesenha por cima, sem escurecer, o que brilha (janelas acesas,
## letreiros, postes e semáforos); "glow" soma brilho ao chão (poça de luz dos postes, halo
## dos letreiros, luz das vitrines). Os comandos de desenho são montados quando a hora
## muda de meia em meia hora; fora da tela o motor descarta o nó.

const BuildingStyle := preload("res://scripts/world/building_style.gd")
const BuildingDefs := preload("res://scripts/world/building_defs.gd")
const BuildingArt := preload("res://scripts/art/building_art.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const Palette := preload("res://scripts/art/palette.gd")
const SpriteFactory := preload("res://scripts/art/sprite_factory.gd")

const TEXEL := 2.0
## Poça de luz do poste (px do mundo) e intensidades.
const LAMP_POOL := 96.0
const LAMP_ALPHA := 0.55
const SIGN_HALO_ALPHA := 0.45
const SIGN_HALO_GROW := 10.0
const FRONT_LIGHT_DEPTH := 30.0
const FRONT_LIGHT_ALPHA := 0.4

var mode := "emissive"
## Prédios e objetos de cena (postes, semáforos) deste quarteirão.
var buildings: Array = []
var props: Array = []
## Hora usada no último desenho e estado do pisca-pisca (boates).
var hour := 12.0
var blink_on := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## True se algum letreiro deste quarteirão pisca.
func has_blinker() -> bool:
	for b in buildings:
		if b.get("type", "") == "club":
			return true
	return false


## Atualiza a hora e redesenha.
func refresh(p_hour: float, p_blink := true) -> void:
	hour = p_hour
	blink_on = p_blink
	visible = DayCycle.darkness(hour) > 0.0 or DayCycle.light_on("lamp", hour)
	queue_redraw()


## Uso do prédio para o horário das janelas: "home", "office" ou "" (o resto).
static func window_use(type: String) -> String:
	if BuildingDefs.is_home(type):
		return "home"
	if type == "office" or type == "newspaper" or type == "bank":
		return "office"
	return ""


static func windows_lit(b: Dictionary, p_hour: float) -> bool:
	return DayCycle.windows_on(window_use(b.get("type", "")), p_hour)


## Letreiro aceso: de noite, com o prédio aberto. O da boate pisca.
static func sign_lit(b: Dictionary, p_hour: float, p_blink := true) -> bool:
	var type: String = b.get("type", "")
	if not DayCycle.light_on("sign", p_hour) or not BuildingDefs.is_open(type, p_hour):
		return false
	return p_blink or type != "club"


## Vitrine acesa: loja com vitrine, aberta à noite.
static func front_lit(b: Dictionary, p_hour: float) -> bool:
	var type: String = b.get("type", "")
	return BuildingDefs.def(type).get("front", false) and DayCycle.light_on("sign", p_hour) and BuildingDefs.is_open(type, p_hour)


func _draw() -> void:
	if mode == "glow":
		_draw_glow()
	else:
		_draw_emissive()


func _draw_emissive() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(TEXEL, TEXEL))
	for b in buildings:
		var style := BuildingStyle.for_building(b)
		var origin: Vector2 = (b.rect as Rect2).position / TEXEL
		if windows_lit(b, hour):
			var windows := SpriteFactory.custom("light/windows/%s" % BuildingStyle.cache_key(b, style),
				func() -> RefCounted: return BuildingArt.window_lights(b, style))
			draw_texture(windows, origin + Vector2(0.0, BuildingArt.facade_top(b, style)))
		if sign_lit(b, hour, blink_on):
			var placement := BuildingArt.sign_placement(b, style)
			if not placement.is_empty():
				var sign := SpriteFactory.custom("light/sign/%s" % BuildingStyle.cache_key(b, style),
					func() -> RefCounted: return BuildingArt.sign_canvas(b, style))
				draw_texture(sign, origin + Vector2((placement.rect as Rect2i).position))
	if DayCycle.light_on("lamp", hour):
		for prop in props:
			if prop.kind == "lamp" or prop.kind == "traffic_light":
				var texture := SpriteFactory.prop(prop.kind)
				var size := Vector2(texture.get_size())
				draw_texture(texture, ((prop.position as Vector2) / TEXEL - Vector2(size.x / 2.0, size.y)).round())


func _draw_glow() -> void:
	var glow := SpriteFactory.custom("light/glow", func() -> RefCounted: return glow_canvas())
	if DayCycle.light_on("lamp", hour):
		var lamp := _tint("orange", LAMP_ALPHA)
		for prop in props:
			if prop.kind == "lamp":
				var p: Vector2 = prop.position
				draw_texture_rect(glow, Rect2(p - Vector2(LAMP_POOL, LAMP_POOL) / 2.0, Vector2(LAMP_POOL, LAMP_POOL)), false, lamp)
	for b in buildings:
		var rect: Rect2 = b.rect
		if front_lit(b, hour):
			draw_texture_rect(glow, Rect2(rect.position.x, rect.end.y - 6.0, rect.size.x, FRONT_LIGHT_DEPTH + 6.0), false,
				_tint("cream", FRONT_LIGHT_ALPHA))
		if sign_lit(b, hour, blink_on):
			var style := BuildingStyle.for_building(b)
			var placement := BuildingArt.sign_placement(b, style)
			if not placement.is_empty():
				var r := Rect2(Vector2((placement.rect as Rect2i).position) * TEXEL, Vector2((placement.rect as Rect2i).size) * TEXEL)
				r.position += rect.position
				draw_texture_rect(glow, r.grow(SIGN_HALO_GROW), false, _tint(style.sign_fg, SIGN_HALO_ALPHA))


static func _tint(color_name: String, alpha: float) -> Color:
	var c := Palette.get_color(color_name)
	return Color(c.r, c.g, c.b, alpha)


## Brilho suave em degraus (pixel art): anéis brancos cada vez mais opacos para o centro.
## A cor vem do tom aplicado ao desenhar.
static func glow_canvas() -> RefCounted:
	var PixelCanvas := preload("res://scripts/art/pixel_canvas.gd")
	var size := 32
	var canvas: RefCounted = PixelCanvas.new(size, size)
	var steps := [0.12, 0.26, 0.45, 0.7, 1.0]
	for i in steps.size():
		var inset := i * 3
		canvas.ellipse(inset, inset, size - inset * 2, size - inset * 2, Color(1, 1, 1, steps[i]))
	return canvas
