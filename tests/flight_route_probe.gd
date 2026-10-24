extends SceneTree
## QA-only scripted flight over a seeded random route. No autopilot is
## accessible from the player UI. --fixed-fps 60 disables wall-clock waiting.
## Run: godot --headless --fixed-fps 60 --path . -s res://tests/flight_route_probe.gd

const AppScene = preload("res://scenes/app.tscn")
var game
var max_entities: int = 0
var min_fuel: float = 100.0
var hazards_during_training: bool = false
var seconds_to_probe: float = 90.0
var ticks: int = 0
var theme_to_probe := "city"
var seed_to_probe: int = 2026

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="):
			seconds_to_probe = clampf(argument.trim_prefix("--duration=").to_float(), 1.0, 600.0)
		elif argument.begins_with("--theme="):
			theme_to_probe = argument.trim_prefix("--theme=")
		elif argument.begins_with("--seed="):
			seed_to_probe = argument.trim_prefix("--seed=").to_int()
	call_deferred("_run")

func _run() -> void:
	game = AppScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.select_theme(theme_to_probe)
	game.start_run()
	game.director.rng.seed = seed_to_probe
	while game.state == game.RunState.COUNTDOWN and ticks < 600:
		ticks += 1
		await physics_frame
	print("ROUTE PROBE started after %d physics ticks, state=%d" % [ticks, game.state])
	var max_probe_ticks := ceili((seconds_to_probe + 10.0) * 60.0)
	while game.state == game.RunState.PLAYING and game.elapsed < seconds_to_probe and ticks < max_probe_ticks:
		ticks += 1
		# QA follows visible supplies and the nearest random group's lane using
		# ordinary Input. Physics, fuel, hits and rescue remain fully enabled.
		var target_y := 350.0
		var nearest_tank_x := INF
		for entity in game.director.get_children():
			if entity.get("kind") == "tank" and not entity.consumed and entity.enabled:
				if entity.position.x > game.player.position.x and entity.position.x <= 1280.0 and entity.position.x < nearest_tank_x:
					nearest_tank_x = entity.position.x
					target_y = entity.position.y
		var nearest_hazard_x := INF
		var hazard_target := 350.0
		var tank_route_clear := nearest_tank_x < 950.0
		for entity in game.director.get_children():
			if entity.collision_layer == 4 and entity.enabled:
				if entity.position.x > game.player.position.x - entity.size.x * .5 - 62.0 and entity.position.x <= nearest_tank_x + 100.0:
					if absf(entity.position.y - target_y) < entity.size.y * .5 + 46.0:
						tank_route_clear = false
				if entity.position.x > game.player.position.x - entity.size.x * .5 - 62.0 and entity.position.x < 760.0 and entity.position.x < nearest_hazard_x:
					nearest_hazard_x = entity.position.x
					hazard_target = entity.safe_center
		if nearest_hazard_x < INF and not tank_route_clear:
			target_y = hazard_target
		var projected_y: float = game.player.position.y + game.player.velocity.y * 0.30
		if projected_y > target_y:
			Input.action_press("thrust_keyboard")
		else:
			Input.action_release("thrust_keyboard")
		max_entities = maxi(max_entities, game.director.get_child_count())
		min_fuel = minf(min_fuel, game.player.fuel)
		if game.elapsed < 10.0:
			for entity in game.director.get_children():
				if entity.collision_layer == 4:
					hazards_during_training = true
		if ticks % 900 == 0:
			print("ROUTE PROBE progress: ticks=%d, elapsed=%.2f, health=%d, fuel=%.2f" % [ticks, game.elapsed, game.player.health, game.player.fuel])
		await physics_frame
	Input.action_release("thrust_keyboard")
	var passed: bool = game.elapsed >= seconds_to_probe and game.player.health == 3 and game.coins >= 20 and max_entities < 80 and not hazards_during_training
	print("ROUTE PROBE: theme=%s seed=%d elapsed=%.2fs, distance=%.1fm, health=%d, coins=%d, fuel=%.2f, min_fuel=%.2f, max_entities=%d, training_hazards=%s" % [theme_to_probe, seed_to_probe, game.elapsed, game.distance, game.player.health, game.coins, game.player.fuel, min_fuel, max_entities, hazards_during_training])
	print("ROUTE PROBE RESULT: %s" % ("PASS" if passed else "FAIL"))
	paused = false
	game.queue_free()
	await process_frame
	# --fixed-fps can finish virtual seconds faster than the audio mix thread.
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await process_frame
	quit(0 if passed else 1)
