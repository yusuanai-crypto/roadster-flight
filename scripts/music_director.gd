extends Node
## Scene soundtrack owner. Muting, pausing and changing scenes preserve independent state.

const MUSIC_PATHS: Dictionary = {
	"city": "res://assets/music/city.wav",
	"desert": "res://assets/music/desert.wav",
	"sky": "res://assets/music/sky.wav",
	"underwater": "res://assets/music/underwater.wav",
}
const MODE_VOLUMES: Dictionary = {
	"menu": -20.0,
	"countdown": -17.0,
	"playing": -16.0,
	"paused": -16.0,
	"result": -20.0,
}
const SILENT_DB: float = -80.0
const FADE_SECONDS: float = 0.28

var _player: AudioStreamPlayer
var _theme: String = "city"
var _mode: String = "menu"
var _muted: bool = false
var _fade: Tween
var _shut_down: bool = false

func _ready() -> void:
	# AudioStreamPlayer's stream_paused resumes its current playback; ALWAYS prevents
	# SceneTree pause from overriding our explicit pause/resume state.
	# https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html#class-audiostreamplayer-property-stream-paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "SceneMusic"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = SILENT_DB
	add_child(_player)
	_load_theme()

func set_theme(theme_id: String) -> void:
	if _shut_down:
		return
	var next_theme: String = theme_id if MUSIC_PATHS.has(theme_id) else "city"
	if next_theme == _theme and _player != null and _player.stream != null:
		return
	_theme = next_theme
	if _player != null:
		_load_theme()

func set_mode(mode: String) -> void:
	if _shut_down or not MODE_VOLUMES.has(mode):
		return
	_mode = mode
	if _player == null:
		return
	# Do not call play() when resuming: stream_paused retains the current position.
	_player.stream_paused = _mode == "paused"
	_fade_to_target()

func set_muted(muted: bool) -> void:
	if _shut_down:
		return
	_muted = muted
	if _player != null:
		_fade_to_target()

func is_muted() -> bool:
	return _muted

func _load_theme() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var stream: AudioStreamWAV = load(MUSIC_PATHS[_theme]) as AudioStreamWAV
	if stream == null:
		push_error("Scene music could not be loaded: %s" % MUSIC_PATHS[_theme])
		return
	# Loop markers use sample frames (not interleaved stereo sample count).
	# https://docs.godotengine.org/en/4.7/classes/class_audiostreamwav.html#class-audiostreamwav-property-loop-end
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()
	_player.stream_paused = _mode == "paused"
	_fade_to_target()

func _fade_to_target() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var target_db: float = SILENT_DB if _muted else float(MODE_VOLUMES[_mode])
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_player, "volume_db", target_db, FADE_SECONDS)

func shutdown() -> void:
	# Release playback before the audio server shuts down. Headless and fast QA
	# runs otherwise retain the active WAV playback until the next audio mix.
	if _shut_down:
		return
	_shut_down = true
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null

func _exit_tree() -> void:
	shutdown()
