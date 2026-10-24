extends RefCounted
## One silhouette source for painting and physics; empty corners stay harmless.

const STYLES := {
	"city": ["drone", "satellite", "energy_orb"],
	"desert": ["boulder", "crystal", "tumbleweed"],
	"sky": ["storm_cloud", "balloon", "glider"],
	"underwater": ["jellyfish", "sea_mine", "coral"],
}
const SIZES := {
	"drone": Vector2(110, 86), "satellite": Vector2(100, 112), "energy_orb": Vector2(100, 100),
	"boulder": Vector2(106, 114), "crystal": Vector2(98, 140), "tumbleweed": Vector2(102, 102),
	"storm_cloud": Vector2(110, 124), "balloon": Vector2(96, 144), "glider": Vector2(110, 86),
	"jellyfish": Vector2(106, 138), "sea_mine": Vector2(108, 108), "coral": Vector2(106, 138),
}

static func resolve_kind(theme: String, requested: String) -> String:
	var styles: Array = STYLES.get(theme, STYLES.city)
	if requested in styles:
		return requested
	return styles[2] if requested in ["electric", "gate"] else styles[0]

static func ellipse(center: Vector2, radius: Vector2, points: int = 28) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in range(points):
		var angle := TAU * float(index) / float(points)
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return polygon

static func diamond(center: Vector2, half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -half.y), center + Vector2(half.x, 0), center + Vector2(0, half.y), center + Vector2(-half.x, 0)])

static func polygons(style: String, size: Vector2, variation: float = 0.0) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	match style:
		"drone":
			parts.append(PackedVector2Array([Vector2(-.42, -.05), Vector2(-.22, -.22), Vector2(.24, -.22), Vector2(.43, -.04), Vector2(.30, .22), Vector2(-.29, .22)]))
			for side: float in [-1.0, 1.0]:
				parts.append(ellipse(Vector2(side * .34, -.22), Vector2(.16, .12)))
				parts.append(diamond(Vector2(side * .25, .29), Vector2(.11, .18)))
		"satellite":
			parts.append(diamond(Vector2.ZERO, Vector2(.23, .34)))
			for side: float in [-1.0, 1.0]:
				parts.append(PackedVector2Array([Vector2(side * .19, -.18), Vector2(side * .50, -.30), Vector2(side * .46, .28), Vector2(side * .18, .15)]))
			parts.append(diamond(Vector2(0, -.37), Vector2(.065, .13)))
		"energy_orb", "sea_mine":
			var star := PackedVector2Array()
			for index in range(24):
				var angle := TAU * float(index) / 24.0
				var radius := .50 if index % 3 == 0 else .34
				star.append(Vector2(cos(angle), sin(angle)) * radius)
			parts.append(star)
		"boulder", "tumbleweed":
			var rock := PackedVector2Array()
			var count := 11 if style == "boulder" else 26
			for index in range(count):
				var angle := TAU * float(index) / float(count)
				var radius := .45 + .045 * sin(float(index) * 2.7 + variation)
				rock.append(Vector2(cos(angle), sin(angle)) * radius)
			parts.append(rock)
		"crystal":
			parts.append(diamond(Vector2(-.29, .16), Vector2(.19, .30)))
			parts.append(diamond(Vector2(.01, -.02), Vector2(.25, .48)))
			parts.append(diamond(Vector2(.31, .21), Vector2(.18, .27)))
		"storm_cloud":
			parts.append(ellipse(Vector2(-.27, -.19), Vector2(.23, .22)))
			parts.append(ellipse(Vector2(.02, -.24), Vector2(.29, .26)))
			parts.append(ellipse(Vector2(.29, -.16), Vector2(.21, .20)))
			parts.append(PackedVector2Array([Vector2(-.03, -.07), Vector2(.19, -.07), Vector2(.03, .18), Vector2(.16, .18), Vector2(-.17, .50), Vector2(-.06, .23), Vector2(-.19, .23)]))
		"balloon":
			parts.append(ellipse(Vector2(0, -.14), Vector2(.38, .36)))
			parts.append(PackedVector2Array([Vector2(-.20, .33), Vector2(.20, .33), Vector2(.15, .50), Vector2(-.15, .50)]))
		"glider":
			parts.append(PackedVector2Array([Vector2(-.50, .24), Vector2(-.18, -.06), Vector2(.04, -.46), Vector2(.18, -.06), Vector2(.50, .24), Vector2(.15, .13), Vector2(0, .44), Vector2(-.16, .13)]))
		"jellyfish":
			var dome := PackedVector2Array()
			for index in range(21):
				var angle := PI + PI * float(index) / 20.0
				dome.append(Vector2(cos(angle) * .49, -.06 + sin(angle) * .44))
			parts.append(dome)
			for index in range(4):
				var x := -.30 + float(index) * .20
				parts.append(PackedVector2Array([Vector2(x - .035, -.08), Vector2(x + .04, -.08), Vector2(x + .085, .20), Vector2(x + .01, .48 - float(index % 2) * .10), Vector2(x - .045, .45 - float(index % 2) * .10), Vector2(x + .01, .20)]))
		"coral":
			parts.append(PackedVector2Array([Vector2(-.09, .50), Vector2(-.16, .12), Vector2(-.32, -.02), Vector2(-.49, -.10), Vector2(-.48, -.32), Vector2(-.37, -.35), Vector2(-.34, -.17), Vector2(-.17, -.12), Vector2(-.19, -.47), Vector2(-.05, -.50), Vector2(.02, -.12), Vector2(.20, -.22), Vector2(.23, -.42), Vector2(.36, -.40), Vector2(.35, -.14), Vector2(.13, .07), Vector2(.30, .08), Vector2(.38, -.03), Vector2(.49, .02), Vector2(.38, .23), Vector2(.09, .27), Vector2(.10, .50)]))
		_:
			parts.append(diamond(Vector2.ZERO, Vector2(.48, .48)))
	for part_index in range(parts.size()):
		var scaled := parts[part_index]
		for point_index in range(scaled.size()):
			scaled[point_index] *= size
		parts[part_index] = scaled
	return parts
