extends SceneTree
## Generate genuine scene previews from the same renderers used in flight.
## godot --path . -s res://tools/generate-previews.gd

const Backdrop = preload("res://visuals/city_background.gd")
const Car = preload("res://visuals/roadster_visual.gd")
const Pickup = preload("res://visuals/pickup_visual.gd")
const Hazard = preload("res://visuals/hazard_visual.gd")
const Geometry = preload("res://scripts/hazard_geometry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Node2D.new()
	root.add_child(scene)
	var background := Backdrop.new()
	scene.add_child(background)
	background.travel = 1850.0
	background.clock = 8.0
	var car := Car.new()
	car.position = Vector2(480, 368)
	car.scale = Vector2(1.9, 1.9)
	car.thrusting = true
	scene.add_child(car)
	for index in range(6):
		var coin := Pickup.new()
		coin.kind = "coin"
		coin.position = Vector2(695 + index * 65, 340 - sin(float(index) / 5.0 * PI) * 70.0)
		scene.add_child(coin)
	var tank := Pickup.new()
	tank.kind = "nitro"
	tank.position = Vector2(1110, 390)
	scene.add_child(tank)
	var hazards: Array[Node2D] = []
	for index in range(3):
		var hazard := Hazard.new()
		hazard.position = [Vector2(725, 190), Vector2(935, 515), Vector2(1155, 205)][index]
		scene.add_child(hazard)
		hazards.append(hazard)
	DirAccess.make_dir_recursive_absolute("res://assets/previews")
	for theme_id: String in ["city", "desert", "sky", "underwater"]:
		background.theme_id = theme_id
		background.queue_redraw()
		for index in range(hazards.size()):
			var hazard = hazards[index]
			hazard.theme_id = theme_id
			hazard.kind = Geometry.STYLES[theme_id][index]
			hazard.size = Geometry.SIZES[hazard.kind] * 1.2
			hazard.parts = Geometry.polygons(hazard.kind, hazard.size)
			hazard.queue_redraw()
		for child in scene.get_children():
			if child is Pickup:
				child.theme_id = theme_id
				child.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://assets/previews/%s.png" % theme_id
		var error := root.get_texture().get_image().save_png(path)
		print("PREVIEW %s: %s" % [theme_id, error_string(error)])
		if error != OK:
			quit(1)
			return
	quit()
