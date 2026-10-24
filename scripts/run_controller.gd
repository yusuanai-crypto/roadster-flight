extends Node2D
## The single owner of session state. Only PLAYING advances the simulation.

signal state_changed(state_name: String)
signal run_finished(distance_meters: float, coins_collected: int)

const Balance = preload("res://scripts/game_balance.gd")
const FlightScript = preload("res://scripts/flight_controller.gd")
const DirectorScript = preload("res://scripts/spawn_director.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const SaveScript = preload("res://scripts/save_service.gd")
const MusicScript = preload("res://scripts/music_director.gd")
const THEMES := ["city", "desert", "sky", "underwater"]

enum RunState { MENU, COUNTDOWN, PLAYING, PAUSED, RESULT }

var state: RunState = RunState.MENU
var paused_from: RunState = RunState.PLAYING
var elapsed: float = 0.0
var travel: float = 0.0
var distance: float = 0.0
var coins: int = 0
var countdown_left: float = 0.0
var finish_count: int = 0
var last_damage_cause: String = "碰撞障碍"
var input_armed: bool = false
var test_mode: bool = false
var auto_simulation: bool = true
var selected_theme: String = "city"
var current_speed: float = Balance.START_SPEED
var world: Node2D
var background: Node2D
var player: CharacterBody2D
var director: Node2D
var ui: CanvasLayer
var save_service: RefCounted
var music: Node
var _quitting: bool = false
var _windowed_mode: int = DisplayServer.WINDOW_MODE_WINDOWED

func _ready() -> void:
	# Controller/UI keep processing while the SceneTree's world is paused.
	# https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Route the title-bar close request through the same audio cleanup as Exit.
	# https://docs.godotengine.org/en/4.7/tutorials/inputs/handling_quit_requests.html
	get_tree().auto_accept_quit = false
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	background = load("res://visuals/city_background.gd").new()
	world.add_child(background)
	director = DirectorScript.new()
	director.name = "SpawnDirector"
	world.add_child(director)
	player = FlightScript.new()
	player.name = "Roadster"
	world.add_child(player)
	ui = UIScript.new()
	add_child(ui)
	music = MusicScript.new()
	music.name = "MusicDirector"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	save_service = SaveScript.new()
	save_service.enabled = not test_mode
	save_service.load_record()
	ui.start_requested.connect(start_run)
	ui.pause_requested.connect(pause_run)
	ui.resume_requested.connect(resume_run)
	ui.retry_requested.connect(start_run)
	ui.menu_requested.connect(show_menu)
	ui.quit_requested.connect(_quit)
	ui.theme_requested.connect(select_theme)
	ui.music_requested.connect(toggle_music)
	player.damaged.connect(_on_damaged)
	player.rescued.connect(_on_rescued)
	player.died.connect(finish_run)
	director.pickup_collected.connect(_on_pickup)
	director.hazard_contacted.connect(_on_hazard_contact)
	director.hazard_separated.connect(_on_hazard_separation)
	show_menu()

func select_theme(theme_id: String) -> void:
	if state != RunState.MENU or theme_id not in THEMES:
		return
	selected_theme = theme_id
	_apply_theme()
	# The UI animates the selected preview without starting a run.
	background.queue_redraw()

func _apply_theme() -> void:
	background.set("theme_id", selected_theme)
	director.theme_id = selected_theme
	music.set_theme(selected_theme)
	ui.set_theme(selected_theme)

func toggle_music() -> void:
	music.set_muted(not music.is_muted())
	ui.set_music_muted(music.is_muted())

func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen:
		DisplayServer.window_set_mode(_windowed_mode)
	else:
		_windowed_mode = mode
		# Exclusive fullscreen covers every monitor pixel, including the taskbar.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func show_menu() -> void:
	get_tree().paused = false
	state = RunState.MENU
	_apply_theme()
	music.set_mode("menu")
	ui.set_music_muted(music.is_muted())
	input_armed = false
	director.reset_route()
	player.reset_flight()
	player.hide()
	player.position = Vector2(953.0, 364.0)
	player.scale = Vector2(2.45, 2.45)
	player.visual.set("thrusting", true)
	background.set("travel", 0.0)
	background.set("clock", 0.0)
	background.queue_redraw()
	ui.show_screen("menu")
	ui.set_best(save_service.best_distance)
	state_changed.emit("menu")

func start_run() -> void:
	get_tree().paused = false
	_apply_theme()
	director.reset_route()
	player.show()
	player.scale = Vector2.ONE
	player.reset_flight()
	elapsed = 0.0
	current_speed = Balance.speed_at(0.0)
	travel = 0.0
	distance = 0.0
	coins = 0
	finish_count = 0
	countdown_left = Balance.COUNTDOWN_SECONDS
	last_damage_cause = "碰撞障碍"
	input_armed = false
	state = RunState.COUNTDOWN
	music.set_mode("countdown")
	ui.clear_notices()
	ui.show_screen("countdown")
	ui.set_countdown(countdown_left)
	_update_view()
	state_changed.emit("countdown")

func begin_playing() -> void:
	if state != RunState.COUNTDOWN:
		return
	countdown_left = 0.0
	state = RunState.PLAYING
	music.set_mode("playing")
	director.set_active(true)
	ui.show_screen("playing")
	ui.show_notice("开始飞行！沿金币路线寻找补给", ui.CYAN, 2.5)
	state_changed.emit("playing")

func _physics_process(delta: float) -> void:
	if _quitting or not auto_simulation:
		return
	if state == RunState.COUNTDOWN:
		# Record mouse releases during the countdown without applying any
		# movement. A new press before GO must still work on the first tick.
		_wants_thrust()
		countdown_left = maxf(0.0, countdown_left - delta)
		ui.set_countdown(countdown_left)
		if countdown_left <= 0.0:
			begin_playing()
	elif state == RunState.PLAYING:
		simulate_step(delta, _wants_thrust())

func simulate_step(delta: float, thrust_requested: bool) -> void:
	if _quitting or state != RunState.PLAYING:
		return
	current_speed = Balance.speed_at(elapsed)
	elapsed += delta
	travel += current_speed * delta
	distance = travel * Balance.METERS_PER_PIXEL
	player.simulate(delta, thrust_requested)
	if state != RunState.PLAYING:
		_update_view()
		return
	director.advance(delta, current_speed)
	ui.advance(delta)
	_update_view()

func _wants_thrust() -> bool:
	var keyboard := Input.is_action_pressed("thrust_keyboard")
	var mouse := Input.is_action_pressed("thrust_mouse")
	# Space may already be held during the countdown. Mouse is separately
	# armed after release so starting/resuming with a button never boosts.
	if not mouse:
		input_armed = true
	return keyboard or (input_armed and mouse and not ui.pointer_over_button())

func pause_run() -> void:
	if state not in [RunState.PLAYING, RunState.COUNTDOWN]:
		return
	paused_from = state
	state = RunState.PAUSED
	music.set_mode("paused")
	player.thrusting = false
	player.update_visual()
	input_armed = false
	get_tree().paused = true
	ui.show_screen("paused")
	state_changed.emit("paused")

func resume_run() -> void:
	if state != RunState.PAUSED:
		return
	get_tree().paused = false
	state = paused_from
	music.set_mode("countdown" if state == RunState.COUNTDOWN else "playing")
	input_armed = false
	ui.show_screen("countdown" if state == RunState.COUNTDOWN else "playing")
	state_changed.emit("countdown" if state == RunState.COUNTDOWN else "playing")

func finish_run() -> void:
	if state != RunState.PLAYING:
		return
	state = RunState.RESULT
	music.set_mode("result")
	finish_count += 1
	director.set_active(false)
	player.thrusting = false
	player.update_visual()
	var new_record: bool = save_service.record(distance)
	ui.set_result(distance, coins, save_service.best_distance, new_record)
	ui.show_screen("result")
	run_finished.emit(distance, coins)
	state_changed.emit("result")

func _on_pickup(_pickup: Area2D, kind: String) -> void:
	if state != RunState.PLAYING:
		return
	if kind == "coin":
		coins += 1
		player.add_fuel(Balance.COIN_FUEL)
	else:
		player.add_fuel(Balance.TANK_FUEL)
		ui.show_notice("氮气补充 +35", ui.CYAN, 1.0)
	_update_view()

func _on_hazard_contact(hazard: Area2D, body: Node2D) -> void:
	if state == RunState.PLAYING and body == player:
		player.enter_hazard(hazard.get_instance_id())

func _on_hazard_separation(hazard: Area2D, body: Node2D) -> void:
	if body == player:
		player.leave_hazard(hazard.get_instance_id())

func _on_damaged(_health: int, cause: String) -> void:
	last_damage_cause = cause
	ui.show_notice("%s · 生命 -1" % cause, ui.RED, 1.4)

func _on_rescued(refueled: bool) -> void:
	ui.show_notice("救援成功 · 氮气已恢复至 50%" if refueled else "救援成功 · 继续飞行", ui.CYAN, 2.0)

func _update_view() -> void:
	background.set("travel", travel)
	background.set("clock", elapsed)
	background.queue_redraw()
	player.update_visual()
	ui.update_run(player.fuel, player.health, coins, distance, elapsed)

func _unhandled_key_input(event: InputEvent) -> void:
	if _quitting or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif state == RunState.MENU and event.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		ui.cycle_theme(-1 if event.physical_keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE:
		if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			toggle_fullscreen()
		elif state == RunState.PAUSED:
			resume_run()
		else:
			pause_run()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_R and state in [RunState.PAUSED, RunState.RESULT]:
		start_run()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and state == RunState.MENU:
		start_run()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_M:
		toggle_music()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()
	elif not _quitting and what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(ui) and not test_mode:
		pause_run()

func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	auto_simulation = false
	get_tree().paused = false
	if is_instance_valid(director):
		director.set_active(false)
	if is_instance_valid(ui):
		for button: Button in ui.buttons:
			button.disabled = true
	if is_instance_valid(music):
		music.shutdown()
	# AudioServer frees its stopped playback on a later mix. Pump real frames
	# before quitting, including when a paused window is closed or Exit repeats.
	var audio_cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_cleanup_until:
		await get_tree().process_frame
	get_tree().quit()
