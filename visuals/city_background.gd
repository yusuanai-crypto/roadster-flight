extends Node2D
## Four deterministic environments. travel and clock belong to the game.
## All drawing uses CanvasItem primitives; no downloaded art or font dependency.

var travel: float = 0.0
var clock: float = 0.0
var theme_id: String = "city"

const WORLD_WIDTH: float = 1280.0
const SKYLINE_SPAN: float = 1680.0
const RUNWAY_Y: float = 660.0

class SkylineBuilding:
	var x: float = 0.0
	var width: float = 0.0
	var height: float = 0.0
	var pattern: int = 0
	var neon: bool = false
	var spire: bool = false

var _far: Array[SkylineBuilding] = []
var _middle: Array[SkylineBuilding] = []
var _near: Array[SkylineBuilding] = []


func _ready() -> void:
	_far = _make_skyline(73, 34.0, 91.0, 100.0, 320.0)
	_middle = _make_skyline(197, 46.0, 104.0, 80.0, 290.0)
	_near = _make_skyline(435, 70.0, 143.0, 40.0, 155.0)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _make_skyline(seed_value: int, width_min: float, width_max: float, height_min: float, height_max: float) -> Array[SkylineBuilding]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var buildings: Array[SkylineBuilding] = []
	var next_x: float = 0.0
	while next_x < SKYLINE_SPAN:
		var building: SkylineBuilding = SkylineBuilding.new()
		building.x = next_x
		building.width = minf(rng.randf_range(width_min, width_max), SKYLINE_SPAN - next_x)
		building.height = rng.randf_range(height_min, height_max)
		building.pattern = rng.randi_range(1, 199)
		building.neon = rng.randf() > 0.58
		building.spire = rng.randf() > 0.82
		buildings.append(building)
		next_x += building.width + rng.randf_range(7.0, 20.0)
	return buildings


func _draw() -> void:
	match theme_id:
		"desert":
			_draw_desert()
		"sky":
			_draw_sky_world()
		"underwater":
			_draw_underwater()
		_:
			_draw_city()
	# Every biome has a quiet, dark header, independent of its palette.
	for band: int in range(8):
		draw_rect(Rect2(0, float(band) * 14.0, WORLD_WIDTH, 14), Color(0.018, 0.035, 0.08, 0.6 * (1.0 - float(band) / 8.0)))


func _draw_city() -> void:
	_draw_sky()
	_draw_skyline(_far, 0.07, 626.0, Color("111d3c"), Color("243754"), 0.28, false)
	# Atmospheric strips separate layers without placing opaque fog over gameplay.
	draw_rect(Rect2(0, 535, WORLD_WIDTH, 125), Color(0.17, 0.08, 0.29, 0.15))
	_draw_skyline(_middle, 0.19, 655.0, Color("14233a"), Color("356276"), 0.45, true)
	_draw_skyline(_near, 0.39, 675.0, Color("111b2f"), Color("255465"), 0.36, true)
	_draw_runway()


func _draw_sky() -> void:
	var top_color: Color = Color("070e20")
	var horizon_color: Color = Color("251a43")
	for band: int in range(48):
		var t: float = float(band) / 47.0
		draw_rect(Rect2(0, float(band) * 15.0, WORLD_WIDTH, 16.0), top_color.lerp(horizon_color, t))
	# Keep the HUD band above y=90 deliberately quiet.
	for star_index: int in range(74):
		var star_x: float = fposmod(float(star_index * 197 + 53), 1277.0)
		var star_y: float = 112.0 + fposmod(float(star_index * 127 + 29), 349.0)
		var twinkle: float = 0.24 + 0.12 * sin(clock * 0.7 + float(star_index) * 1.91)
		var star_size: float = 1.1 if star_index % 6 == 0 else 0.6
		draw_circle(Vector2(star_x, star_y), star_size, Color(0.58, 0.8, 1.0, twinkle))
	var moon: Vector2 = Vector2(1060.0, 178.0)
	for halo_index: int in range(5, 0, -1):
		draw_circle(moon, 28.0 + float(halo_index) * 10.0, Color(0.3, 0.63, 0.9, 0.007))
	draw_circle(moon, 28.0, Color("6d8ca9"))
	draw_circle(moon + Vector2(-8, -4), 27.0, Color("15233c"))
	# Thin, distant air traffic remains decorative and faint.
	for craft_index: int in range(3):
		var craft_x: float = fposmod(480.0 * float(craft_index) - travel * 0.025, 1400.0) - 60.0
		var craft_y: float = 246.0 + float(craft_index) * 57.0
		draw_line(Vector2(craft_x - 23, craft_y), Vector2(craft_x, craft_y), Color(0.23, 0.61, 0.86, 0.09), 1.0, true)
		draw_line(Vector2(craft_x - 3, craft_y), Vector2(craft_x + 2, craft_y), Color(0.5, 0.8, 0.95, 0.32), 1.0, true)


