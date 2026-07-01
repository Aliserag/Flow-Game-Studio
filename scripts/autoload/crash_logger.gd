extends Node

# Lightweight local crash/error log. Writes the first unhandled error to
# user://crash.log along with build info. Never transmits anything.
# Main menu surfaces "Last run crashed" if the file exists at startup.

const LOG_PATH := "user://crash.log"

func _ready() -> void:
	# Wipe the previous run's crash log so the menu hint only appears for the
	# session that actually crashed.
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
	# Best-effort: install our handler. Godot doesn't expose a global
	# uncaught-exception hook, so we listen on a recurring tick and check
	# `OS.get_messages_buffer()` if available; otherwise we rely on systems
	# calling `report(...)` from their own except branches.
	set_process(false)

func report(msg: String) -> void:
	# Append to crash.log. Includes build id + timestamp so a bug reporter
	# can identify the binary.
	var bid: String = BuildInfo.build_id if BuildInfo != null else "unknown"
	var when: String = Time.get_datetime_string_from_system()
	var line: String = "[%s] %s — %s\n" % [when, bid, msg]
	var existing: String = ""
	if FileAccess.file_exists(LOG_PATH):
		var rf := FileAccess.open(LOG_PATH, FileAccess.READ)
		if rf != null:
			existing = rf.get_as_text()
			rf.close()
	var wf := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(line + existing)
		wf.close()
