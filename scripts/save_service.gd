extends RefCounted
## Prototype records only; coins/upgrades intentionally wait for the next phase.
## ConfigFile requires save() after set_value() and persistent data uses user://.
## https://docs.godotengine.org/en/stable/classes/class_configfile.html

var path: String = "user://prototype.cfg"
var best_distance: float = 0.0
var enabled: bool = true

func load_record() -> void:
	if not enabled:
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var value: Variant = config.get_value("records", "best_distance", 0.0)
	if (value is float or value is int) and is_finite(float(value)):
		best_distance = clampf(float(value), 0.0, 10000000.0)

func record(distance: float) -> bool:
	if distance <= best_distance:
		return false
	best_distance = distance
	if enabled:
		var config := ConfigFile.new()
		config.set_value("records", "best_distance", best_distance)
		var result := config.save(path)
		if result != OK:
			push_warning("最高纪录保存失败：%s" % error_string(result))
	return true