func _draw_skyline(buildings: Array[SkylineBuilding], parallax: float, baseline: float, fill: Color, light: Color, brightness: float, detailed: bool) -> void:
	var offset: float = fposmod(travel * parallax, SKYLINE_SPAN)
	for repeat_index: int in range(-1, 2):
		for building: SkylineBuilding in buildings:
			var x: float = building.x - offset + float(repeat_index) * SKYLINE_SPAN
			if x + building.width < -25.0 or x > WORLD_WIDTH + 25.0:
				continue
			var y: float = baseline - building.height
			var width: float = building.width
			draw_rect(Rect2(x, y, width, building.height), fill)
			draw_line(Vector2(x, y), Vector2(x + width, y), Color(light, brightness * 0.5), 1.0)
			if building.spire:
				draw_rect(Rect2(x + width * 0.3, y - 13.0, width * 0.4, 13.0), fill)
				draw_line(Vector2(x + width * 0.5, y - 13.0), Vector2(x + width * 0.5, y - 33.0), Color(light, brightness * 0.6), 1.0)
				draw_circle(Vector2(x + width * 0.5, y - 33.0), 1.2, Color(0.87, 0.25, 0.54, 0.45))
			if width < 16.0:
				continue
			var columns: int = maxi(1, int((width - 12.0) / 13.0))
			var rows: int = maxi(1, int((building.height - 20.0) / 18.0))
			for row: int in range(rows):
				for column: int in range(columns):
					var pattern: int = (building.pattern + row * 17 + column * 11) % 9
					if pattern > 4:
						continue
					var window_color: Color = Color(light, brightness * (0.36 if pattern == 0 else 0.7))
					if pattern == 4:
						window_color = Color(0.77, 0.39, 0.6, brightness * 0.44)
					draw_rect(Rect2(x + 8 + float(column) * 13.0, y + 13 + float(row) * 18.0, 3.0 if not detailed else 4.0, 5.0), window_color)
			if detailed and building.neon:
				var accent: Color = Color(0.08, 0.66, 0.77, 0.42) if building.pattern % 2 == 0 else Color(0.61, 0.23, 0.63, 0.45)
				draw_line(Vector2(x + width - 4.0, y + 5), Vector2(x + width - 4.0, baseline), Color(accent, 0.08), 7.0, true)
				draw_line(Vector2(x + width - 4.0, y + 5), Vector2(x + width - 4.0, baseline), accent, 1.0, true)
				if width > 55.0:
					draw_rect(Rect2(x + 10, y + 24, width - 24, 9), Color(accent, 0.22))
					draw_line(Vector2(x + 14, y + 28), Vector2(x + width - 18, y + 28), accent, 1.0, true)


func _draw_runway() -> void:
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 720.0 - RUNWAY_Y), Color("080f1d"))
	draw_rect(Rect2(0, RUNWAY_Y - 9, WORLD_WIDTH, 16), Color(0.05, 0.7, 0.9, 0.025))
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color(0.14, 0.86, 0.98, 0.13), 7.0, true)
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color("4ca5b9"), 1.5, true)
	draw_line(Vector2(0, RUNWAY_Y + 5), Vector2(WORLD_WIDTH, RUNWAY_Y + 5), Color("183b4d"), 1.0)
	var road_offset: float = fposmod(travel, 120.0)
	for marker: int in range(-1, 13):
		var x: float = float(marker) * 120.0 - road_offset
		draw_line(Vector2(x, RUNWAY_Y + 11), Vector2(x - 42, 720), Color(0.12, 0.39, 0.49, 0.2), 1.0, true)
		draw_rect(Rect2(x + 14, RUNWAY_Y + 19, 25, 2), Color("246b82"))
	draw_line(Vector2(0, 700), Vector2(WORLD_WIDTH, 700), Color("122436"), 1.0)


