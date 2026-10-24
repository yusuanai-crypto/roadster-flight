extends SceneTree
## QA-only renderer. It has no entry point in normal player UI.
## Run without --headless: godot --path . -s res://tests/render_capture.gd

const AppScene = preload("res://scenes/app.tscn")
var game
var capture_root := "D:/Tesla/builds/qa"

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
	root.size = Vector2i(1280, 720)
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	await capture("01-menu")
	game.start_run()
	await capture("02-countdown")
	game.begin_playing()
	game.elapsed = 18.0
	game.travel = 6500.0
	game.distance = 520.0
	game.coins = 17
	game.player.fuel = 62.0
	game.player.position.y = 355.0
	game.player.thrusting = true
	game.player.velocity.y = -90.0
	game.director.reset_route()
	game.director.set_active(true)
	game.director.spawn_gate(1120.0)
	game.director.spawn_hazard(Vector2(810, 168), Vector2(86, 96), "electric")
	game.director.spawn_coin_arc(515, 310, 6)
	game.director.spawn_pickup("tank", Vector2(940, 380))
	game.ui.clear_notices()
	game._update_view()
	await capture("03-flight")
	game.pause_run()
	await capture("04-pause")
	game.resume_run()
	game.finish_run()
	await capture("05-result")
	paused = false
	game.queue_free()
	await process_frame
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await process_frame
	quit()
