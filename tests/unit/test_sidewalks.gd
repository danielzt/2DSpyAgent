extends "res://tests/base_test.gd"
## Grafo de calçadas e pedestres que andam por elas.

const SidewalkGraph := preload("res://scripts/world/sidewalk_graph.gd")
const CityLayout := preload("res://scripts/world/city_layout.gd")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var extras: Array = []


func after_each() -> void:
	for n in extras:
		if is_instance_valid(n):
			n.queue_free()
	extras.clear()
	await wait_frames(2)


func _walker(from: Vector4i, to: Vector4i, seed_value := 4) -> Node:
	var npc := NPC_SCENE.instantiate()
	npc.ai_seed = seed_value
	npc.position = SidewalkGraph.position(from)
	npc.start_on_sidewalk(from, to)
	tree.root.add_child(npc)
	extras.append(npc)
	return npc


# --- grafo (puro) ---

func test_sidewalk_is_centered_between_asphalt_and_lot() -> void:
	assert_almost_eq(SidewalkGraph.half(), CityLayout.ASPHALT / 2.0 + CityLayout.SIDEWALK / 2.0)
	assert_almost_eq(CityLayout.ROAD / 2.0 - SidewalkGraph.half(), CityLayout.SIDEWALK / 2.0)


func test_node_validity() -> void:
	assert_true(SidewalkGraph.is_valid(Vector4i(1, 1, 1, -1)))
	assert_false(SidewalkGraph.is_valid(Vector4i(0, 3, 1, 1)))
	assert_false(SidewalkGraph.is_valid(Vector4i(3, CityLayout.CELLS, 1, 1)))
	assert_false(SidewalkGraph.is_valid(Vector4i(3, 3, 0, 1)))


func test_node_positions_are_corners_around_the_intersection() -> void:
	var center := Vector2(3, 4) * CityLayout.BLOCK
	var h := SidewalkGraph.half()
	assert_eq(SidewalkGraph.position(Vector4i(3, 4, 1, 1)), center + Vector2(h, h))
	assert_eq(SidewalkGraph.position(Vector4i(3, 4, -1, 1)), center + Vector2(-h, h))
	assert_eq(SidewalkGraph.position(Vector4i(3, 4, 1, -1)), center + Vector2(h, -h))


func test_every_node_has_four_neighbors_inside() -> void:
	var n := Vector4i(5, 5, 1, 1)
	assert_eq(SidewalkGraph.neighbors(n).size(), 4)
	assert_eq(SidewalkGraph.along_neighbors(n).size(), 2)
	assert_eq(SidewalkGraph.cross_neighbors(n).size(), 2)


func test_edges_are_symmetric() -> void:
	for cx in [1, 4, 11]:
		for cy in [1, 6, 11]:
			for qx in [-1, 1]:
				for qy in [-1, 1]:
					var n := Vector4i(cx, cy, qx, qy)
					for m in SidewalkGraph.neighbors(n):
						assert_true(SidewalkGraph.neighbors(m).has(n), "%s -> %s sem volta" % [str(n), str(m)])


func test_along_edges_follow_the_sidewalk_line() -> void:
	# andar pela calçada mantém a mesma coordenada lateral (fica no mesmo lado da rua)
	for n in [Vector4i(4, 4, 1, 1), Vector4i(4, 4, -1, -1), Vector4i(6, 3, 1, -1)]:
		for m in SidewalkGraph.along_neighbors(n):
			var a := SidewalkGraph.position(n)
			var b := SidewalkGraph.position(m)
			assert_true(is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y), "aresta diagonal")
			assert_almost_eq(a.distance_to(b), CityLayout.BLOCK - SidewalkGraph.half() * 2.0, 0.01)


func test_cross_edges_cross_the_asphalt() -> void:
	for n in [Vector4i(4, 4, 1, 1), Vector4i(7, 2, -1, 1)]:
		for m in SidewalkGraph.cross_neighbors(n):
			assert_almost_eq(SidewalkGraph.position(n).distance_to(SidewalkGraph.position(m)), SidewalkGraph.half() * 2.0, 0.01)


func test_sidewalk_nodes_are_never_inside_buildings_or_lots() -> void:
	var layout := CityLayout.new()
	for cx in range(1, CityLayout.CELLS):
		for cy in range(1, CityLayout.CELLS):
			for qx in [-1, 1]:
				for qy in [-1, 1]:
					var p := SidewalkGraph.position(Vector4i(cx, cy, qx, qy))
					assert_eq(layout.building_at(p), -1)
					for lot in layout.lots:
						assert_false(lot.has_point(p), "calçada dentro de lote")


func test_next_node_never_reverses_when_there_is_another_way() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := Vector4i(5, 5, 1, 1)
	var came: Vector4i = SidewalkGraph.neighbors(n)[0]
	for i in 100:
		assert_ne(SidewalkGraph.next_node(n, came, rng), came)


