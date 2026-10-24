extends Node2D
## Random themed obstacle groups, with a reachable supply corridor per group.

signal pickup_collected(pickup: Area2D, kind: String)
signal hazard_contacted(hazard: Area2D, body: Node2D)
signal hazard_separated(hazard: Area2D, body: Node2D)

const PickupScript = preload("res://scripts/pickup.gd")
const HazardScript = preload("res://scripts/hazard.gd")
const Balance = preload("res://scripts/game_balance.gd")
const Geometry = preload("res://scripts/hazard_geometry.gd")

var run_clock: float = 0.0
var group_clock: float = 0.0
var next_gate_at: float = Balance.TRAINING_SECONDS
var next_coin_at: float = 0.3
var next_tank_at: float = 2.1
var route_index: int = 0
var active: bool = false
var theme_id: String = "city"
var gates_spawned: int = 0
var hazards_spawned: int = 0
var rng := RandomNumberGenerator.new()
var route_center: float = Balance.START_Y
var last_style: String = ""

func _ready() -> void:
	rng.randomize()

func reset_route() -> void:
	for child in get_children():
		# A queued physics callback from the old run must not award anything.
		child.set("enabled", false)
		remove_child(child)
		child.queue_free()
	run_clock = 0.0
	group_clock = 0.0
	next_gate_at = Balance.TRAINING_SECONDS
	next_coin_at = 0.3
	next_tank_at = 2.1
	route_index = 0
	gates_spawned = 0
	hazards_spawned = 0
	route_center = Balance.START_Y
	last_style = ""
	active = false
	# Visible starting coins teach height control before any obstacle exists.
	spawn_coin_arc(780.0, 354.0, 5)
	spawn_pickup("tank", Vector2(1320.0, 360.0))

func set_active(value: bool) -> void:
	active = value
	for entity in get_children():
		entity.set("enabled", value)

func advance(delta: float, speed: float) -> void:
	if not active:
		return
	run_clock += delta
	group_clock += delta
	for entity in get_children():
		entity.advance(delta, speed, run_clock)
	if run_clock >= next_gate_at:
		spawn_gate(1430.0)
		# One bounded group per physics step, even after a long stalled frame.
		next_gate_at = run_clock + Balance.gate_interval_at(run_clock)
		route_index += 1
	if run_clock >= next_coin_at:
		spawn_coin_arc(1390.0, safe_height_at(1500.0), 6)
		next_coin_at = run_clock + 5.6
	if run_clock >= next_tank_at:
		spawn_pickup("tank", Vector2(1425.0, safe_height_at(1425.0)))
		next_tank_at = run_clock + 6.2

func spawn_coin_arc(start_x: float, center_y: float, count: int) -> void:
	for index in range(count):
		var offset := sin(float(index) / maxf(float(count - 1), 1.0) * PI) * -36.0
		spawn_pickup("coin", Vector2(start_x + float(index) * 54.0, center_y + offset))

func spawn_pickup(pickup_kind: String, at: Vector2) -> Area2D:
	# A pickup created after its obstacle must also respect the open corridor.
	var radius := 23.0 if pickup_kind == "tank" else 17.0
	for obstacle in get_children():
		if obstacle is HazardScript and absf(obstacle.position.x - at.x) < obstacle.size.x * .5 + radius + 8.0:
			if absf(obstacle.position.y - at.y) < obstacle.size.y * .5 + radius + 8.0:
				at.y = obstacle.safe_center
	var entity := PickupScript.new()
	entity.kind = pickup_kind
	entity.theme_id = theme_id
	entity.position = at
	entity.enabled = active
	entity.collected.connect(_on_pickup_collected)
	add_child(entity)
	return entity

func spawn_gate(at_x: float) -> void:
	# Every new group can occupy a different altitude, including screen centre.
	# The lane moves at most 112px between groups, never jumping across a wall.
	route_center = rng.randf_range(maxf(230.0, route_center - 112.0), minf(544.0, route_center + 112.0))
	var count := 2 if run_clock >= 60.0 and rng.randf() < .65 else 1
	for index in range(count):
		var styles: Array = Geometry.STYLES.get(theme_id, Geometry.STYLES.city).duplicate()
		styles.erase(last_style)
		var style: String = styles[rng.randi_range(0, styles.size() - 1)]
		last_style = style
		var base_size: Vector2 = Geometry.SIZES[style]
		var hazard_size := base_size * rng.randf_range(.78, 1.0)
		var half_opening := Balance.gate_opening_at(run_clock) * .5 + 8.0
		var available_height := maxf(route_center - half_opening - 154.0, 620.0 - route_center - half_opening)
		hazard_size.y = minf(hazard_size.y, available_height - 2.0)
		var half_height := hazard_size.y * .5
		var minimum := 154.0 + half_height
		var maximum := 620.0 - half_height
		var upper_end := minf(maximum, route_center - half_opening - half_height)
		var lower_start := maxf(minimum, route_center + half_opening + half_height)
		var upper_space := maxf(0.0, upper_end - minimum)
		var lower_space := maxf(0.0, maximum - lower_start)
		var choice := rng.randf_range(0.0, upper_space + lower_space)
		var height := minimum + choice if choice < upper_space else lower_start + choice - upper_space
		var x := at_x + rng.randf_range(0.0, 64.0) + float(index) * rng.randf_range(270.0, 340.0)
		var obstacle := spawn_hazard(Vector2(x, height), hazard_size, style)
		# New obstacles can appear next to supplies already waiting off-screen.
		for pickup in get_children():
			if pickup is PickupScript and absf(pickup.position.x - x) < hazard_size.x * .5 + 32.0:
				if absf(pickup.position.y - height) < half_height + 32.0:
					pickup.position.y = obstacle.safe_center
	gates_spawned += 1

func safe_height_at(at_x: float) -> float:
	var nearest := INF
	var center := route_center
	for entity in get_children():
		if entity is HazardScript:
			var distance := absf(entity.position.x - at_x)
			if distance < nearest:
				nearest = distance
				center = entity.safe_center
	return center

func spawn_hazard(at: Vector2, hazard_size: Vector2, hazard_kind: String) -> Area2D:
	var entity := HazardScript.new()
	entity.position = at
	entity.size = hazard_size
	entity.kind = hazard_kind
	entity.theme_id = theme_id
	entity.variation = rng.randf_range(0.0, TAU)
	entity.safe_center = route_center
	entity.enabled = active
	entity.contacted.connect(_on_hazard_contacted)
	entity.separated.connect(_on_hazard_separated)
	add_child(entity)
	hazards_spawned += 1
	return entity

func _on_pickup_collected(pickup: Area2D, pickup_kind: String) -> void:
	if active:
		pickup_collected.emit(pickup, pickup_kind)

func _on_hazard_contacted(hazard: Area2D, body: Node2D) -> void:
	if active:
		hazard_contacted.emit(hazard, body)

func _on_hazard_separated(hazard: Area2D, body: Node2D) -> void:
	hazard_separated.emit(hazard, body)

