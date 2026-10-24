extends SceneTree
## Visible OpenGL capture of all four real menu previews and flight scenes.
## Run: godot --path . -s res://tests/render_v2.gd

const AppScene = preload("res://scenes/app.tscn")
const Balance = preload("res://scripts/game_balance.gd")
var game
var capture_root := "D:/Tesla/builds/qa/v2"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_root = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(capture_root.path_join(label + ".png"))
	print("CAPTURE %s: %s" % [label, error_string(result)])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(capture_root)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	for theme_id: String in game.THEMES:
		game.show_menu()
		game.ui.theme_buttons[theme_id].pressed.emit()
		var transition_deadline := Time.get_ticks_msec() + 2000
		while game.ui.carousel_tween != null and Time.get_ticks_msec() < transition_deadline:
			await process_frame
		await capture("menu-" + theme_id)
		game.start_run()
		# Let the physics server sync the car's teleport from the menu showcase.
		await physics_frame
		await physics_frame
		await process_frame
		game.begin_playing()
		game.elapsed = 120.0
		game.current_speed = Balance.speed_at(game.elapsed)
		game.travel = 24000.0
		game.distance = 1920.0
		game.coins = 39
		game.player.fuel = 62.0
		game.player.position.y = 355.0
		game.player.thrusting = true
		game.player.velocity.y = -90.0
		game.director.reset_route()
		game.director.run_clock = 120.0
		game.director.set_active(true)
		game.director.spawn_gate(1120.0)
		game.director.spawn_coin_arc(445.0, 326.0, 6)
		game.director.spawn_pickup("tank", Vector2(885.0, 370.0))
		game.ui.clear_notices()
		game._update_view()
		await capture("flight-" + theme_id)
		game.pause_run()
		await capture("pause-" + theme_id)
		game.resume_run()
	game.player.fuel = 0.0
	game.player.hit_ground()
	game._update_view()
	await capture("rescue-50-percent")
	game.player.fuel = 0.0
	game.player.health = 1
	game.player.hit_ground()
	game._update_view()
	await capture("result-empty-tank")
	paused = false
	game.queue_free()
	await process_frame
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await process_frame
	quit()
