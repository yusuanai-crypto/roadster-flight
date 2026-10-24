extends Area2D
## Area2D signals own pickups; collecting twice cannot duplicate resources.
## https://docs.godotengine.org/en/stable/classes/class_area2d.html#signals

signal collected(pickup: Area2D, kind: String)

var kind: String = "coin"
var theme_id: String = "city"
var consumed: bool = false
var enabled: bool = false
var visual: Node2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 23.0 if kind == "tank" else 17.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	visual = load("res://visuals/pickup_visual.gd").new()
	visual.set("kind", "nitro" if kind == "tank" else kind)
	visual.set("theme_id", theme_id)
	add_child(visual)
	body_entered.connect(_on_body_entered)

func advance(delta: float, speed: float, clock: float) -> void:
	position.x -= speed * delta
	if is_instance_valid(visual):
		visual.set("clock", clock)
		visual.queue_redraw()
	if position.x < -100.0:
		queue_free()

func try_collect(body: Node) -> bool:
	if consumed or not enabled or not body is CharacterBody2D:
		return false
	consumed = true
	visible = false
	# Area callbacks run during physics flushing, so monitoring changes defer.
	set_deferred("monitoring", false)
	collected.emit(self, kind)
	queue_free()
	return true

func _on_body_entered(body: Node2D) -> void:
	try_collect(body)

