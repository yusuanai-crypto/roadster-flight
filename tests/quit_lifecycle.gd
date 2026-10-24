extends SceneTree
## Exercises shipping Exit and repeated window-close notifications, including
## a paused world. Capture complete stderr to check final AudioServer teardown.

const AppScene = preload("res://scenes/app.tscn")
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	check(not auto_accept_quit, "window close is routed through the application")
	game.start_run()
	await physics_frame
	await physics_frame
	game.begin_playing()
	game.pause_run()
	check(paused and game.music._player.stream_paused, "test starts from a paused game with active paused music")
	# These arrive while the first real _quit is waiting for the audio mix.
	game.call_deferred("_quit")
	root.call_deferred("propagate_notification", Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var started_at := Time.get_ticks_msec()
	await game._quit()
	check(Time.get_ticks_msec() - started_at >= 200, "normal quit allows a real audio cleanup interval")
	check(game._quitting and not paused and not game.director.active, "quit is idempotent and stops the paused world")
	check(not game.music._player.playing and game.music._player.stream == null and game.music._fade == null, "quit stops playback, clears its stream and kills the fade")
	game.music.shutdown()
	game.music.set_theme("sky")
	game.music.set_mode("playing")
	check(game.music._player.stream == null, "shutdown is idempotent and cannot restart music")
	print("QUIT LIFECYCLE RESULT: %d assertions, %d failures" % [assertions, failures.size()])
	if not failures.is_empty():
		quit(1)
