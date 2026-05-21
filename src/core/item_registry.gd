extends Node
## Loads all JSON data files at boot. Read-only data access for the rest of the game.

const ARCHETYPES_PATH := "res://data/orc-archetypes.json"
const ENEMIES_PATH := "res://data/enemy-types.json"
const GEAR_PATH := "res://data/gear-pieces.json"
const TRAITS_PATH := "res://data/traits.json"
const ECONOMY_PATH := "res://data/economy.json"
const BIOMES_PATH := "res://data/biomes.json"

var _archetypes: Dictionary = {}
var _enemies: Dictionary = {}
var _gear: Dictionary = {}
var _traits: Dictionary = {}
var _compositions: Dictionary = {}
var _economy: Dictionary = {}
var _biomes: Dictionary = {}
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
	_biomes = _load_indexed(BIOMES_PATH, "biomes", "id")
	_loaded = true
	Console.info(
		"Loaded: %d archetypes, %d enemies, %d compositions, %d gear, %d traits, %d biomes" % [
			_archetypes.size(), _enemies.size(), _compositions.size(),
			_gear.size(), _traits.size(), _biomes.size()
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


func gear_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _gear:
		out.append(id)
	return out


func get_biome(id: String) -> Dictionary:
	if not _biomes.has(id):
		Console.warn("Unknown biome: %s" % id, "registry")
		return {}
	return _biomes[id]


func biome_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _biomes:
		out.append(id)
	return out


func compositions_for_biome(biome_id: String) -> Array[String]:
	## Returns non-boss composition ids that belong to a biome.
	var biome := get_biome(biome_id)
	var pool: Array = biome.get("composition_pool", [])
	var out: Array[String] = []
	for id in pool:
		out.append(String(id))
	return out


func boss_composition_for_biome(biome_id: String) -> String:
	var biome := get_biome(biome_id)
	return String(biome.get("boss_composition_id", ""))


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
