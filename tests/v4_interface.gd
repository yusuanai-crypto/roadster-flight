extends SceneTree
## Real Windows regression for startup fullscreen and the revised interface.

const AppScene = preload("res://scenes/app.tscn")
var capture_root := "res://builds/qa/v4"
var game
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_root = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(capture_root)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_root.path_join(label + ".png"))

func await_carousel() -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while game.ui.carousel_tween != null and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()

func all_copy(node: Node) -> String:
	var copy := ""
	if node is Label or node is Button:
		copy += node.text + "\n"
	for child in node.get_children():
		copy += all_copy(child)
	return copy

func check_fill(label: String) -> void:
	await settle()
	var pixels := root.get_texture().get_image()
	var expected := Color("080f20")
	var filled := true
	for point in [Vector2i(3, 3), Vector2i(pixels.get_width() - 4, 3), Vector2i(3, pixels.get_height() - 4), Vector2i(pixels.get_width() - 4, pixels.get_height() - 4)]:
		var actual := pixels.get_pixelv(point)
		filled = filled and absf(actual.r - expected.r) < 0.01 and absf(actual.g - expected.g) < 0.01 and absf(actual.b - expected.b) < 0.01
	check(filled, "%s fills every corner without letterboxing (%s)" % [label, pixels.get_size()])
	pixels.save_png(capture_root.path_join(label + ".png"))

func check_carousel() -> void:
	var old_centre: TextureRect = game.ui.preview_image
	var incoming: TextureRect = game.ui.next_preview
	game.ui.cycle_theme(1)
	check(game.ui.carousel_tween != null and game.ui.preview_image == old_centre, "right navigation begins an animation instead of replacing the image")
	await create_timer(0.17).timeout
	check(old_centre.position.x < 166 and old_centre.position.x > 0 and incoming.position.x > 166 and incoming.position.x < 1096, "both scene cards occupy intermediate horizontal positions")
	check(old_centre.size.x < 900 and old_centre.size.x > 136 and incoming.size.x > 136 and incoming.size.x < 900, "scene cards smoothly grow and shrink during navigation")
	await capture("carousel-right-midpoint")
	await await_carousel()
	check(game.selected_theme == "desert" and game.ui.preview_image == incoming and game.ui.displayed_theme == "desert", "right animation ends on the selected desert card")
	check(game.ui.preview_image.position == Vector2(166, 0) and game.ui.preview_image.size == Vector2(900, 424), "finished card returns to the exact centre layout")
	old_centre = game.ui.preview_image
	game.ui.cycle_theme(-1)
	await create_timer(0.17).timeout
	check(old_centre.position.x > 166 and old_centre.position.x < 1096, "left navigation visibly moves the old card to the right")
	await capture("carousel-left-midpoint")
	await await_carousel()
	for theme_id: String in game.THEMES:
		game.ui.theme_buttons[theme_id].pressed.emit()
		await await_carousel()
		check(game.selected_theme == theme_id and game.ui.preview_image.texture == game.ui.PREVIEWS[theme_id], "%s button animates to the matching real scene" % theme_id)
		check(game.ui.preview_track.get_child_count() == 3, "%s transition leaves exactly three preview cards" % theme_id)
	await press_key(KEY_RIGHT)
	await await_carousel()
	check(game.selected_theme == "city", "right keyboard navigation wraps from underwater to city")
	await press_key(KEY_LEFT)
	await await_carousel()
	check(game.selected_theme == "underwater", "left keyboard navigation wraps from city to underwater")
	game.ui.cycle_theme(1)
	await create_timer(0.05).timeout
	game.ui.cycle_theme(1)
	game.ui.cycle_theme(1)
	game.ui.cycle_theme(-1)
	await await_carousel()
	check(game.selected_theme == "desert" and game.ui.displayed_theme == "desert" and game.ui.preview_name.text == "沙漠", "rapid direction changes finish on the most recent selection")
	check(game.ui.preview_track.get_child_count() == 3, "rapid navigation does not accumulate offscreen cards")
	game.select_theme("sky")
	game.start_run()
	check(game.ui.carousel_tween == null and game.selected_theme == "sky" and game.ui.displayed_theme == "sky", "starting during a slide uses the latest scene and finishes the hidden carousel")
	game.show_menu()
	game.select_theme("city")
	await await_carousel()

