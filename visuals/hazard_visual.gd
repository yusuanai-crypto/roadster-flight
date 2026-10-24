extends Node2D
## Shared polygon silhouettes are also the exact solid physics outlines.

const Geometry = preload("res://scripts/hazard_geometry.gd")
var size := Vector2(106, 114)
var kind := "boulder"
var theme_id := "city"
var variation: float = 0.0
var clock: float = 0.0
var parts: Array[PackedVector2Array] = []

func _ready() -> void:
	parts = Geometry.polygons(kind, size, variation)

func _draw() -> void:
	var colors := _palette()
	for index in range(parts.size()):
		var fill: Color = colors[0]
		if kind == "storm_cloud" and index == 3:
			fill = Color("ffe675")
		elif kind == "crystal":
			fill = fill.lightened(float(index) * .10)
		elif kind == "satellite" and index in [1, 2]:
			fill = Color("24468b")
		elif kind == "balloon" and index == 1:
			fill = Color("7e473b")
		elif kind == "jellyfish" and index > 0:
			fill = Color("e486d4")
		var outline := parts[index].duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color("09182e"), 6.0, true)
		draw_colored_polygon(parts[index], fill)
		draw_polyline(outline, colors[1], 2.0, true)
	_draw_details(colors[1])

func _palette() -> Array[Color]:
	match theme_id:
		"desert":
			if kind == "crystal":
				return [Color("7f637e"), Color("ffd0a1")]
			return [Color("ab6744") if kind == "boulder" else Color("816037"), Color("ffd18a")]
		"sky":
			return [Color("555578") if kind == "storm_cloud" else Color("ce5a69"), Color("fff0c9")]
		"underwater":
			return [Color("b660bb") if kind == "jellyfish" else Color("de697f") if kind == "coral" else Color("3a5668"), Color("ffb5df")]
	return [Color("3a4b74"), Color("ff658e")]

func _line(points: Array, color: Color, width: float = 2.0) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * size)
	draw_polyline(scaled, color, width, true)

func _draw_details(_light: Color) -> void:
	match kind:
		"drone":
			for side: float in [-1.0, 1.0]:
				var center := Vector2(side * .34, -.22) * size
				draw_arc(center, size.x * .12, 0, TAU, 24, Color("75e8ff"), 1.5, true)
				var axis := Vector2(cos(clock * 30), sin(clock * 30) * .3) * size.x * .12
				draw_line(center - axis, center + axis, Color("e0fcff"), 2, true)
			draw_circle(Vector2(0, .01) * size, size.x * .085, Color("ff526e"))
			draw_circle(Vector2(-.02, -.02) * size, size.x * .025, Color("fff5f8"))
		"satellite":
			for side: float in [-1.0, 1.0]:
				for y: float in [-.10, .02, .14]:
					_line([Vector2(side * .24, y), Vector2(side * .44, y - .03)], Color("63c8f5"), 1)
			_line([Vector2(0, -.20), Vector2(.12, 0), Vector2(0, .20), Vector2(-.12, 0), Vector2(0, -.20)], Color("ffd47f"))
		"energy_orb":
			draw_circle(Vector2.ZERO, size.x * .27, Color("832651"))
			draw_arc(Vector2.ZERO, size.x * .26, 0, TAU, 40, Color("ff84db"), 3, true)
			_line([Vector2(.06, -.23), Vector2(-.13, .02), Vector2(.08, .02), Vector2(-.06, .23)], Color("fff2fb"), 3)
		"boulder":
			_line([Vector2(-.31, -.22), Vector2(-.03, -.34), Vector2(.29, -.12), Vector2(.13, .22), Vector2(-.20, .30)], Color("d99a62"), 3)
			_line([Vector2(-.03, -.34), Vector2(.02, -.05), Vector2(-.20, .08), Vector2(-.13, .29)], Color("714634"))
			_line([Vector2(.02, -.05), Vector2(.30, .04)], Color("714634"))
		"crystal":
			for data: Vector3 in [Vector3(-.29, .16, .30), Vector3(.01, -.02, .48), Vector3(.31, .21, .27)]:
				_line([Vector2(data.x, data.y - data.z + .04), Vector2(data.x + .05, data.y), Vector2(data.x, data.y + data.z - .04)], Color("ffe1b5"), 1.5)
		"tumbleweed":
			for index in range(7):
				var angle := float(index) * PI / 7.0 + variation
				var axis := Vector2(cos(angle), sin(angle)) * size * .39
				draw_line(-axis, axis, Color("deb772"), 1.5, true)
			for radius: float in [.16, .29, .38]:
				draw_arc(Vector2.ZERO, radius * minf(size.x, size.y), 0, TAU, 24, Color("c59a59"), 1.3, true)
		"storm_cloud":
			_line([Vector2(-.31, -.23), Vector2(-.20, -.26), Vector2(-.11, -.20)], Color("b1b9e2"))
			_line([Vector2(.10, -.27), Vector2(.23, -.29), Vector2(.30, -.22)], Color("b1b9e2"))
		"balloon":
			for x: float in [-.18, 0, .18]:
				_line([Vector2(x * .5, -.44), Vector2(x, -.14), Vector2(x * .5, .18)], Color("ffd39b"), 3)
			for side: float in [-1.0, 1.0]:
				_line([Vector2(side * .15, .18), Vector2(side * .17, .34)], Color("edc198"), 1.5)
			_line([Vector2(-.15, .39), Vector2(.15, .39)], Color("e4ad75"))
		"glider":
			_line([Vector2(-.41, .19), Vector2(.04, -.34), Vector2(.40, .19)], Color("ffe5a5"), 2.5)
			_line([Vector2(.04, -.34), Vector2(0, .33)], Color("fff4d6"), 2.5)
		"jellyfish":
			draw_arc(Vector2(0, -.08) * size, size.x * .32, PI + .25, TAU - .25, 24, Color("ffd5f4"), 2, true)
			for x: float in [-.18, .18]:
				draw_circle(Vector2(x, -.15) * size, 3, Color("fff1fc"))
		"sea_mine":
			draw_arc(Vector2.ZERO, size.x * .25, 0, TAU, 32, Color("8cabb9"), 2, true)
			draw_circle(Vector2.ZERO, size.x * .10, Color("ff637f"))
			draw_circle(Vector2(-.025, -.025) * size, size.x * .028, Color("fff4c9"))
		"coral":
			_line([Vector2(0, .42), Vector2(-.06, .01), Vector2(-.12, -.40)], Color("ffb99e"), 3)
			_line([Vector2(-.06, .01), Vector2(.27, -.20), Vector2(.29, -.35)], Color("ffb99e"), 2)
			for point: Vector2 in [Vector2(-.42, -.27), Vector2(-.12, -.40), Vector2(.29, -.35), Vector2(.41, .06)]:
				draw_circle(point * size, 3, Color("ffe5bd"))
