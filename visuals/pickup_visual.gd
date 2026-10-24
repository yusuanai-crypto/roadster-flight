extends Node2D
## The game owns clock. Pausing the game therefore freezes all pickup animation.

var kind: String = "coin"
var clock: float = 0.0
var theme_id: String = "city"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if kind == "nitro":
		_draw_nitro()
	else:
		_draw_coin()


func _draw_coin() -> void:
	var pulse: float = 0.7 + 0.3 * sin(clock * 4.0)
	# A dark backing keeps gold recognisable against sunset sand and bright clouds.
	if theme_id == "desert" or theme_id == "sky":
		draw_circle(Vector2.ZERO, 13.8, Color("2a2633"))
	draw_circle(Vector2.ZERO, 21.0, Color(1.0, 0.66, 0.14, 0.035 * pulse))
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.66, 0.14, 0.09 * pulse))
	draw_circle(Vector2.ZERO, 12.0, Color("a86416"))
	draw_circle(Vector2(-0.8, -1.0), 10.7, Color("ffc959"))
	draw_arc(Vector2(-0.8, -1.0), 8.2, 0.0, TAU, 28, Color("ffe7a1"), 1.2, true)
	draw_arc(Vector2.ZERO, 11.4, 3.3, 5.35, 16, Color("fff5c7"), 1.3, true)
	# A bevelled lightning emblem remains readable while moving quickly.
	var emblem: PackedVector2Array = PackedVector2Array([
		Vector2(1, -7), Vector2(-5, 1), Vector2(-0.6, 1),
		Vector2(-2, 6.5), Vector2(5, -2), Vector2(0.5, -2),
	])
	draw_colored_polygon(emblem, Color("a05e11"))
	var sparkle: float = maxf(0.0, sin(clock * 3.0))
	draw_line(Vector2(10, -13), Vector2(10, -7), Color(1.0, 0.95, 0.71, sparkle), 1.2, true)
	draw_line(Vector2(7, -10), Vector2(13, -10), Color(1.0, 0.95, 0.71, sparkle), 1.2, true)


func _draw_nitro() -> void:
	var pulse: float = 0.75 + 0.25 * sin(clock * 3.0)
	var halo: Color = Color(0.0, 0.72, 1.0, 0.035 * pulse)
	if theme_id == "underwater":
		halo = Color(0.36, 0.88, 1.0, 0.055 * pulse)
	draw_circle(Vector2.ZERO, 32.0, halo)
	draw_circle(Vector2.ZERO, 24.0, Color(0.1, 0.74, 1.0, 0.07 * pulse))
	draw_line(Vector2(0, -24), Vector2(0, 20), Color("082036"), 24.0, true)
	# Reinforced high-pressure bottle with visible neck and valve.
	draw_rect(Rect2(-5, -25, 10, 5), Color("20384e"))
	draw_rect(Rect2(-4, -27, 8, 3), Color("b4e5ee"))
	draw_line(Vector2(-7, -27), Vector2(7, -27), Color("63e6fc"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -21), Vector2(5, -21), Vector2(10, -15),
		Vector2(10, 16), Vector2(7, 21), Vector2(-7, 21),
		Vector2(-10, 16), Vector2(-10, -15),
	]), Color("197dbe"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -20), Vector2(2, -20), Vector2(6, -14),
		Vector2(6, 16), Vector2(3, 20), Vector2(-5, 20),
		Vector2(-8, 15), Vector2(-8, -14),
	]), Color("9be9f6"))
	draw_rect(Rect2(-10, -11, 20, 22), Color("167ac1"))
	draw_rect(Rect2(-8, -11, 4, 22), Color("269bd7"))
	draw_line(Vector2(-9, -12), Vector2(9, -12), Color("d0faff"), 1.5, true)
	draw_line(Vector2(-9, 12), Vector2(9, 12), Color("d0faff"), 1.5, true)
	draw_line(Vector2(-6, -17), Vector2(-6, -14), Color("efffff"), 1.6, true)
	draw_line(Vector2(-6, 15), Vector2(-6, 17), Color("efffff"), 1.6, true)
	# Hand-drawn N2 avoids dependence on any font or font import.
	draw_polyline(PackedVector2Array([
		Vector2(-5.5, 5), Vector2(-5.5, -4), Vector2(0, 5), Vector2(0, -4),
	]), Color("e9fbff"), 1.5, true)
	draw_polyline(PackedVector2Array([
		Vector2(2.5, 0), Vector2(6.5, 0), Vector2(6.5, 2), Vector2(2.5, 5), Vector2(7, 5),
	]), Color("e9fbff"), 1.3, true)
	draw_arc(Vector2.ZERO, 29.0, clock * 0.7, clock * 0.7 + 0.8, 12, Color(0.3, 0.9, 1.0, 0.3), 1.0, true)
