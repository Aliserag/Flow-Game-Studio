extends Node
## Loads all JSON data files at boot. Read-only data access for the rest of the game.

const ARCHETYPES_PATH := "res://data/orc-archetypes.json"
const ENEMIES_PATH := "res://data/enemy-types.json"
const GEAR_PATH := "res://data/gear-pieces.json"
const TRAITS_PATH := "res://data/traits.json"
const ECONOMY_PATH := "res://data/economy.json"

var _archetypes: Dictionary = {}
var _enemies: Dictionary = {}
var _gear: Dictionary = {}
var _traits: Dictionary = {}
var _compositions: Dictionary = {}
var _economy: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	load_all()


func load_all() -> void:
	_archetypes = _load_indexed(ARCHETYPES_PATH, "archetypes", "id")
	_enemies = _load_indexed(ENEMIES_PATH, "enemies", "id")
	_compositions = _load_indexed(ENEMIES_PATH, "compositions", "id")
	_gear = _load_indexed(GEAR_PATH, "gear", "id")
	_traits = _load_indexed(TRAITS_PATH, "traits", "id")
	_economy = _load_top(ECONOMY_PATH)
	_loaded = true
	Console.info(
		"Loaded: %d archetypes, %d enemies, %d compositions, %d gear, %d traits" % [
			_archetypes.size(), _enemies.size(), _compositions.size(),
			_gear.size(), _traits.size()
		],
		"registry"
	)


func is_loaded() -> bool:
	return _loaded


func get_archetype(id: String) -> Dictionary:
	if not _archetypes.has(id):
		Console.warn("Unknown archetype: %s" % id, "registry")
		return {}
	return _archetypes[id]


func get_enemy(id: String) -> Dictionary:
	if not _enemies.has(id):
		Console.warn("Unknown enemy: %s" % id, "registry")
		return {}
	return _enemies[id]


func get_gear(id: String) -> Dictionary:
	if not _gear.has(id):
		Console.warn("Unknown gear: %s" % id, "registry")
		return {}
	return _gear[id]


func get_trait(id: String) -> Dictionary:
	if not _traits.has(id):
		Console.warn("Unknown trait: %s" % id, "registry")
		return {}
	return _traits[id]


func get_composition(id: String) -> Dictionary:
	if not _compositions.has(id):
		Console.warn("Unknown composition: %s" % id, "registry")
		return {}
	return _compositions[id]


func get_economy() -> Dictionary:
	return _economy.duplicate(true)


func grunt_archetype_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _archetypes:
		var a: Dictionary = _archetypes[id]
		if a.get("kind", "") == "grunt":
			out.append(id)
	return out


func hero_archetype_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _archetypes:
		var a: Dictionary = _archetypes[id]
		if a.get("kind", "") == "hero":
			out.append(id)
	return out


func composition_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _compositions:
		out.append(id)
	return out


func _load_top(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		Console.error("Cannot open: %s" % path, "registry")
		return {}
	var raw := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		Console.error("Not a JSON object: %s" % path, "registry")
		return {}
	return parsed


func _load_indexed(path: String, key: String, id_field: String) -> Dictionary:
	var top := _load_top(path)
	var arr: Array = top.get(key, [])
	var out: Dictionary = {}
	for entry: Variant in arr:
		if not entry is Dictionary:
			continue
		var ed: Dictionary = entry
		out[ed[id_field]] = ed
	return out
