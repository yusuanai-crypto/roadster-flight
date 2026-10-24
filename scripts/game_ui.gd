extends CanvasLayer
## Presentation only: emits intent and displays the controller's live state.

signal start_requested
signal pause_requested
signal resume_requested
signal retry_requested
signal menu_requested
signal quit_requested
signal theme_requested(theme_id: String)
signal music_requested

const INK := Color("eef7ff")
const MUTED := Color("8798b6")
const CYAN := Color("55e6ff")
const GOLD := Color("ffc86b")
const RED := Color("ff587b")
const PANEL := Color("101b31")
const THEME_NAMES := {"city": "霓虹城市", "desert": "沙漠", "sky": "天空", "underwater": "海底"}
const THEME_ORDER := ["city", "desert", "sky", "underwater"]
const PREVIEWS := {
	"city": preload("res://assets/previews/city.png"),
	"desert": preload("res://assets/previews/desert.png"),
	"sky": preload("res://assets/previews/sky.png"),
	"underwater": preload("res://assets/previews/underwater.png")
}
const HEART_FULL = preload("res://assets/ui/heart-full.svg")
const HEART_EMPTY = preload("res://assets/ui/heart-empty.svg")
const SPEAKER_ON = preload("res://assets/ui/speaker-on.svg")
const SPEAKER_MUTED = preload("res://assets/ui/speaker-muted.svg")
const COIN_ICON = preload("res://assets/ui/coin.svg")
const PREVIEW_LEFT := Rect2(0, 70, 136, 288)
const PREVIEW_CENTRE := Rect2(166, 0, 900, 424)
const PREVIEW_RIGHT := Rect2(1096, 70, 136, 288)
const PREVIEW_DIM := Color(0.65, 0.73, 0.85, 0.6)
const CAROUSEL_SECONDS := 0.38

var root_control: Control
var menu: Control
var hud: Control
var countdown: Control
var pause_menu: Control
var result: Control
var fuel_bar: ProgressBar
var fuel_caption: Label
var health_icons: Array[TextureRect] = []
var coin_label: Label
var distance_label: Label
var best_label: Label
var countdown_label: Label
var notice_label: Label
var result_distance: Label
var result_coins: Label
var record_notice: Label
var preview_image: TextureRect
var previous_preview: TextureRect
var next_preview: TextureRect
var preview_track: Control
var carousel_tween: Tween
var displayed_theme: String = "city"
var preview_name: Label
var preview_index: Label
var previous_name: Label
var next_name: Label
var pause_button: Button
var theme_buttons: Dictionary = {}
var music_buttons: Array[Button] = []
var selected_theme: String = "city"
var buttons: Array[Button] = []
var toast_left: float = 0.0
var ui_font: SystemFont
var ui_font_bold: SystemFont

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial"])
	ui_font_bold = SystemFont.new()
	ui_font_bold.font_names = ui_font.font_names
	ui_font_bold.font_weight = 700
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = Theme.new()
	root_control.theme.default_font = ui_font
	root_control.theme.default_font_size = 18
	add_child(root_control)
	_build_menu()
	_build_hud()
	_build_countdown()
	_build_pause()
	_build_result()
	show_screen("menu")

func _make_root() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(control)
	return control