func test_random_walk_stays_on_valid_nodes_and_crosses_sometimes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var node := Vector4i(6, 6, 1, 1)
	var came := SidewalkGraph.along_neighbors(node)[0]
	var crossings := 0
	for i in 1500:
		var next := SidewalkGraph.next_node(node, came, rng)
		assert_true(SidewalkGraph.is_valid(next))
		if SidewalkGraph.cross_neighbors(node).has(next):
			crossings += 1
		came = node
		node = next
	assert_gt(crossings, 100.0, "pedestres devem atravessar a rua de vez em quando")
	assert_true(crossings < 1000, "mas não o tempo todo")


func test_farthest_neighbor_runs_away() -> void:
	var n := Vector4i(5, 5, 1, 1)
	var threat := SidewalkGraph.position(n) + Vector2(-100, 0)
	var chosen := SidewalkGraph.farthest_neighbor(n, threat, Vector4i.ZERO)
	for other in SidewalkGraph.neighbors(n):
		assert_true(SidewalkGraph.position(chosen).distance_to(threat) >= SidewalkGraph.position(other).distance_to(threat) - 0.01)


func test_nearest_node() -> void:
	var near := SidewalkGraph.position(Vector4i(4, 4, 1, -1)) + Vector2(5, 5)
	assert_eq(SidewalkGraph.nearest_node(near), Vector4i(4, 4, 1, -1))
	assert_true(SidewalkGraph.is_valid(SidewalkGraph.nearest_node(Vector2(-300, 99999))))


func test_random_sidewalk_point_lies_between_its_nodes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 50:
		var s := SidewalkGraph.random_sidewalk_point(rng)
		var a := SidewalkGraph.position(s.from)
		var b := SidewalkGraph.position(s.to)
		assert_almost_eq(s.position.distance_to(Geometry2D.get_closest_point_to_segment(s.position, a, b)), 0.0, 0.01)


# --- pedestre ---

func test_pedestrian_walks_toward_the_next_node() -> void:
	var from := Vector4i(4, 4, 1, 1)
	var to: Vector4i = SidewalkGraph.along_neighbors(from)[0]
	var npc := _walker(from, to)
	var start_dist: float = npc.global_position.distance_to(SidewalkGraph.position(to))
	await wait_physics_frames(60)
	assert_true(npc.global_position.distance_to(SidewalkGraph.position(to)) < start_dist - 30.0)


func test_pedestrian_stays_on_the_sidewalk_while_walking() -> void:
	var from := Vector4i(4, 4, 1, 1)
	var to: Vector4i = SidewalkGraph.along_neighbors(from)[0]
	var npc := _walker(from, to, 6)
	var half := SidewalkGraph.half()
	for i in 600:
		await tree.physics_frame
		if i % 10 != 0:
			continue
		# distância a qualquer centro de rua: nunca no meio do asfalto, exceto nas faixas
		var p: Vector2 = npc.global_position
		var dx := absf(fposmod(p.x + CityLayout.BLOCK / 2.0, CityLayout.BLOCK) - CityLayout.BLOCK / 2.0)
		var dy := absf(fposmod(p.y + CityLayout.BLOCK / 2.0, CityLayout.BLOCK) - CityLayout.BLOCK / 2.0)
		var on_line_x := absf(dx - half) < 15.0    # sobre a calçada de uma rua vertical
		var on_line_y := absf(dy - half) < 15.0
		var crossing_x := dy < half + 15.0 and dx < half + 15.0  # dentro do cruzamento
		assert_true(on_line_x or on_line_y or crossing_x, "pedestre fora da calçada em %s" % str(p))


func test_pedestrian_keeps_choosing_new_nodes() -> void:
	var from := Vector4i(4, 4, 1, 1)
	var to: Vector4i = SidewalkGraph.along_neighbors(from)[0]
	var npc := _walker(from, to, 8)
	var targets := {}
	for i in 1500:
		await tree.physics_frame
		targets[npc.sidewalk_target()] = true
	assert_gt(targets.size(), 3.0, "pedestre deveria seguir passeando")


func test_attacked_pedestrian_flees_along_the_sidewalk() -> void:
	var from := Vector4i(4, 4, 1, 1)
	var to: Vector4i = SidewalkGraph.along_neighbors(from)[0]
	var npc := _walker(from, to, 3)
	var attacker := PLAYER_SCENE.instantiate()
	attacker.global_position = npc.global_position + Vector2(-80, 0)
	tree.root.add_child(attacker)
	extras.append(attacker)
	await wait_physics_frames(2)
	npc.take_damage(1, attacker)
	var before: float = npc.global_position.distance_to(attacker.global_position)
	await wait_physics_frames(60)
	assert_gt(npc.global_position.distance_to(attacker.global_position), before + 30.0)


func test_pedestrian_turns_back_when_blocked() -> void:
	var from := Vector4i(4, 4, 1, 1)
	var to: Vector4i = SidewalkGraph.along_neighbors(from)[0]
	var npc := _walker(from, to, 5)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 120)
	shape.shape = rs
	wall.add_child(shape)
	wall.global_position = npc.global_position + (SidewalkGraph.position(to) - npc.global_position).normalized() * 80.0
	tree.root.add_child(wall)
	extras.append(wall)
	await wait_physics_frames(240)
	assert_true(npc.sidewalk_target() != to or npc.global_position.distance_to(wall.global_position) > 30.0, "ficou preso na parede")
