extends "res://tests/base_test.gd"
## Mobiliário urbano e paisagismo (StreetPropsLayout).

const CityLayout := preload("res://scripts/world/city_layout.gd")
const SidewalkGraph := preload("res://scripts/world/sidewalk_graph.gd")
const StreetPropsLayout := preload("res://scripts/world/street_props_layout.gd")
const PropSprites := preload("res://scripts/art/prop_sprites.gd")

const CURB_KINDS := ["lamp", "small_tree", "bin", "hydrant", "traffic_light"]
const MID_KINDS := ["bus_stop", "newsstand"]

var city
var props


func before_each() -> void:
	city = CityLayout.new()
	props = StreetPropsLayout.new(city, city.world_seed)


func _lot_of(block: Vector2i) -> Rect2:
	return city.lots[block.x * CityLayout.CELLS + block.y]


func _count(kind: String) -> int:
	var total := 0
	for p in props.props:
		if p.kind == kind:
			total += 1
	return total


func test_same_seed_gives_the_same_props() -> void:
	var again = StreetPropsLayout.new(CityLayout.new(), city.world_seed)
	assert_eq(again.props.size(), props.props.size())
	for i in props.props.size():
		assert_eq(again.props[i].kind, props.props[i].kind)
		assert_eq(again.props[i].position, props.props[i].position)
	assert_eq(again.parks.keys(), props.parks.keys())


func test_different_seed_moves_the_props() -> void:
	var other = StreetPropsLayout.new(city, city.world_seed + 1)
	var moved := 0
	for i in mini(other.props.size(), props.props.size()):
		if other.props[i].position != props.props[i].position:
			moved += 1
	assert_gt(moved, 100.0)


func test_every_kind_has_a_sprite() -> void:
	for p in props.props:
		assert_true(PropSprites.has_sprite(p.kind), p.kind)


func test_street_has_every_kind_of_furniture() -> void:
	# um poste por lado de cada quarteirão (um lado pode ficar sem, se as portas ocuparem as vagas)
	assert_gt(_count("lamp"), city.lots.size() * 3.5)
	assert_true(_count("lamp") <= city.lots.size() * 4)
	for kind in ["traffic_light", "small_tree", "bin", "hydrant", "bus_stop", "newsstand", "manhole", "bench", "bush", "flowers"]:
		assert_gt(_count(kind), 0.0, kind)


## A calçada é estreita: nada sólido nela, e os objetos ficam junto ao meio-fio,
## fora da linha por onde os pedestres andam.
func test_nothing_solid_and_curb_props_stay_off_the_walking_line() -> void:
	var walking_line := CityLayout.SIDEWALK / 2.0
	for p in props.props:
		assert_false(p.solid, p.kind)
		if not CURB_KINDS.has(p.kind):
			continue
		var lot := _lot_of(p.block)
		var pos: Vector2 = p.position
		assert_false(lot.has_point(pos), "%s dentro do lote" % p.kind)
		assert_true(lot.grow(CityLayout.SIDEWALK).has_point(pos), "%s fora da calçada" % p.kind)
		var distance := maxf(maxf(lot.position.x - pos.x, pos.x - lot.end.x), maxf(lot.position.y - pos.y, pos.y - lot.end.y))
		assert_gt(distance, walking_line + 4.0, "%s em cima da linha de caminhada" % p.kind)


func test_bus_stops_and_newsstands_sit_on_the_sidewalk() -> void:
	for p in props.props:
		if MID_KINDS.has(p.kind):
			var lot := _lot_of(p.block)
			assert_false(lot.has_point(p.position))
			assert_true(lot.grow(CityLayout.SIDEWALK).has_point(p.position), p.kind)


func test_props_keep_clear_of_doors() -> void:
	for p in props.props:
		if not (CURB_KINDS.has(p.kind) or MID_KINDS.has(p.kind)) or p.kind == "traffic_light":
			continue
		var lot := _lot_of(p.block)
		var pos: Vector2 = p.position
		if pos.y < lot.end.y:
			continue  # só a calçada de baixo tem portas
		for b in city.buildings:
			if lot.grow(0.5).encloses(b.rect):
				assert_gt(absf((b.door as Rect2).get_center().x - pos.x), StreetPropsLayout.DOOR_CLEARANCE - 2.0,
					"%s em frente à porta do prédio %d" % [p.kind, b.id])


