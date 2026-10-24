extends SceneTree
## V2 integration checks use the shipping controllers and live Area2D entities.
## Run: godot --headless --path . -s res://tests/v2_features.gd

const AppScene = preload("res://scenes/app.tscn")
const Balance = preload("res://scripts/game_balance.gd")
var game
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, explanation: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + explanation)
	else:
		failures.append(explanation)
		push_error("FAIL: " + explanation)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func fresh_run() -> void:
	game.start_run()
	await settle()
	game.begin_playing()

func _run() -> void:
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	check(game.music.process_mode == Node.PROCESS_MODE_ALWAYS, "music can receive pause and menu transitions while world is paused")
	await check_difficulty()
	await check_rescue()
	await check_scenes()
	await check_music()
	check_resources()
	paused = false
	game.queue_free()
	await process_frame
	# AudioServer releases the stopped WAV voice on its next mix. Continue
	# pumping frames for real time; fixed-fps QA can otherwise exit before it.
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await process_frame
	print("V2 RESULT: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_difficulty() -> void:
	var checkpoints := [0.0, 30.0, 60.0, 120.0, 180.0]
	var previous_speed: float = 0.0
	var previous_interval: float = 100.0
	for seconds: float in checkpoints:
		var speed: float = Balance.speed_at(seconds)
		var interval: float = Balance.gate_interval_at(seconds)
		check(speed > previous_speed and interval < previous_interval, "difficulty increases at %.0fs: speed %.1f, interval %.2f" % [seconds, speed, interval])
		check(Balance.visible_reaction_time_at(seconds) >= Balance.MIN_VISIBLE_REACTION_SECONDS, "fully visible obstacle allows at least 1.5s reaction at %.0fs" % seconds)
		check(Balance.gate_opening_at(seconds) >= 184.0, "random route opening stays wider than six car heights at %.0fs" % seconds)
		previous_speed = speed
		previous_interval = interval
	check(is_equal_approx(Balance.speed_at(900.0), Balance.MAX_SPEED) and is_equal_approx(Balance.gate_interval_at(900.0), Balance.MIN_GATE_INTERVAL), "speed and group density cap after the ramp")
	check(Balance.speed_at(-1.0) == Balance.START_SPEED, "negative time cannot produce invalid speed")
	# Exercise the live director over six consecutive half-minute windows.
	game.show_menu()
	var director = game.director
	director.reset_route()
	director.set_active(true)
	var counts: Array[int] = []
	var last_count: int = 0
	var training_clear := true
	var max_entities: int = 0
	for frame in range(10800):
		director.advance(1.0 / 60.0, Balance.speed_at(director.run_clock))
		if director.run_clock < Balance.TRAINING_SECONDS and director.gates_spawned > 0:
			training_clear = false
		max_entities = maxi(max_entities, director.get_child_count())
		if (frame + 1) % 1800 == 0:
			counts.append(director.gates_spawned - last_count)
			last_count = director.gates_spawned
		if frame % 60 == 0:
			await process_frame
	check(training_clear, "live director spawns no obstacles during the first 10 seconds")
	check(counts[0] < counts[1] and counts[1] < counts[3] and counts[3] < counts[5], "real half-minute gate counts increase from early to late play: %s" % str(counts))
	check(max_entities < 100, "live spawn queue stays bounded across 180 seconds (max %d)" % max_entities)
	var before_jump: int = director.gates_spawned
	director.advance(45.0, Balance.MAX_SPEED)
	check(director.gates_spawned == before_jump + 1, "a long frame cannot spawn a backlog of gates at once")
	# Inspect the actual random group rather than the removed edge-wall layout.
	director.reset_route()
	director.run_clock = 180.0
	director.spawn_gate(1200.0)
	var corridor_clear := true
	for entity in director.get_children():
		if entity.collision_layer == 4:
			corridor_clear = corridor_clear and absf(entity.position.y - director.route_center) - entity.size.y * .5 >= Balance.gate_opening_at(180.0) * .5
	check(corridor_clear and director.hazards_spawned > 0, "late live random group preserves its open corridor")
	await fresh_run()
	game.director.set_active(false)
	game.simulate_step(1.0 / 60.0, true)
	var first_speed: float = game.current_speed
	game.elapsed = 180.0
	var travel_before: float = game.travel
	game.simulate_step(1.0 / 60.0, true)
	check(game.current_speed > first_speed and is_equal_approx(game.travel - travel_before, Balance.MAX_SPEED / 60.0), "shipping simulation actually moves the world faster late in a run")
	game.pause_run()
	var snapshot := [game.elapsed, game.current_speed, game.travel, game.director.run_clock]
	for frame in range(10):
		game.simulate_step(1.0, true)
		await physics_frame
	check(snapshot == [game.elapsed, game.current_speed, game.travel, game.director.run_clock], "paused gameplay does not advance speed, distance or obstacle timers")
	game.resume_run()

func check_rescue() -> void:
	await fresh_run()
	var player = game.player
	player.fuel = 0.0
	player.position.y = Balance.GROUND_Y + 2.0
	player.velocity.y = 200.0
	player.simulate(1.0 / 60.0, false)
	check(player.health == 2 and player.fuel == Balance.MAX_FUEL * 0.5, "surviving an actual empty-tank ground fall restores exactly 50% nitro")
	check(player.position.y == Balance.RESCUE_Y and player.velocity.y == 0.0, "empty-tank rescue restores safe altitude and stops the fall")
	check(game.last_damage_cause == "氮气耗尽坠落" and game.ui.notice_label.text.contains("50%"), "empty-tank damage keeps the cause and displays the rescue refill")
	player.simulate(1.0 / 60.0, true)
	check(player.thrusting and player.velocity.y < 0.0, "rescued car can immediately fly again")
	await fresh_run()
	player.fuel = 70.0
	player.hit_ground()
	check(player.health == 2 and player.fuel == 70.0 and game.last_damage_cause == "触地坠落", "a ground impact with fuel neither refills nor reports an empty-tank cause")
	await fresh_run()
	player.fuel = 0.0
	player.health = 1
	player.position.y = Balance.GROUND_Y
	player.hit_ground()
	check(player.health == 0 and player.fuel == 0.0 and player.position.y == Balance.GROUND_Y, "last-life empty-tank fall ends the run without fuel or revival")
	check(game.state == game.RunState.RESULT and game.last_damage_cause == "氮气耗尽坠落", "last-life settlement records the real empty-tank cause")
	player.hit_ground()
	check(game.finish_count == 1 and player.fuel == 0.0, "repeated ground callbacks cannot revive or settle twice")
	await fresh_run()
	player.fuel = 0.0
	player.take_damage("碰撞障碍", true)
	check(player.health == 2 and player.fuel == 0.0, "an empty tank does not grant fuel merely for colliding with an obstacle")

func check_scenes() -> void:
	for theme_id: String in game.THEMES:
		game.show_menu()
		game.ui.theme_buttons[theme_id].pressed.emit()
		check(game.selected_theme == theme_id and game.background.theme_id == theme_id and game.ui.theme_buttons[theme_id].text.begins_with("●"), "%s menu choice changes the live background preview and selection" % theme_id)
		await fresh_run()
		var pickup = game.director.spawn_pickup("tank", Vector2(1150.0, 350.0))
		var hazard = game.director.spawn_hazard(Vector2(1180.0, 550.0), Vector2(86, 150), "pillar")
		check(pickup.theme_id == theme_id and pickup.visual.theme_id == theme_id and hazard.visual.theme_id == theme_id, "%s passes to pickup and obstacle visuals" % theme_id)
		game.select_theme("sky" if theme_id != "sky" else "city")
		check(game.selected_theme == theme_id, "%s cannot change midway through a run" % theme_id)
		game.pause_run()
		game.start_run()
		check(game.selected_theme == theme_id and game.background.theme_id == theme_id and game.director.theme_id == theme_id, "%s retry preserves the selected environment" % theme_id)
	game.show_menu()
	game.select_theme("invalid")
	check(game.selected_theme == "underwater", "invalid scene IDs cannot replace the current selection")
	check(game.ui.preview_name.text == "海底", "menu scene label stays synchronized with the chosen environment")

func check_music() -> void:
	game.show_menu()
	game.select_theme("city")
	game.music.set_muted(false)
	game.ui.set_music_muted(false)
	for theme_id: String in game.THEMES:
		game.select_theme(theme_id)
		check(game.music._player.stream != null, "%s has a loaded scene music stream" % theme_id)
	await fresh_run()
	var stream_before: AudioStream = game.music._player.stream
	check(not game.music._player.stream_paused, "playing mode unpauses the audio stream")
	game.pause_run()
	check(game.music._player.stream_paused, "pause freezes the actual audio stream")
	game.resume_run()
	check(not game.music._player.stream_paused and game.music._player.stream == stream_before, "resume continues the same music stream")
	game.ui.music_buttons[1].pressed.emit()
	check(game.music.is_muted(), "HUD music button mutes the audio director")
	await create_timer(0.4, true).timeout
	check(game.music._player.volume_db <= -70.0, "muted audio fades to inaudible volume")
	game.pause_run()
	game.ui.music_buttons[2].pressed.emit()
	check(not game.music.is_muted() and game.music._player.stream_paused, "pause-menu music toggle preserves the paused stream")
	game.show_menu()
	check(not paused and not game.music._player.stream_paused, "returning from pause to menu restores menu audio")
	check(game.ui.music_buttons.size() == 3, "music controls exist on menu, HUD and pause screen")
	var protected_buttons := true
	for button in game.ui.music_buttons:
		protected_buttons = protected_buttons and button in game.ui.buttons
	check(protected_buttons, "every music button participates in mouse-thrust input protection")
	game.ui.music_buttons[0].pressed.emit()
	check(game.music.is_muted() and game.ui.music_buttons[1].icon == game.ui.SPEAKER_MUTED, "menu mute synchronizes the HUD speaker icon")
	game.start_run()
	check(game.music.is_muted(), "mute preference survives a new run")
	game.pause_run()
	game.resume_run()
	check(not game.music._player.stream_paused, "resuming a paused countdown restores countdown audio state")
	game.begin_playing()
	game.finish_run()
	check(not game.music._player.stream_paused, "result transition is not stuck in paused music")

func check_resources() -> void:
	var texture = load("res://assets/vehicle/reference-car.png")
	check(texture is Texture2D and texture.get_width() > 0, "reference car texture can load through Godot's exported resource paths")
	for theme_id: String in game.THEMES:
		var path: String = "res://assets/music/" + theme_id + ".wav"
		check(ResourceLoader.exists(path) and load(path) is AudioStream, "%s music is present as an exportable AudioStream" % theme_id)
