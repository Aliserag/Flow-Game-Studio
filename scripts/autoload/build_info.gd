extends Node

# Stamps the build version + commit (when available) into the window title and
# surfaces them via static-readable fields for save files, credits screen, and
# error reports.

var version: String = ""
var commit: String = ""
var build_id: String = ""

func _ready() -> void:
	version = String(ProjectSettings.get_setting("application/config/version", "0.0.0-dev"))
	commit = _read_commit_hash()
	build_id = "v%s%s" % [version, (" (" + commit + ")") if commit != "" else ""]
	# Append the build_id to the window title at boot.
	var base_title: String = String(ProjectSettings.get_setting("application/config/name", "Game"))
	DisplayServer.window_set_title("%s — %s" % [base_title, build_id])

func _read_commit_hash() -> String:
	# Tries res://BUILD_COMMIT (a file the Makefile writes pre-export); falls back to empty.
	if not FileAccess.file_exists("res://BUILD_COMMIT"):
		return ""
	var f := FileAccess.open("res://BUILD_COMMIT", FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text().strip_edges()
	f.close()
	# Truncate to 7 chars (short commit).
	return s.substr(0, 7) if s.length() >= 7 else s
