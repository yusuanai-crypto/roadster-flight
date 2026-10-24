extends SceneTree
## Real flight render of the three shipping silhouettes in each environment.
const AppScene = preload("res://scenes/app.tscn")
const Geometry = preload("res://scripts/hazard_geometry.gd")
var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	for theme: String in Geometry.STYLES:
		game.show_menu()
		game.select_theme(theme)
		game.start_run()
		await physics_frame
		await physics_frame
		game.begin_playing()
		game.director.reset_route()
		for child in game.director.get_children():
			game.director.remove_child(child)
			child.queue_free()
		game.director.run_clock = 120.0
		game.director.rng.seed = 101
		game.director.set_active(true)
		for index in range(3):
			var style: String = Geometry.STYLES[theme][index]
			var at := Vector2(575 + index * 270, [235, 415, 558][index])
			game.director.spawn_hazard(at, Geometry.SIZES[style], style)
		game.director.spawn_coin_arc(340, 335, 5)
		game.director.spawn_pickup("tank", Vector2(970, 310))
		game.elapsed = 120.0
		game.current_speed = 526.7
		game.distance = 1920.0
		game.travel = 24000.0
		game.coins = 39
		game.player.fuel = 62.0
		game.player.thrusting = true
		game.player.position.y = 350.0
		game.ui.clear_notices()
		game._update_view()
		await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://builds/qa/v5/obstacles-%s.png" % theme
		var result := root.get_texture().get_image().save_png(output)
		print("CAPTURE %s: %s" % [theme, error_string(result)])
	game.queue_free()
	await process_frame
	var cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < cleanup_until:
		await process_frame
	quit()
