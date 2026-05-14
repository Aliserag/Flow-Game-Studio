extends Node
## Central logging singleton. Use instead of print().
## Levels: DEBUG, INFO, WARN, ERROR. Configurable via min_level.

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.INFO
var _entries: Array[Dictionary] = []
var _capture: bool = true
const MAX_CAPTURED_ENTRIES: int = 1000


func debug(msg: String, system: String = "") -> void:
	_log(Level.DEBUG, msg, system)


func info(msg: String, system: String = "") -> void:
	_log(Level.INFO, msg, system)


func warn(msg: String, system: String = "") -> void:
	_log(Level.WARN, msg, system)


func error(msg: String, system: String = "") -> void:
	_log(Level.ERROR, msg, system)


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate()


func clear() -> void:
	_entries.clear()


func _log(level: Level, msg: String, system: String) -> void:
	if level < min_level:
		return
	var tag := _level_tag(level)
	var prefix := "[%s]" % tag if system.is_empty() else "[%s][%s]" % [tag, system]
	var line := "%s %s" % [prefix, msg]
	print(line)
	if _capture:
		_entries.append({
			"level": level,
			"system": system,
			"msg": msg,
			"line": line,
		})
		if _entries.size() > MAX_CAPTURED_ENTRIES:
			_entries.pop_front()


func _level_tag(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		_: return "?"