func _label(parent: Control, value: String, rect: Rect2, size: int, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", ui_font_bold if bold else ui_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel(parent: Control, rect: Rect2, color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 16) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _button(parent: Control, title: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", ui_font_bold)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("071321") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("071321") if primary else CYAN)
	button.add_theme_color_override("font_pressed_color", Color("071321") if primary else CYAN)
	for variant in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = CYAN if primary else Color("17273e")
		if variant == "hover":
			style.bg_color = Color("a1f2ff") if primary else Color("223b55")
		elif variant == "pressed":
			style.bg_color = Color("30b9d5") if primary else Color("102031")
		style.border_color = CYAN if primary else Color("36526c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(variant, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons.append(button)
	return button

func _build_menu() -> void:
	menu = _make_root()
	_panel(menu, Rect2(0, 0, 1280, 720), Color("080f20"), Color.TRANSPARENT, 0)
	var title := _texture(menu, preload("res://assets/ui/title-brush.png"), Rect2(42, 16, 320, 108))
	title.name = "氮气飞驰"
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_music_button(menu, Rect2(1176, 42, 56, 50))
	_panel(menu, Rect2(182, 134, 916, 440), Color("14283b"), Color("3c8294"), 14)
	# One clipped track lets all three cards slide and resize continuously.
	preview_track = Control.new()
	preview_track.position = Vector2(24, 142)
	preview_track.size = Vector2(1232, 424)
	preview_track.clip_contents = true
	preview_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(preview_track)
	previous_name = _label(menu, "", Rect2(24, 510, 136, 30), 17, MUTED, true)
	previous_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_name = _label(menu, "", Rect2(1120, 510, 136, 30), 17, MUTED, true)
	next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel(menu, Rect2(190, 480, 900, 86), Color(0.02, 0.05, 0.1, 0.82), Color.TRANSPARENT, 0)
	preview_name = _label(menu, "霓虹城市", Rect2(219, 500, 620, 45), 30, INK, true)
	preview_index = _label(menu, "01 / 04", Rect2(960, 510, 104, 30), 16, CYAN, true)
	_reset_carousel("city")
	_button(menu, "‹", Rect2(61, 329, 62, 62), cycle_theme.bind(-1)).add_theme_font_size_override("font_size", 40)
	_button(menu, "›", Rect2(1157, 329, 62, 62), cycle_theme.bind(1)).add_theme_font_size_override("font_size", 40)
	var index := 0
	for theme_id: String in THEME_ORDER:
		var button := _button(menu, THEME_NAMES[theme_id], Rect2(388 + index * 128, 592, 120, 38), _on_theme.bind(theme_id))
		button.add_theme_font_size_override("font_size", 16)
		theme_buttons[theme_id] = button
		index += 1
	_button(menu, "开始飞行    →", Rect2(452, 650, 260, 52), _on_start, true)
	_button(menu, "退出", Rect2(730, 650, 96, 52), _on_quit)
	_label(menu, "最高距离", Rect2(48, 655, 100, 26), 14, MUTED)
	best_label = _label(menu, "0 m", Rect2(149, 650, 220, 38), 22, INK, true)

func _texture(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = texture
	picture.position = rect.position
	picture.size = rect.size
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(picture)
	return picture

func cycle_theme(direction: int) -> void:
	var index := THEME_ORDER.find(selected_theme)
	_on_theme(THEME_ORDER[posmod(index + direction, THEME_ORDER.size())])

func _build_hud() -> void:
	hud = _make_root()
	_panel(hud, Rect2(24, 22, 1232, 88), Color(0.035, 0.065, 0.125, 0.92), Color("253e56"), 14)
	fuel_bar = ProgressBar.new()
	fuel_bar.position = Vector2(52, 50)
	fuel_bar.size = Vector2(340, 32)
	fuel_bar.max_value = 100.0
	fuel_bar.value = 100.0
	fuel_bar.show_percentage = false
	fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("24344b")
	empty.set_corner_radius_all(5)
	fuel_bar.add_theme_stylebox_override("background", empty)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.set_corner_radius_all(5)
	fuel_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(fuel_bar)
	fuel_caption = _label(fuel_bar, "N₂", Rect2(14, 0, 50, 32), 21, Color("081629"), true)
	fuel_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for index in range(3):
		var heart := _texture(hud, HEART_FULL, Rect2(441 + index * 38, 52, 28, 29))
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		health_icons.append(heart)
	_texture(hud, COIN_ICON, Rect2(623, 48, 36, 36)).name = "CoinIcon"
	coin_label = _label(hud, "000", Rect2(671, 47, 105, 38), 24, GOLD, true)
	distance_label = _label(hud, "0 m", Rect2(800, 47, 220, 38), 24, INK, true)
	_music_button(hud, Rect2(1054, 40, 56, 50))
	pause_button = _button(hud, "暂停", Rect2(1124, 40, 110, 50), _on_pause)
	pause_button.icon = preload("res://assets/ui/triangle.svg")
	pause_button.add_theme_constant_override("h_separation", 10)
	notice_label = _label(hud, "", Rect2(316, 151, 650, 42), 20, CYAN, true)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_countdown() -> void:
	countdown = _make_root()
	_panel(countdown, Rect2(457, 233, 366, 221), Color(0.04, 0.085, 0.15, 0.9), Color("315b70"), 20)
	_label(countdown, "准备起飞", Rect2(460, 253, 360, 42), 25, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label = _label(countdown, "3", Rect2(460, 289, 360, 103), 70, CYAN, true)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(countdown, "按住上升  ·  松开下落", Rect2(460, 408, 360, 28), 17, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _scrim(parent: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.04, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)

func _build_pause() -> void:
	pause_menu = _make_root()
	_scrim(pause_menu)
	_panel(pause_menu, Rect2(399, 210, 482, 300), PANEL, Color("2b566d"), 20)
	_label(pause_menu, "暂时停靠", Rect2(435, 233, 330, 63), 40, INK, true)
	_music_button(pause_menu, Rect2(787, 240, 56, 50))
	_button(pause_menu, "继续飞行", Rect2(437, 318, 406, 58), _on_resume, true)
	_button(pause_menu, "重新开始", Rect2(437, 415, 193, 55), _on_retry)
	_button(pause_menu, "返回首页", Rect2(650, 415, 193, 55), _on_menu)

func _build_result() -> void:
	result = _make_root()
	_scrim(result)
	_panel(result, Rect2(364, 166, 552, 388), PANEL, Color("2c4b63"), 20)
	_label(result, "下一次，飞得更远", Rect2(404, 194, 480, 63), 37, INK, true)
	_panel(result, Rect2(406, 279, 226, 92), Color("152840"), Color("28475e"), 12)
	_panel(result, Rect2(649, 279, 226, 92), Color("152840"), Color("28475e"), 12)
	result_distance = _label(result, "0 m", Rect2(426, 301, 190, 46), 30, INK, true)
	_texture(result, COIN_ICON, Rect2(673, 306, 36, 36)).name = "CoinIcon"
	result_coins = _label(result, "0", Rect2(726, 301, 133, 46), 30, GOLD, true)
	record_notice = _label(result, "", Rect2(409, 389, 465, 28), 15, CYAN)
	_button(result, "再飞一次    →", Rect2(406, 447, 282, 60), _on_retry, true)
	_button(result, "返回首页", Rect2(708, 447, 166, 60), _on_menu)

func show_screen(screen: String) -> void:
	if screen != "menu":
		_reset_carousel(selected_theme)
	menu.visible = screen == "menu"
	hud.visible = screen in ["playing", "countdown", "paused", "result"]
	countdown.visible = screen == "countdown"
	pause_menu.visible = screen == "paused"
	result.visible = screen == "result"
	notice_label.visible = screen in ["playing", "countdown"]

func update_run(fuel: float, health: int, coins: int, distance: float, _clock: float) -> void:
	fuel_bar.value = fuel
	fuel_caption.add_theme_color_override("font_color", INK if fuel < 20.0 else Color("081629"))
	var fill := fuel_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = RED if fuel < 20.0 else CYAN
	for index in range(health_icons.size()):
		health_icons[index].texture = HEART_FULL if health > index else HEART_EMPTY
	coin_label.text = "%03d" % coins
	distance_label.text = "%d m" % floori(distance)
	if fuel <= 0.0:
		show_notice("氮气耗尽！滑行寻找补给", RED, 0.3)
	elif fuel < 20.0 and toast_left <= 0.0:
		show_notice("氮气不足 · 靠近蓝色氮气罐补给", GOLD, 0.3)

func set_countdown(seconds: float) -> void:
	countdown_label.text = str(ceili(seconds))

func set_best(distance: float) -> void:
	best_label.text = "%d m" % floori(distance)

func set_theme(theme_id: String) -> void:
	selected_theme = theme_id
	for candidate: String in theme_buttons:
		var button: Button = theme_buttons[candidate]
		var chosen := candidate == theme_id
		button.text = ("● " if chosen else "") + THEME_NAMES[candidate]
		button.add_theme_color_override("font_color", CYAN if chosen else INK)
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		style.border_color = CYAN if chosen else Color("36526c")
		style.bg_color = Color("1e4055") if chosen else Color("17273e")
	if not menu.visible:
		_reset_carousel(theme_id)
	elif carousel_tween == null:
		_animate_next_scene()

func _update_preview_copy(theme_id: String) -> void:
	var index := THEME_ORDER.find(theme_id)
	preview_name.text = THEME_NAMES[theme_id]
	preview_index.text = "%02d / 04" % (index + 1)
	previous_name.text = THEME_NAMES[THEME_ORDER[posmod(index - 1, 4)]]
	next_name.text = THEME_NAMES[THEME_ORDER[posmod(index + 1, 4)]]

func _reset_carousel(theme_id: String) -> void:
	if carousel_tween != null:
		carousel_tween.kill()
		carousel_tween = null
	for child in preview_track.get_children():
		preview_track.remove_child(child)
		child.queue_free()
	var index := THEME_ORDER.find(theme_id)
	previous_preview = _texture(preview_track, PREVIEWS[THEME_ORDER[posmod(index - 1, 4)]], PREVIEW_LEFT)
	preview_image = _texture(preview_track, PREVIEWS[theme_id], PREVIEW_CENTRE)
	next_preview = _texture(preview_track, PREVIEWS[THEME_ORDER[posmod(index + 1, 4)]], PREVIEW_RIGHT)
	previous_preview.modulate = PREVIEW_DIM
	next_preview.modulate = PREVIEW_DIM
	displayed_theme = theme_id
	_update_preview_copy(theme_id)

func _move_card(card: TextureRect, rect: Rect2, tint: Color) -> void:
	carousel_tween.tween_property(card, "position", rect.position, CAROUSEL_SECONDS)
	carousel_tween.tween_property(card, "size", rect.size, CAROUSEL_SECONDS)
	carousel_tween.tween_property(card, "modulate", tint, CAROUSEL_SECONDS)

func _animate_next_scene() -> void:
	if displayed_theme == selected_theme:
		return
	var index := THEME_ORDER.find(displayed_theme)
	var steps := posmod(THEME_ORDER.find(selected_theme) - index, 4)
	var direction := 1 if steps <= 2 else -1
	var destination: String = THEME_ORDER[posmod(index + direction, 4)]
	var incoming_theme: String = THEME_ORDER[posmod(index + direction * 2, 4)]
	var far_left := Rect2(-180, 120, 96, 184)
	var far_right := Rect2(1316, 120, 96, 184)
	var incoming := _texture(preview_track, PREVIEWS[incoming_theme], far_right if direction > 0 else far_left)
	incoming.modulate = Color(0.65, 0.73, 0.85, 0.0)
	var outgoing := previous_preview if direction > 0 else next_preview
	var old_centre := preview_image
	var new_centre := next_preview if direction > 0 else previous_preview
	carousel_tween = create_tween().set_parallel(true)
	carousel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_card(outgoing, far_left if direction > 0 else far_right, Color(0.65, 0.73, 0.85, 0.0))
	_move_card(old_centre, PREVIEW_LEFT if direction > 0 else PREVIEW_RIGHT, PREVIEW_DIM)
	_move_card(new_centre, PREVIEW_CENTRE, Color.WHITE)
	_move_card(incoming, PREVIEW_RIGHT if direction > 0 else PREVIEW_LEFT, PREVIEW_DIM)
	carousel_tween.chain().tween_callback(func() -> void:
		outgoing.queue_free()
		preview_image = new_centre
		previous_preview = old_centre if direction > 0 else incoming
		next_preview = incoming if direction > 0 else old_centre
		displayed_theme = destination
		_update_preview_copy(destination)
		carousel_tween = null
		# Rapid input changes the target; finish this movement before the next.
		_animate_next_scene()
	)

func _music_button(parent: Control, rect: Rect2) -> Button:
	var button := _button(parent, "", rect, _on_music)
	button.icon = SPEAKER_ON
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 28)
	button.tooltip_text = "关闭音乐（M）"
	music_buttons.append(button)
	return button

func set_music_muted(muted: bool) -> void:
	for button in music_buttons:
		button.icon = SPEAKER_MUTED if muted else SPEAKER_ON
		button.tooltip_text = "开启音乐（M）" if muted else "关闭音乐（M）"

func set_result(distance: float, coins: int, best: float, is_record: bool) -> void:
	result_distance.text = "%d m" % floori(distance)
	result_coins.text = str(coins)
	record_notice.text = "新纪录！你又向前飞了一程。" if is_record else "个人最高：%d m" % floori(best)

func show_notice(message: String, color: Color = CYAN, duration: float = 1.2) -> void:
	notice_label.text = message
	notice_label.add_theme_color_override("font_color", color)
	toast_left = duration

func advance(delta: float) -> void:
	toast_left = maxf(0.0, toast_left - delta)
	if toast_left == 0.0:
		notice_label.text = ""

func pointer_over_button() -> bool:
	var pointer := root_control.get_global_mouse_position()
	for button in buttons:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pointer):
			return true
	return false

func clear_notices() -> void:
	toast_left = 0.0
	notice_label.text = ""

func _on_start() -> void:
	start_requested.emit()
func _on_pause() -> void:
	pause_requested.emit()
func _on_resume() -> void:
	resume_requested.emit()
func _on_retry() -> void:
	retry_requested.emit()
func _on_menu() -> void:
	menu_requested.emit()
func _on_quit() -> void:
	quit_requested.emit()
func _on_theme(theme_id: String) -> void:
	theme_requested.emit(theme_id)
func _on_music() -> void:
	music_requested.emit()