func test_traffic_lights_only_at_inner_intersections() -> void:
	var inner := (CityLayout.CELLS - 1) * (CityLayout.CELLS - 1)
	assert_eq(_count("traffic_light"), inner * 4, "4 semáforos por cruzamento interno")
	for p in props.props:
		if p.kind != "traffic_light":
			continue
		var node := Vector2i(roundi(p.position.x / CityLayout.BLOCK), roundi(p.position.y / CityLayout.BLOCK))
		assert_true(node.x >= 1 and node.x <= CityLayout.CELLS - 1 and node.y >= 1 and node.y <= CityLayout.CELLS - 1)


func test_manholes_are_on_the_asphalt() -> void:
	for p in props.props:
		if p.kind == "manhole":
			var from_road_center := absf(p.position.y - roundf(p.position.y / CityLayout.BLOCK) * CityLayout.BLOCK)
			assert_true(from_road_center < CityLayout.ASPHALT / 2.0 - 4.0)
			assert_eq(p.layer, "ground")


func test_layers() -> void:
	for p in props.props:
		assert_eq(p.layer, "overlay" if StreetPropsLayout.OVERLAY_KINDS.has(p.kind) else "ground", p.kind)


func test_for_block_returns_only_that_block() -> void:
	var total := 0
	for cx in CityLayout.CELLS:
		for cy in CityLayout.CELLS:
			for p in props.for_block(Vector2i(cx, cy)):
				assert_eq(p.block, Vector2i(cx, cy))
				total += 1
	assert_eq(total, props.props.size())
	assert_eq(props.for_block(Vector2i(99, 99)), [])


func test_positions_are_on_the_texel_grid() -> void:
	for p in props.props:
		assert_almost_eq(fposmod(p.position.x, 2.0), 0.0)
		assert_almost_eq(fposmod(p.position.y, 2.0), 0.0)


# --- parques e quintais ---

func test_every_park_has_paths_inside_the_lot() -> void:
	assert_eq(props.parks.size(), city.parks.size())
	for index in props.parks:
		var lot: Rect2 = city.lots[index]
		assert_true(city.parks.has(lot))
		var park: Dictionary = props.parks[index]
		assert_eq(park.paths.size(), 2)
		for path in park.paths:
			assert_true(lot.grow(0.5).encloses(path))


func test_ponds_stay_inside_the_park_away_from_paths_and_trees() -> void:
	var ponds := 0
	for seed_value in [2024, 1, 2, 3, 4]:
		var c := CityLayout.new(seed_value)
		var layout = StreetPropsLayout.new(c, seed_value)
		for index in layout.parks:
			var park: Dictionary = layout.parks[index]
			if not park.has_pond:
				continue
			ponds += 1
			var pond: Rect2 = park.pond
			assert_true((c.lots[index] as Rect2).encloses(pond))
			for path in park.paths:
				assert_false(pond.intersects(path), "lago em cima do caminho")
			for t in c.trees:
				assert_false(pond.grow(30.0).has_point(t), "árvore dentro do lago")
	assert_gt(ponds, 0.0, "nenhum lago em 5 cidades")


func test_park_decor_stays_inside_the_park() -> void:
	for p in props.props:
		if p.kind == "bench":
			assert_true(city.parks.has(_lot_of(p.block)))
			assert_true(_lot_of(p.block).has_point(p.position))


func test_yards_are_recorded_and_decorated() -> void:
	assert_gt(city.yards.size(), 10.0)
	for yard in city.yards:
		var inside_lot := false
		for lot in city.lots:
			if lot.grow(0.5).encloses(yard):
				inside_lot = true
		assert_true(inside_lot)
		assert_eq(city.building_at(yard.get_center()), -1, "quintal não fica sob prédio")
		var decor := 0
		for p in props.props:
			if (p.kind == "bush" or p.kind == "flowers") and yard.has_point(p.position):
				decor += 1
		assert_gt(decor, 0.0)
