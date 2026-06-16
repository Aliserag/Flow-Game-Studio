extends Node
## Save system. Persists to `user://` which maps to:
##  - Filesystem on desktop
##  - IndexedDB (browser localStorage-equivalent) on HTML5
## One slot, plus meta_progression for cross-campaign data.
##
## ANTI-TAMPER: every save is HMAC-SHA256 signed. The signing key is derived from
## a project-secret + a per-install salt. This is a casual-cheat deterrent only —
## anyone who downloads the source code can re-sign their own saves.
## Schema is versioned via SCHEMA_VERSION; older or missing versions are rejected.

const SCHEMA_VERSION: int = 1

const SLOT_PATH := "user://warband_slot.json"
const SLOT_SIG_PATH := "user://warband_slot.sig"
const META_PATH := "user://warband_meta.json"
const META_SIG_PATH := "user://warband_meta.sig"
const SALT_PATH := "user://warband_save_salt.txt"

# Casual-cheat deterrent only; documented as such.
const _PROJECT_SEED := "warband_save_v1_2026_05"

var _slot: Dictionary = {}
var _meta_progression: Dictionary = {
	"campaigns_started": 0,
	"campaigns_won": 0,
	"hero_deaths": 0,
	"legends": [],
}
var _salt: String = ""


func _ready() -> void:
	_salt = _load_or_create_salt()
	_load_meta()
	_load_slot()


## Run state ---------------------------------------------------------------

func has_save() -> bool:
	return not _slot.is_empty()


func save_run(snapshot: Dictionary) -> void:
	var to_save: Dictionary = snapshot.duplicate(true)
	to_save["schema_version"] = SCHEMA_VERSION
	_slot = to_save
	_write_json(SLOT_PATH, _slot)
	_write_sig(SLOT_SIG_PATH, _sign(_slot))
	Console.info("Run saved to %s" % SLOT_PATH, "save")


func load_run() -> Dictionary:
	return _slot.duplicate(true) if has_save() else {}


func clear_run() -> void:
	_slot.clear()
	_delete_if_exists(SLOT_PATH)
	_delete_if_exists(SLOT_SIG_PATH)


## Meta progression --------------------------------------------------------

func record_campaign_started() -> void:
	_meta_progression["campaigns_started"] = int(_meta_progression.get("campaigns_started", 0)) + 1
	_persist_meta()


func record_campaign_won() -> void:
	_meta_progression["campaigns_won"] = int(_meta_progression.get("campaigns_won", 0)) + 1
	_persist_meta()


func record_hero_death(hero_dict: Dictionary) -> void:
	_meta_progression["hero_deaths"] = int(_meta_progression.get("hero_deaths", 0)) + 1
	var legends: Array = _meta_progression.get("legends", [])
	if int(hero_dict.get("battles_fought", 0)) >= 1:
		legends.append({
			"name": hero_dict.get("name", "unknown"),
			"archetype": hero_dict.get("archetype_id", "unknown"),
			"kills": int(hero_dict.get("kills", 0)),
			"battles": int(hero_dict.get("battles_fought", 0)),
			"killer": hero_dict.get("killer_name", "unknown"),
		})
	_meta_progression["legends"] = legends
	_persist_meta()


func get_meta_progression() -> Dictionary:
	return _meta_progression.duplicate(true)


## Internals --------------------------------------------------------------

func _persist_meta() -> void:
	_meta_progression["schema_version"] = SCHEMA_VERSION
	_write_json(META_PATH, _meta_progression)
	_write_sig(META_SIG_PATH, _sign(_meta_progression))


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Console.error("Cannot open %s for write" % path, "save")
		return
	f.store_string(JSON.stringify(data))


func _write_sig(path: String, sig: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(sig)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _read_sig(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text().strip_edges()


func _delete_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## HMAC-SHA256 over canonical JSON. Casual-tamper deterrent.
func _sign(data: Dictionary) -> String:
	var canonical := JSON.stringify(data)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((_PROJECT_SEED + _salt + ":" + canonical).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _verify(data: Dictionary, sig: String) -> bool:
	if sig.is_empty():
		return false
	return _sign(data) == sig


func _load_slot() -> void:
	var loaded := _read_json(SLOT_PATH)
	if loaded.is_empty():
		return
	# Schema version gate
	if int(loaded.get("schema_version", 0)) != SCHEMA_VERSION:
		Console.warn("Save schema version mismatch — refusing to load", "save")
		return
	# HMAC verify
	var sig := _read_sig(SLOT_SIG_PATH)
	if not _verify(loaded, sig):
		Console.warn("Save integrity check failed — data may be tampered. Ignoring.", "save")
		return
	_slot = loaded
	Console.info("Loaded existing run from %s" % SLOT_PATH, "save")


func _load_meta() -> void:
	var loaded := _read_json(META_PATH)
	if loaded.is_empty():
		return
	if int(loaded.get("schema_version", 0)) != SCHEMA_VERSION:
		Console.warn("Meta schema version mismatch — starting fresh meta", "save")
		return
	var sig := _read_sig(META_SIG_PATH)
	if not _verify(loaded, sig):
		Console.warn("Meta integrity check failed — starting fresh meta", "save")
		return
	# Strip the schema_version field from in-memory dict so other code doesn't see it as data
	loaded.erase("schema_version")
	_meta_progression = loaded
	Console.info(
		"Loaded meta: campaigns=%d, hero_deaths=%d, legends=%d" % [
			int(_meta_progression.get("campaigns_started", 0)),
			int(_meta_progression.get("hero_deaths", 0)),
			(_meta_progression.get("legends", []) as Array).size(),
		],
		"save"
	)


func _load_or_create_salt() -> String:
	if FileAccess.file_exists(SALT_PATH):
		var f := FileAccess.open(SALT_PATH, FileAccess.READ)
		if f != null:
			var s := f.get_as_text().strip_edges()
			if not s.is_empty():
				return s
	var new_salt := "%d_%d" % [Time.get_unix_time_from_system(), randi() % 1_000_000_000]
	var f := FileAccess.open(SALT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(new_salt)
	return new_salt
