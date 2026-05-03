extends Node

var terrain: Dictionary = {}
var items: Dictionary = {}
var factions: Dictionary = {}
var zombie_units: Dictionary = {}
var enhancements: Dictionary = {}
var events: Dictionary = {}

func _ready() -> void:
	terrain = _load_json("res://data/terrain.json")
	items = _load_json("res://data/items.json")
	factions = _load_json("res://data/factions.json")
	zombie_units = _load_json("res://data/zombie_units.json")
	enhancements = _load_json("res://data/enhancements.json")
	events = _load_json("res://data/events.json")
	print("[DataLoader] terrain=%d items=%d factions=%d zombies=%d enhancements=%d events=%d" % [
		terrain.size(), items.size(), factions.size(), zombie_units.size(),
		enhancements.size(), events.size()
	])

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: missing %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataLoader: invalid JSON in %s" % path)
		return {}
	return parsed