func _gradient(top: Color, bottom: Color) -> void:
	for band: int in range(48):
		draw_rect(Rect2(0, float(band) * 15.0, WORLD_WIDTH, 16.0), top.lerp(bottom, float(band) / 47.0))


func _draw_desert() -> void:
	_gradient(Color("152a48"), Color("c4745b"))
	# Layered sunset disc and thin wind-swept clouds sit behind the mesa range.
	var sun: Vector2 = Vector2(1012, 264)
	for halo: int in range(4, 0, -1):
		draw_circle(sun, 63.0 + float(halo) * 18.0, Color(1.0, 0.61, 0.3, 0.016))
	draw_circle(sun, 63.0, Color("ffc780"))
	for stripe: int in range(5):
		var y: float = 273.0 + float(stripe) * 10.0
		draw_line(Vector2(945, y), Vector2(1079, y), Color("b56c67"), 2.0 + float(stripe) * 0.55, true)
	for streak: int in range(9):
		var x: float = fposmod(float(streak * 239) - travel * 0.025, 1500.0) - 100.0
		var y: float = 171.0 + float(streak % 4) * 49.0
		draw_line(Vector2(x, y), Vector2(x + 94.0 + float(streak % 3) * 28.0, y), Color(1.0, 0.7, 0.49, 0.1), 2.0, true)
	_draw_mesa_layer(0.055, 479.0, Color("705275"), 330.0)
	_draw_mesa_layer(0.14, 575.0, Color("92555c"), 295.0)
	_draw_dunes(0.27, 588.0, 32.0, Color("b36e57"), 1.1)
	_draw_dunes(0.44, 626.0, 22.0, Color("d08a60"), 2.7)
	# Sparse, recognisable silhouettes stay in the decorative lower band.
	for index: int in range(10):
		var cactus_x: float = fposmod(float(index) * 183.0 + 82.0 - travel * 0.32, 1700.0) - 100.0
		var cactus_height: float = 34.0 + float(index % 4) * 9.0
		_draw_cactus(Vector2(cactus_x, 652.0), cactus_height, Color("555752"))
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 60), Color("80523d"))
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 7), Color("e4b377"))
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color("ffe0a1"), 2.0, true)
	for ripple: int in range(28):
		var x: float = fposmod(float(ripple) * 57.0 - travel * 0.9, 1450.0) - 80.0
		var y: float = 678.0 + float(ripple % 3) * 13.0
		draw_line(Vector2(x, y), Vector2(x + 28.0, y - 3.0), Color(1.0, 0.76, 0.46, 0.23), 1.0, true)
	# Airborne dust is deliberately dim, and never the same colour as a pickup.
	for grain: int in range(18):
		var x: float = fposmod(float(grain * 137) - travel * 0.45, 1400.0) - 60.0
		var y: float = 430.0 + fposmod(float(grain * 53), 204.0)
		draw_line(Vector2(x, y), Vector2(x + 9, y - 1), Color(0.94, 0.66, 0.44, 0.15), 1.0)


func _draw_mesa_layer(parallax: float, baseline: float, fill: Color, span: float) -> void:
	var offset: float = fposmod(travel * parallax, span)
	for index: int in range(-1, 7):
		var x: float = float(index) * span - offset
		var peak: float = baseline - 95.0 - float(posmod(index + 13, 3)) * 30.0
		var ridge: PackedVector2Array = PackedVector2Array([
			Vector2(x - 20, RUNWAY_Y), Vector2(x, baseline), Vector2(x + span * 0.13, baseline - 37),
			Vector2(x + span * 0.2, peak + 8), Vector2(x + span * 0.28, peak),
			Vector2(x + span * 0.53, peak), Vector2(x + span * 0.61, peak + 19),
			Vector2(x + span * 0.66, baseline - 26), Vector2(x + span * 0.82, baseline - 4),
			Vector2(x + span + 5, baseline + 12), Vector2(x + span + 5, RUNWAY_Y),
		])
		draw_colored_polygon(ridge, fill)
		draw_polyline(PackedVector2Array([Vector2(x + span * 0.2, peak + 8), Vector2(x + span * 0.28, peak), Vector2(x + span * 0.53, peak)]), Color(fill.lightened(0.14), 0.5), 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + span * 0.53, peak + 1), Vector2(x + span * 0.61, peak + 19),
			Vector2(x + span * 0.66, baseline - 26), Vector2(x + span * 0.47, baseline + 18),
		]), Color(fill.darkened(0.12), 0.7))


