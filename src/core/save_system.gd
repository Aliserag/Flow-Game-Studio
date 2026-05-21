extends Node
## Save system. G1: persists to `user://` which maps to:
##  - Filesystem on desktop
##  - IndexedDB (browser localStorage-equivalent) on HTML5
## One slot, plus a separate meta_progression file for cross-campaign data.

const SLOT_PATH := "user://warband_slot.json"
const META_PATH := "user://warband_meta.json"

var _slot: Dictionary = {}
var _meta_progression: Dictionary = {
	"campaigns_started": 0,
	"campaigns_won": 0,
	"hero_deaths": 0,
	"legends": [],
}


func _ready() -> void:
	_load_meta()
	_load_slot()


## Run state ---------------------------------------------------------------

func has_save() -> bool:
	return not _slot.is_empty()


func save_run(snapshot: Dictionary) -> void:
	_slot = snapshot.duplicate(true)
	_write_json(SLOT_PATH, _slot)
	Console.info("Run saved to %s" % SLOT_PATH, "save")


func load_run() -> Dictionary:
	return _slot.duplicate(true) if has_save() else {}


func clear_run() -> void:
	_slot.clear()
	if FileAccess.file_exists(SLOT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH))
	# In HTML5, file deletion may not propagate to IndexedDB immediately, but
	# overwriting with {} on next save_run effectively clears it.


## Meta progression --------------------------------------------------------

func record_campaign_started() -> void:
	_meta_progression["campaigns_started"] = int(_meta_progression.get("campaigns_started", 0)) + 1
	_write_json(META_PATH, _meta_progression)


func record_campaign_won() -> void:
	_meta_progression["campaigns_won"] = int(_meta_progression.get("campaigns_won", 0)) + 1
	_write_json(META_PATH, _meta_progression)


func record_hero_death(hero_dict: Dictionary) -> void:
	_meta_progression["hero_deaths"] = int(_meta_progression.get("hero_deaths", 0)) + 1
	var legends: Array = _meta_progression.get("legends", [])
	if hero_dict.get("battles_fought", 0) >= 1:
		legends.append({
			"name": hero_dict.get("name", "unknown"),
			"archetype": hero_dict.get("archetype_id", "unknown"),
			"kills": hero_dict.get("kills", 0),
			"battles": hero_dict.get("battles_fought", 0),
			"killer": hero_dict.get("killer_name", "unknown"),
		})
	_meta_progression["legends"] = legends
	_write_json(META_PATH, _meta_progression)


func get_meta_progression() -> Dictionary:
	return _meta_progression.duplicate(true)


## File I/O ---------------------------------------------------------------

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Console.error("Cannot open %s for write" % path, "save")
		return
	f.store_string(JSON.stringify(data))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	return {}


func _load_slot() -> void:
	_slot = _read_json(SLOT_PATH)
	if not _slot.is_empty():
		Console.info("Loaded existing run from %s" % SLOT_PATH, "save")


func _load_meta() -> void:
	var loaded: Dictionary = _read_json(META_PATH)
	if not loaded.is_empty():
		_meta_progression = loaded
		Console.info(
			"Loaded meta: campaigns=%d, hero_deaths=%d, legends=%d" % [
				int(_meta_progression.get("campaigns_started", 0)),
				int(_meta_progression.get("hero_deaths", 0)),
				(_meta_progression.get("legends", []) as Array).size(),
			],
			"save"
		)
