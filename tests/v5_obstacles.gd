extends SceneTree
## Shipping generation, real polygon physics, and seeded distribution checks.

const Geometry = preload("res://scripts/hazard_geometry.gd")
const Director = preload("res://scripts/spawn_director.gd")
const Hazard = preload("res://scripts/hazard.gd")
const Balance = preload("res://scripts/game_balance.gd")
var assertions := 0
var failures: Array[String] = []
var director

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func clear_entities() -> void:
	for entity in director.get_children():
		director.remove_child(entity)
		entity.queue_free()

func hits(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not root.world_2d.direct_space_state.intersect_point(query).is_empty()

func check_shapes() -> void:
	for theme: String in Geometry.STYLES:
		for style: String in Geometry.STYLES[theme]:
			var obstacle := Hazard.new()
			obstacle.kind = style
			obstacle.theme_id = theme
			obstacle.size = Geometry.SIZES[style]
			obstacle.position = Vector2(900, 380)
			root.add_child(obstacle)
			await physics_frame
			await physics_frame
			var expected := Geometry.polygons(style, obstacle.size)
			var shapes_match: bool = obstacle.visual.parts == expected
			var shape_count := 0
			var valid_parts := true
			for child in obstacle.get_children():
				if child is CollisionPolygon2D:
					shapes_match = shapes_match and child.polygon == expected[shape_count]
					valid_parts = valid_parts and not Geometry2D.triangulate_polygon(child.polygon).is_empty()
					shape_count += 1
			check(shapes_match and shape_count == expected.size() and valid_parts, "%s uses valid shared painted and collidable polygons" % style)
			var triangles := Geometry2D.triangulate_polygon(expected[0])
			var sample := (expected[0][triangles[0]] + expected[0][triangles[1]] + expected[0][triangles[2]]) / 3.0
			check(hits(obstacle.position + sample), "%s solid surface is detected by the real physics server" % style)
			check(not hits(obstacle.position + obstacle.size * .49), "%s empty bounding-box corner does not cause a phantom hit" % style)
			obstacle.queue_free()
			await physics_frame

func check_distribution() -> void:
	for theme: String in Geometry.STYLES:
		var styles := {}
		var heights := {}
		var sizes := {}
		var zones := [0, 0, 0]
		var corridor_clear := true
		var in_bounds := true
		var reachable := true
		var no_repeats := true
		var groups_have_hazards := true
		var positions := []
		var samples := 0
		for seed_value in [41, 773, 2026, 9981]:
			director.reset_route()
			director.rng.seed = seed_value
			director.theme_id = theme
			clear_entities()
			var last_style := ""
			for group in range(180):
				director.run_clock = float(group) * 1.5 + 10.0
				var previous: float = director.route_center
				director.spawn_gate(1430.0)
				reachable = reachable and absf(previous - director.route_center) <= 112.01
				groups_have_hazards = groups_have_hazards and director.get_child_count() in [1, 2]
				for obstacle in director.get_children():
					styles[obstacle.kind] = true
					heights[int(obstacle.position.y / 20.0)] = true
					sizes[int(obstacle.size.x)] = true
					positions.append(obstacle.position.x)
					var zone := 0 if obstacle.position.y < 300.0 else 1 if obstacle.position.y < 480.0 else 2
					zones[zone] += 1
					samples += 1
					no_repeats = no_repeats and last_style != obstacle.kind
					last_style = obstacle.kind
					corridor_clear = corridor_clear and absf(obstacle.position.y - director.route_center) - obstacle.size.y * .5 >= Balance.gate_opening_at(director.run_clock) * .5 + 7.9
					in_bounds = in_bounds and obstacle.position.y - obstacle.size.y * .5 >= 153.9 and obstacle.position.y + obstacle.size.y * .5 <= 620.1
					in_bounds = in_bounds and obstacle.size.x <= 110.0 and obstacle.position.x >= 1430.0
				clear_entities()
				if group % 30 == 0:
					await process_frame
		check(styles.size() == 3, "%s randomly uses all three scene-specific styles" % theme)
		check(zones[0] > 0 and zones[1] > 0 and zones[2] > 0, "%s covers upper, middle, lower flight space: %s / %d hazards" % [theme, str(zones), samples])
		check(heights.size() >= 15, "%s uses continuous random heights (%d sampled height bins)" % [theme, heights.size()])
		check(sizes.size() >= 15, "%s varies obstacle sizes (%d widths)" % [theme, sizes.size()])
		check(no_repeats, "%s never repeats the same silhouette consecutively" % theme)
		check(corridor_clear and groups_have_hazards, "%s preserves an open corridor in every generated group" % theme)
		check(reachable and in_bounds, "%s keeps lane changes reachable and all hazards inside the flight region" % theme)
		check(positions.max() - positions.min() > 250.0, "%s varies horizontal spacing and staggers paired hazards" % theme)

func route_signature(seed_value: int) -> Array:
	director.reset_route()
	clear_entities()
	director.rng.seed = seed_value
	var signature := []
	for group in range(12):
		director.run_clock = 100.0
		director.spawn_gate(1430.0)
		for obstacle in director.get_children():
			signature.append([obstacle.kind, obstacle.position, obstacle.size])
		clear_entities()
	return signature

func _run() -> void:
	director = Director.new()
	root.add_child(director)
	await check_shapes()
	await check_distribution()
	check(route_signature(311) == route_signature(311), "a fixed QA seed reproduces the same random route")
	check(route_signature(311) != route_signature(312), "different random seeds produce different routes")
	clear_entities()
	director.route_center = 350.0
	var obstacle = director.spawn_hazard(Vector2(1000, 500), Vector2(100, 100), "sea_mine")
	var supply = director.spawn_pickup("tank", Vector2(1000, 500))
	check(supply.position.y == obstacle.safe_center, "a later supply is relocated out of the obstacle")
	clear_entities()
	director.run_clock = 180.0
	for y in range(180, 601, 30):
		director.spawn_pickup("tank", Vector2(1460, y))
	director.spawn_gate(1430.0)
	var supplies_clear := true
	for hazard in director.get_children():
		if hazard is Hazard:
			for pickup in director.get_children():
				if pickup.collision_layer == 2:
					supplies_clear = supplies_clear and (absf(pickup.position.x - hazard.position.x) >= hazard.size.x * .5 + 23.0 or absf(pickup.position.y - hazard.position.y) >= hazard.size.y * .5 + 23.0)
	check(supplies_clear, "new random obstacles never bury previously spawned supplies")
	for seconds: float in [0, 60, 120, 180, 600]:
		check(Balance.visible_reaction_time_at(seconds) >= 1.5, "largest silhouette leaves 1.5s visible reaction at %.0fs" % seconds)
	director.queue_free()
	await process_frame
	print("V5 OBSTACLES RESULT: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