func _draw_dunes(parallax: float, baseline: float, amplitude: float, fill: Color, phase: float) -> void:
	var line: PackedVector2Array = PackedVector2Array()
	for index: int in range(-1, 47):
		var x: float = float(index) * 30.0
		var world_x: float = x + travel * parallax
		var y: float = baseline + sin(world_x / 190.0 + phase) * amplitude + sin(world_x / 380.0 + phase) * amplitude * 0.4
		line.append(Vector2(x, minf(y, RUNWAY_Y)))
	var dune: PackedVector2Array = line.duplicate()
	dune.append(Vector2(1380, RUNWAY_Y))
	dune.append(Vector2(-30, RUNWAY_Y))
	draw_colored_polygon(dune, fill)
	draw_polyline(line, Color(fill.lightened(0.22), 0.6), 1.5, true)


func _draw_cactus(base: Vector2, height: float, fill: Color) -> void:
	var top: Vector2 = base - Vector2(0, height)
	draw_line(base, top, fill, 7.0, true)
	draw_circle(top, 3.5, fill)
	draw_polyline(PackedVector2Array([base + Vector2(0, -height * 0.46), base + Vector2(-12, -height * 0.46), base + Vector2(-12, -height * 0.75)]), fill, 5.0, true)
	draw_polyline(PackedVector2Array([base + Vector2(0, -height * 0.29), base + Vector2(12, -height * 0.29), base + Vector2(12, -height * 0.57)]), fill, 5.0, true)
	draw_circle(base + Vector2(-12, -height * 0.75), 2.5, fill)
	draw_circle(base + Vector2(12, -height * 0.57), 2.5, fill)


func _draw_sky_world() -> void:
	_gradient(Color("163755"), Color("5eafbf"))
	var sun: Vector2 = Vector2(1055, 204)
	for halo: int in range(5, 0, -1):
		draw_circle(sun, 36.0 + float(halo) * 14.0, Color(1.0, 0.96, 0.74, 0.018))
	draw_circle(sun, 36.0, Color("fff1bf"))
	draw_circle(sun + Vector2(-7, -8), 25.0, Color(1.0, 1.0, 0.9, 0.16))
	# Cloud families have different speeds, sizes and heights, producing depth.
	for layer: int in range(3):
		for cloud: int in range(7):
			var spacing: float = 258.0 + float(layer) * 32.0
			var x: float = fposmod(float(cloud) * spacing + float(layer) * 104.0 - travel * (0.04 + float(layer) * 0.07), 1780.0) - 220.0
			var y: float = 185.0 + float(layer) * 160.0 + float(cloud % 3) * 43.0
			var cloud_scale: float = 0.75 + float(layer) * 0.4 + float(cloud % 2) * 0.19
			_draw_cloud(Vector2(x, y), cloud_scale, Color(0.79, 0.94, 1.0, 0.16 + float(layer) * 0.035))
	# These distant hanging islands are scenery, below most of the flight lane.
	for island: int in range(4):
		var x: float = fposmod(float(island) * 437.0 + 170.0 - travel * 0.16, 1810.0) - 200.0
		var y: float = 535.0 + float(island % 3) * 28.0
		_draw_floating_island(Vector2(x, y), 0.75 + float(island % 2) * 0.35)
	# Fine horizontal air trails reinforce speed while staying behind obstacles.
	for trail: int in range(12):
		var x: float = fposmod(float(trail) * 151.0 - travel * 0.38, 1500.0) - 120.0
		var y: float = 265.0 + float(trail % 6) * 57.0
		draw_line(Vector2(x, y), Vector2(x + 68.0, y), Color(0.84, 0.97, 1.0, 0.09), 1.0, true)
	# A continuous visible edge marks the same ground boundary as every biome.
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 60), Color("376987"))
	for cloud: int in range(12):
		var x: float = float(cloud) * 128.0 - fposmod(travel * 0.55, 128.0)
		_draw_cloud(Vector2(x, 701.0), 1.3, Color(0.71, 0.9, 0.98, 0.25))
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color(0.75, 0.94, 1.0, 0.16), 9.0, true)
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color("c5edf3"), 2.0, true)


