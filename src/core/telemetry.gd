extends Node
## Opt-in anonymous telemetry. Default OFF. No PII. No IP logging on our side.
## See docs/release/PRIVACY.md.

const CONSENT_PATH := "user://telemetry_consent.json"
const SALT_PATH := "user://install_salt.txt"

var enabled: bool = false
var endpoint_url: String = ""  # empty by default — flush is a no-op
var _install_salt: String = ""
var _player_id_hash: String = ""
var _session_id: String = ""
var _queue: Array[Dictionary] = []
var _http: HTTPRequest


func _ready() -> void:
	_session_id = _gen_session_id()
	_load_consent()
	_load_or_create_salt()
	_player_id_hash = _hash_player_id(_install_salt)
	_http = HTTPRequest.new()
	add_child(_http)
	# Wire RunState signals (the autoload's emitter is the source of truth)
	if RunState != null:
		if RunState.run_started.is_connected(_on_run_started) == false:
			RunState.run_started.connect(_on_run_started)
		if RunState.run_ended.is_connected(_on_run_ended) == false:
			RunState.run_ended.connect(_on_run_ended)
		if RunState.orc_died.is_connected(_on_orc_died) == false:
			RunState.orc_died.connect(_on_orc_died)
		if RunState.battle_won.is_connected(_on_battle_won) == false:
			RunState.battle_won.connect(_on_battle_won)


func set_enabled(value: bool) -> void:
	enabled = value
	_save_consent()
	Console.info("Telemetry %s" % ("enabled" if value else "disabled"), "telemetry")


func set_endpoint(url: String) -> void:
	endpoint_url = url
	_save_consent()


func record(event_name: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry := {
		"event": event_name,
		"props": props,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"session_id": _session_id,
		"player_hash": _player_id_hash,
		"version": ProjectSettings.get_setting("application/config/version", "unknown"),
	}
	_queue.append(entry)
	# Best-effort opportunistic flush every 10 events
	if _queue.size() >= 10:
		flush()


func flush() -> void:
	if not enabled or endpoint_url.is_empty() or _queue.is_empty():
		return
	if _http == null:
		return
	var body := JSON.stringify({"events": _queue})
	var headers := ["Content-Type: application/json"]
	var err := _http.request(endpoint_url, headers, HTTPClient.METHOD_POST, body)
	if err == OK:
		_queue.clear()
	# On failure, keep the queue for next attempt.


# --- Signal handlers ---

func _on_run_started() -> void:
	record("run_started", {})


func _on_run_ended(victory: bool) -> void:
	record("run_ended", {
		"victory": victory,
		"battles_completed": RunState.battles_completed,
		"battles_won": RunState.battles_won,
		"gold_at_end": RunState.gold,
		"gravestone_count": RunState.gravestone_count(),
	})
	flush()  # best-effort send at run boundary


func _on_orc_died(orc_dict: Dictionary, _killer_name: String) -> void:
	if bool(orc_dict.get("is_hero", false)):
		record("hero_died", {
			"battles_fought": orc_dict.get("battles_fought", 0),
			"kills": orc_dict.get("kills", 0),
		})


func _on_battle_won(rewards: Dictionary) -> void:
	record("battle_completed", {
		"gold_gained": rewards.get("gold", 0),
		"enemies_killed": rewards.get("enemies_killed", 0),
	})


# --- Persistence ---

func _load_consent() -> void:
	if not FileAccess.file_exists(CONSENT_PATH):
		return
	var f := FileAccess.open(CONSENT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		enabled = bool(d.get("enabled", false))
		endpoint_url = String(d.get("endpoint", ""))


func _save_consent() -> void:
	var f := FileAccess.open(CONSENT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"enabled": enabled, "endpoint": endpoint_url}))


func _load_or_create_salt() -> void:
	if FileAccess.file_exists(SALT_PATH):
		var f := FileAccess.open(SALT_PATH, FileAccess.READ)
		if f != null:
			_install_salt = f.get_as_text().strip_edges()
			return
	# Create a new salt — never reused, never re-exported
	_install_salt = "%d_%d" % [Time.get_unix_time_from_system(), randi() % 1_000_000_000]
	var f := FileAccess.open(SALT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(_install_salt)


func _hash_player_id(salt: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("warband_player:" + salt).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _gen_session_id() -> String:
	# Cheap session id: timestamp + random short. Not stable across restarts.
	return "%d_%d" % [Time.get_ticks_msec(), randi() % 1_000_000]