func check_icons_and_copy() -> void:
	var copy := all_copy(game.ui.menu) + all_copy(game.ui.hud) + all_copy(game.ui.pause_menu) + all_copy(game.ui.result)
	var removed := true
	for fragment in ["RUN COMPLETE", "生命耗尽", "再来挑战", "飞行距离", "本局金币", "R 快速重试", "金币补气", "氮气罐补气", "音乐：", "全屏", "/ 100", "生命", "氮气", "ROADSTER", "WINDOWS", "自由飞行", "让每一罐", "驾驭银色", "电子脉冲", "前 10 秒", "航速", "FLIGHT LAB", "FLIGHT PAUSED", "调整一下呼吸", "ESC 继续", "飞行原型 v0.2", "按住 空格", "选择飞行场景"]:
		# The title artwork is an image; low-fuel notices are not active here.
		removed = removed and not copy.contains(fragment)
	check(removed, "all screenshot red-box text and fullscreen/music text buttons are removed")
	check(game.ui.fuel_caption.get_parent() == game.ui.fuel_bar and game.ui.fuel_caption.text == "N₂", "N2 is a child label inside the progress bar")
	check(Rect2(Vector2.ZERO, game.ui.fuel_bar.size).encloses(Rect2(game.ui.fuel_caption.position, game.ui.fuel_caption.size)), "the full N2 caption fits within the nitro bar")
	for fuel: float in [100.0, 50.0, 10.0, 0.0]:
		game.ui.update_run(fuel, 3, 10, 184, 0)
		check(game.ui.fuel_bar.value == fuel and game.ui.fuel_caption.text == "N₂", "%.0f nitro keeps the meter and embedded caption readable" % fuel)
	game.ui.clear_notices()
	check(game.ui.hud.get_node("CoinIcon").texture == game.ui.COIN_ICON and game.ui.result.get_node("CoinIcon").texture == game.ui.COIN_ICON, "flight and settlement each show the gold coin icon")
	for health in range(4):
		game.ui.update_run(100, health, 0, 0, 0)
		var full := 0
		for heart in game.ui.health_icons:
			if heart.texture == game.ui.HEART_FULL:
				full += 1
		check(full == health, "%d health displays exactly %d full heart icons" % [health, health])
	check(game.ui.pause_button.icon.resource_path.ends_with("triangle.svg"), "pause retains the triangle icon")
	var title: TextureRect = game.ui.menu.get_node("氮气飞驰")
	check(title.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "brush title keeps its transparent background")
	game.ui.music_buttons[0].pressed.emit()
	var synchronized: bool = game.music.is_muted()
	for button in game.ui.music_buttons:
		synchronized = synchronized and button.text.is_empty() and button.icon == game.ui.SPEAKER_MUTED
	check(synchronized, "clicking the menu speaker mutes audio and updates all three icons")
	await press_key(KEY_M)
	synchronized = not game.music.is_muted()
	for button in game.ui.music_buttons:
		synchronized = synchronized and button.text.is_empty() and button.icon == game.ui.SPEAKER_ON
	check(synchronized, "M restores audio and all three sound-on icons")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(capture_root)
	game = AppScene.instantiate()
	game.test_mode = true
	game.auto_simulation = false
	root.add_child(game)
	await settle()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "startup enters exclusive fullscreen without a click")
	check(root.size == DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()), "startup covers the entire monitor including title bar and taskbar areas")
	await check_fill("menu-fullscreen")
	await press_key(KEY_ESCAPE)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and game.state == game.RunState.MENU, "Esc leaves fullscreen and keeps the menu active")
	root.size = Vector2i(1280, 720)
	await settle()
	await check_carousel()
	await check_icons_and_copy()
	root.size = Vector2i(1280, 800)
	await check_fill("menu-16x10")
	root.size = Vector2i(1600, 720)
	await check_fill("menu-wide")
	root.size = Vector2i(1280, 720)
	await press_key(KEY_F11)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "F11 still allows returning to monitor fullscreen")
	game.start_run()
	await physics_frame
	await physics_frame
	game.begin_playing()
	await press_key(KEY_ESCAPE)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and game.state == game.RunState.PLAYING, "in-flight Esc exits fullscreen before handling pause")
	await press_key(KEY_ESCAPE)
	check(game.state == game.RunState.PAUSED and paused, "windowed Esc pauses the simulation")
	await press_key(KEY_F11)
	await press_key(KEY_ESCAPE)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and game.state == game.RunState.PAUSED and paused, "Esc can leave fullscreen while paused without resuming the world")
	await press_key(KEY_ESCAPE)
	check(game.state == game.RunState.PLAYING and not paused, "windowed Esc resumes a paused flight")
	game.ui.pause_button.pressed.emit()
	check(game.state == game.RunState.PAUSED and paused, "triangle button pauses the actual simulation")
	game.resume_run()
	game.ui.cycle_theme(1)
	await press_key(KEY_LEFT)
	check(game.selected_theme == "city", "scene selection stays locked during a flight")
	game.distance = 261
	game.coins = 10
	game.finish_run()
	check(game.ui.result_distance.text == "261 m" and game.ui.result_coins.text == "10", "clean settlement retains the actual distance and coin totals")
	check(not game.ui.notice_label.visible, "settlement hides flight notices behind the modal")
	await capture("result-clean")
	game.queue_free()
	await process_frame
	var cleanup_until := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < cleanup_until:
		await process_frame
	print("V4 INTERFACE RESULT: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