func _draw_cloud(center: Vector2, cloud_scale: float, fill: Color) -> void:
	# A single silhouette avoids dark overlap rings between translucent lobes.
	var profile: PackedVector2Array = PackedVector2Array()
	var lobes: Array[Vector3] = [Vector3(-48, 2, 22), Vector3(-18, -11, 29), Vector3(14, -20, 36), Vector3(48, -1, 25)]
	for index: int in range(50):
		var x: float = -73.0 + float(index) * 3.0
		var y: float = 13.0
		for lobe: Vector3 in lobes:
			var dx: float = x - lobe.x
			if absf(dx) < lobe.z:
				y = minf(y, lobe.y - sqrt(lobe.z * lobe.z - dx * dx))
		profile.append(center + Vector2(x, y) * cloud_scale)
	for index: int in range(49, -1, -1):
		var x: float = -73.0 + float(index) * 3.0
		var y: float = 13.0 + sin(float(index) / 49.0 * PI) * 7.0
		profile.append(center + Vector2(x, y) * cloud_scale)
	draw_colored_polygon(profile, fill)


func _draw_floating_island(center: Vector2, island_scale: float) -> void:
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(-96, 0), Vector2(-75, -9), Vector2(-30, -14), Vector2(7, -7), Vector2(66, -12),
		Vector2(101, 0), Vector2(58, 21), Vector2(30, 83), Vector2(12, 45), Vector2(-15, 68), Vector2(-49, 29),
	])
	for index: int in range(profile.size()):
		profile[index] = center + profile[index] * island_scale
	draw_colored_polygon(profile, Color("365e77"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(11, 1) * island_scale, center + Vector2(90, 0) * island_scale, center + Vector2(58, 21) * island_scale, center + Vector2(30, 83) * island_scale]), Color("2b536e"))
	draw_line(center + Vector2(-75, -8) * island_scale, center + Vector2(63, -10) * island_scale, Color("70b9a9"), 4.0 * island_scale, true)
	# Tiny trees establish the islands' distance and keep them clearly decorative.
	for tree: int in range(3):
		var base: Vector2 = center + Vector2(-36 + tree * 30, -11) * island_scale
		draw_line(base, base - Vector2(0, 20.0) * island_scale, Color("456d76"), 2.0 * island_scale, true)
		draw_circle(base - Vector2(0, 22.0) * island_scale, (9.0 + float(tree % 2) * 3.0) * island_scale, Color("4e8a86"))


