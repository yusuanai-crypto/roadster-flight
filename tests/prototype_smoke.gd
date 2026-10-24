extends SceneTree
## Run: godot --headless --path . -s res://tests/prototype_smoke.gd
## These checks exercise actual session, CharacterBody2D, and Area2D behavior.

const AppScene = preload("res://scenes/app.tscn")
const Balance = preload("res://scripts/game_balance.gd")
var game
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, explanation: String) -> void:
	assertions += 1
	if not condition:
		failures.append(explanation)
		push_error("FAIL: " + explanation)
	else:
		print("PASS: " + explanation)

func fresh_run() -> void:
	game.start_run()
	# Countdown normally provides this physics sync after teleporting the car
	# from its menu showcase. A test must not skip the physics server's sync.
	await settle_physics()
	game.begin_playing()

func settle_physics() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _run() -> void:
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await process_frame
	check(game.state == game.RunState.MENU, "starts in main menu")
	check(not game.save_service.enabled, "tests cannot alter the player's record")
	game.start_run()
	check(game.state == game.RunState.COUNTDOWN and game.elapsed == 0.0, "new run begins with countdown and no advanced world")
	Input.action_press("thrust_keyboard")
	await settle_physics()
	game.begin_playing()
	check(game._wants_thrust(), "space held during countdown immediately enables thrust after takeoff")
	Input.action_release("thrust_keyboard")
	Input.action_press("thrust_mouse")
	game.start_run()
	game.auto_simulation = true
	game._physics_process(1.0 / 60.0)
	check(not game.input_armed, "original held start click does not arm mouse thrust")
	Input.action_release("thrust_mouse")
	game._physics_process(1.0 / 60.0)
	Input.action_press("thrust_mouse")
	game._physics_process(1.0 / 60.0)
	check(game.player.fuel == 100.0 and game.player.velocity == Vector2.ZERO, "arming mouse during countdown cannot consume fuel or move the car")
	game.begin_playing()
	check(game._wants_thrust(), "mouse released and pressed again during countdown thrusts immediately after takeoff")
	Input.action_release("thrust_mouse")
	game.auto_simulation = false
	var player = game.player

	player.fuel = 100.0
	for frame in range(60):
		player.consume_fuel(1.0 / 60.0, true)
	var sixty: float = player.fuel
	player.fuel = 100.0
	for frame in range(120):
		player.consume_fuel(1.0 / 120.0, true)
	check(is_equal_approx(sixty, 90.0) and is_equal_approx(player.fuel, sixty), "thrust uses exactly 10 fuel/s at both 60 and 120 steps")
	player.fuel = 100.0
	player.consume_fuel(1.0, false)
	check(is_equal_approx(player.fuel, 99.0), "released thrust uses exactly 1 fuel/s")
	player.fuel = 0.01
	player.consume_fuel(1.0, true)
	check(player.fuel == 0.0, "fuel clamps to zero")
	player.velocity = Vector2.ZERO
	player.simulate(1.0 / 60.0, true)
	check(not player.thrusting and player.velocity.y > 0.0, "empty tank cannot thrust but continues falling")
	player.add_fuel(35.0)
	player.velocity = Vector2.ZERO
	player.simulate(1.0 / 60.0, true)
	check(player.thrusting and player.velocity.y < 0.0, "refueling restores upward thrust")
	player.add_fuel(1000.0)
	check(player.fuel == Balance.MAX_FUEL, "refill cannot exceed tank capacity")
	player.position.y = Balance.TOP_Y - 2.0
	player.velocity.y = -200.0
	player.simulate(1.0 / 60.0, true)
	check(player.position.y == Balance.TOP_Y and player.health == 3, "upper boundary clamps altitude without damage")

	await fresh_run()
	player = game.player
	var coin = game.director.spawn_pickup("coin", player.position)
	await settle_physics()
	check(game.coins == 1, "real Area2D coin contact awards one coin even with full fuel (got %d)" % game.coins)
	check(player.fuel == 100.0, "coin refill clamps at 100")
	if is_instance_valid(coin):
		check(not coin.try_collect(player), "a consumed pickup rejects a second collection")
	else:
		check(game.coins == 1, "collected coin is freed and cannot duplicate its award")
	player.fuel = 0.0
	var tank = game.director.spawn_pickup("tank", player.position)
	check(tank.visual.kind == "nitro", "tank uses the distinct nitro canister visual")
	await settle_physics()
	check(player.fuel == 35.0 and game.coins == 1, "real tank contact refuels an empty car by 35 without adding coins (fuel %.2f, coins %d)" % [player.fuel, game.coins])
	var electric = game.director.spawn_hazard(Vector2(1100, 180), Vector2(86, 96), "electric")
	check(electric.visual.kind == "energy_orb", "legacy electric spawn resolves to the city's energy orb")

	await fresh_run()
	player = game.player
	var hazard = game.director.spawn_hazard(player.position, Vector2(84, 96), "pillar")
	await settle_physics()
	check(player.health == 2, "real Area2D obstacle contact costs one life")
	player.protection_left = 0.0
	await settle_physics()
	check(player.health == 2, "continued overlap never costs another life after protection ends")
	hazard.position.x = 900.0
	await settle_physics()
	hazard.position = player.position
	await settle_physics()
	check(player.health == 1, "leaving and contacting again can cause new damage")
	var fuel_before_ground: float = player.fuel
	player.hit_ground()
	check(player.health == 0 and player.fuel == fuel_before_ground, "ground damage bypasses protection without granting fuel")
	check(game.state == game.RunState.RESULT and game.finish_count == 1, "zero health concludes a run once")
	game.finish_run()
	player.take_damage("test", true)
	check(game.finish_count == 1, "repeated death callbacks cannot repeat settlement")
	var result_coins: int = game.coins
	game._on_pickup(null, "coin")
	check(game.coins == result_coins, "result state rejects pickup rewards")

	await fresh_run()
	player = game.player
	player.fuel = 70.0
	player.hit_ground()
	check(player.health == 2 and player.position.y == Balance.RESCUE_Y and player.velocity.y == 0.0, "surviving a fall rescues the car to safe height with zero vertical velocity")
	check(player.fuel == 70.0, "fall rescue with remaining nitro does not replenish fuel")
	game.simulate_step(1.0 / 60.0, true)
	game.pause_run()
	var snapshot := [player.position, player.fuel, game.distance, game.elapsed, game.director.run_clock]
	for frame in range(8):
		game.simulate_step(0.25, true)
		await physics_frame
	check(snapshot == [player.position, player.fuel, game.distance, game.elapsed, game.director.run_clock], "pause freezes position, fuel, distance, difficulty, and spawn time")
	check(paused, "pause uses SceneTree.paused")
	game.resume_run()
	check(not paused and game.state == game.RunState.PLAYING, "resume restores play and unpauses the world")
	game.coins = 8
	game.start_run()
	check(player.fuel == 100.0 and player.health == 3 and game.coins == 0 and game.distance == 0.0 and game.elapsed == 0.0, "retry resets all session resources and counters")
	check(player.position == Vector2(Balance.PLAYER_X, Balance.START_Y) and player.velocity == Vector2.ZERO, "retry resets car position and velocity")
	check(game.director.run_clock == 0.0 and not game.director.active, "retry resets route clock and waits for countdown")
	game.pause_run()
	game.resume_run()
	check(game.state == game.RunState.COUNTDOWN, "pausing during countdown resumes countdown")
	game.show_menu()
	check(not paused and game.state == game.RunState.MENU, "return to menu always unpauses the tree")
	paused = false
	game.queue_free()
	await process_frame
	# Give AudioServer a real mix interval to release stopped WAV playback.
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await process_frame
	print("SMOKE RESULT: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

