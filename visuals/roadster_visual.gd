extends Node2D
## The user's silver car with its background removed. Origin is body centre.
## Texture region drawing: https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-draw-texture-rect-region
## Alpha bounds: https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-get-used-rect

const CAR_TEXTURE_PATH: String = "res://assets/vehicle/reference-car.png"
const VISIBLE_WIDTH: float = 136.0

var thrusting: bool = false
var vertical_speed: float = 0.0
var invulnerable: bool = false

var _animation_time: float = 0.0
var _car_texture: Texture2D
var _source_rect: Rect2 = Rect2()
var _car_rect: Rect2 = Rect2(-68, -20, 136, 40)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists(CAR_TEXTURE_PATH):
		_car_texture = load(CAR_TEXTURE_PATH) as Texture2D
	if _car_texture != null:
		var pixels: Image = _car_texture.get_image()
		var used: Rect2i = pixels.get_used_rect()
		_source_rect = Rect2(used)
		if used.size.x > 0 and used.size.y > 0:
			var visible_size: Vector2 = Vector2(VISIBLE_WIDTH, VISIBLE_WIDTH * float(used.size.y) / float(used.size.x))
			_car_rect = Rect2(-visible_size * 0.5, visible_size)
		else:
			_car_texture = null
	if _car_texture == null:
		push_warning("Silver car texture missing; check the asset import and export.")
	queue_redraw()


func _process(delta: float) -> void:
	_animation_time += delta
	# The visual pitches gently; the parent's physical hitbox stays upright.
	var target_tilt: float = clampf(vertical_speed / 3200.0, -0.12, 0.11)
	rotation = lerpf(rotation, target_tilt, minf(delta * 8.0, 1.0))
	modulate = Color(0.65, 0.88, 1.0, 0.7) if invulnerable and sin(_animation_time * 26.0) > 0.0 else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if thrusting:
		_draw_exhaust()
	draw_line(Vector2(-50, 22), Vector2(49, 22), Color(0.1, 0.74, 1.0, 0.06), 13.0, true)
	draw_line(Vector2(-48, 21), Vector2(48, 21), Color(0.1, 0.74, 1.0, 0.16), 4.0, true)
	if _car_texture != null:
		# Crop only at draw time. The original generated PNG remains unmodified.
		draw_texture_rect_region(_car_texture, _car_rect, _source_rect)
	else:
		_draw_silver_fallback()
	if invulnerable:
		draw_arc(Vector2.ZERO, 76.0, -0.45, 0.45, 18, Color(0.36, 0.89, 1.0, 0.45), 2.0, true)
		draw_arc(Vector2.ZERO, 74.0, 2.7, 3.6, 18, Color(0.36, 0.89, 1.0, 0.24), 1.0, true)


func _draw_silver_fallback() -> void:
	# Import failures still show a silver silhouette; the release uses the PNG.
	for wheel_x: float in [-43.0, 44.0]:
		draw_circle(Vector2(wheel_x, 10), 11.0, Color("080e16"))
		draw_arc(Vector2(wheel_x, 10), 7.0, 0, TAU, 24, Color("a5acb3"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-67, -6), Vector2(-29, -16), Vector2(2, -20), Vector2(28, -7),
		Vector2(65, 0), Vector2(67, 10), Vector2(55, 15), Vector2(53, 3),
		Vector2(35, 3), Vector2(32, 16), Vector2(-30, 14), Vector2(-33, 3),
		Vector2(-53, 3), Vector2(-55, 14), Vector2(-65, 11),
	]), Color("c4c9ce"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25, -14), Vector2(2, -17), Vector2(23, -7), Vector2(-12, -9),
	]), Color("35343b"))
	draw_line(Vector2(-60, -6), Vector2(23, -7), Color("eef2f2"), 1.0, true)
	draw_line(Vector2(-28, 14), Vector2(31, 16), Color("171c24"), 3.0, true)
	draw_line(Vector2(56, 0), Vector2(65, 2), Color("e3fbff"), 1.5, true)
	draw_line(Vector2(-65, 1), Vector2(-58, 3), Color("ff657b"), 1.5, true)


func _draw_exhaust() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_animation_time * 39.0)
	var length: float = 49.0 + pulse * 18.0
	draw_line(Vector2(-65, 7), Vector2(-75 - length * 0.6, 8), Color(0.0, 0.55, 1.0, 0.09), 25.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-65, 1), Vector2(-81, -2), Vector2(-72 - length, 8),
		Vector2(-86, 15), Vector2(-65, 13),
	]), Color(0.04, 0.35, 1.0, 0.36))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-66, 4), Vector2(-79, 2), Vector2(-68 - length * 0.79, 8),
		Vector2(-80, 12), Vector2(-66, 10),
	]), Color("168efa"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-66, 5), Vector2(-72 - length * 0.51, 8), Vector2(-66, 9),
	]), Color("cbfaff"))
	# Downward secondary jets explain the car's lift in side view.
	for nozzle_x: float in [-25.0, 25.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(nozzle_x - 4, 17), Vector2(nozzle_x + 4, 17),
			Vector2(nozzle_x + 6, 25), Vector2(nozzle_x, 43 + pulse * 9), Vector2(nozzle_x - 6, 25),
		]), Color(0.05, 0.58, 1.0, 0.35))
		draw_colored_polygon(PackedVector2Array([
			Vector2(nozzle_x - 2, 18), Vector2(nozzle_x + 2, 18), Vector2(nozzle_x, 34 + pulse * 5),
		]), Color("95efff"))
