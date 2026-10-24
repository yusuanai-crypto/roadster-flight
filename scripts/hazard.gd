extends Area2D

signal contacted(hazard: Area2D, body: Node2D)
signal separated(hazard: Area2D, body: Node2D)

const Geometry = preload("res://scripts/hazard_geometry.gd")
var size := Vector2(84.0, 170.0)
var kind: String = "pillar"
var theme_id: String = "city"
var enabled: bool = false
var visual: Node2D
var variation: float = 0.0
var safe_center: float = 350.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	kind = Geometry.resolve_kind(theme_id, kind)
	for polygon in Geometry.polygons(kind, size, variation):
		var collision := CollisionPolygon2D.new()
		collision.polygon = polygon
		add_child(collision)
	visual = load("res://visuals/hazard_visual.gd").new()
	visual.set("size", size)
	visual.set("kind", kind)
	visual.set("theme_id", theme_id)
	visual.set("variation", variation)
	add_child(visual)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func advance(delta: float, speed: float, clock: float) -> void:
	position.x -= speed * delta
	if is_instance_valid(visual):
		visual.set("clock", clock)
		visual.queue_redraw()
	if position.x < -size.x - 100.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if enabled:
		contacted.emit(self, body)

func _on_body_exited(body: Node2D) -> void:
	separated.emit(self, body)