func _draw_underwater() -> void:
	_gradient(Color("063b54"), Color("051b33"))
	# The surface and animated shafts make the underwater setting unambiguous.
	for beam: int in range(7):
		var x: float = float(beam) * 230.0 - 110.0 + sin(clock * 0.18 + float(beam)) * 18.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 108), Vector2(x + 35, 108), Vector2(x + 264, 658), Vector2(x + 82, 658)]), Color(0.2, 0.85, 0.9, 0.022))
	var surface: PackedVector2Array = PackedVector2Array()
	for index: int in range(46):
		var x: float = float(index) * 30.0
		surface.append(Vector2(x, 126.0 + sin(float(index) * 0.47 + clock * 0.5) * 3.0))
	draw_polyline(surface, Color(0.31, 0.88, 0.92, 0.19), 2.0, true)
	for layer: int in range(2):
		var spacing: float = 264.0 + float(layer) * 115.0
		var parallax: float = 0.04 + float(layer) * 0.09
		for rock: int in range(7):
			var x: float = fposmod(float(rock) * spacing - travel * parallax, 1900.0) - 240.0
			var height: float = 104.0 + float(posmod(rock * 7 + layer, 4)) * 39.0
			var fill: Color = Color("0d3b4c") if layer == 0 else Color("114255")
			draw_colored_polygon(PackedVector2Array([Vector2(x, 665), Vector2(x + 28, 600), Vector2(x + 71, 660 - height), Vector2(x + 118, 647 - height), Vector2(x + 175, 569), Vector2(x + spacing, 665)]), fill)
	for fish: int in range(19):
		var x: float = fposmod(float(fish * 157) - travel * 0.065 + clock * 7.0, 1480.0) - 100.0
		var y: float = 222.0 + float(fish % 5) * 53.0 + sin(clock * 0.45 + float(fish)) * 7.0
		_draw_fish(Vector2(x, y), 0.5 + float(fish % 3) * 0.18, Color(0.28, 0.65, 0.7, 0.22))
	for plant: int in range(18):
		var x: float = fposmod(float(plant) * 91.0 - travel * 0.35, 1640.0) - 100.0
		var height: float = 25.0 + float(plant % 4) * 12.0
		if plant % 3 == 0:
			_draw_coral(Vector2(x, 658), height, Color("38717a"))
		else:
			_draw_seaweed(Vector2(x, 661), height, float(plant))
	# Bubbles are hollow and faint to keep gold coins and solid N2 bottles distinct.
	for bubble: int in range(21):
		var x: float = fposmod(float(bubble * 167) - travel * 0.18 + sin(clock + float(bubble)) * 8.0, 1390.0) - 50.0
		var y: float = 652.0 - fposmod(float(bubble * 97) + clock * (11.0 + float(bubble % 4) * 4.0), 500.0)
		var radius: float = 1.5 + float(bubble % 3) * 1.2
		draw_arc(Vector2(x, y), radius, 0.0, TAU, 16, Color(0.45, 0.85, 0.89, 0.14), 1.0, true)
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 60), Color("0a2a3a"))
	draw_rect(Rect2(0, RUNWAY_Y, WORLD_WIDTH, 5), Color("34717b"))
	draw_line(Vector2(0, RUNWAY_Y), Vector2(WORLD_WIDTH, RUNWAY_Y), Color("86c9bd"), 1.8, true)
	for pebble: int in range(25):
		var x: float = fposmod(float(pebble) * 63.0 - travel * 0.9, 1480.0) - 80.0
		var y: float = 680.0 + float(pebble % 3) * 14.0
		draw_line(Vector2(x, y), Vector2(x + 12.0 + float(pebble % 4) * 3.0, y), Color(0.22, 0.52, 0.54, 0.4), 2.0, true)


func _draw_fish(center: Vector2, fish_scale: float, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12, 0) * fish_scale, center + Vector2(-3, -5) * fish_scale,
		center + Vector2(9, -2) * fish_scale, center + Vector2(17, -7) * fish_scale,
		center + Vector2(17, 6) * fish_scale, center + Vector2(9, 2) * fish_scale,
		center + Vector2(-3, 5) * fish_scale,
	]), fill)


func _draw_seaweed(base: Vector2, height: float, phase: float) -> void:
	for stem: int in range(3):
		var line: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(8):
			var t: float = float(point_index) / 7.0
			var offset: float = sin(t * 4.7 + phase + clock * 0.8) * 7.0 * t
			line.append(base + Vector2(float(stem - 1) * 8.0 + offset, -height * t * (0.75 + float(stem) * 0.13)))
		draw_polyline(line, Color("287778") if stem % 2 == 0 else Color("205862"), 3.0, true)


func _draw_coral(base: Vector2, height: float, fill: Color) -> void:
	draw_line(base, base - Vector2(0, height), fill, 5.0, true)
	for branch: int in range(3):
		var y: float = -height * (0.35 + float(branch) * 0.21)
		var side: float = -1.0 if branch % 2 == 0 else 1.0
		var tip: Vector2 = base + Vector2(side * (19.0 - float(branch) * 3.0), y - 13)
		draw_polyline(PackedVector2Array([base + Vector2(0, y), base + Vector2(side * 13, y - 4), tip]), fill, 3.0, true)
		draw_circle(tip, 3.0, fill.lightened(0.12))
	draw_circle(base - Vector2(0, height), 3.0, fill.lightened(0.12))
