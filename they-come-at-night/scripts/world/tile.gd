class_name Tile
extends RefCounted

# Single grid tile. Lightweight data container; no scene-tree presence.

var pos: Vector2i
var terrain_id: String = "plains"
var supplies: int = 0       # remaining scavengable supply units
var searched: bool = false  # whether the player has scavenged this tile already
var explored: bool = false  # whether the tile has ever been within visual range
var visible: bool = false   # currently in line of sight (recomputed per turn)
var has_base: bool = false  # this tile holds the player's base
var entities: Array = []    # references to entities currently on this tile

func _init(p: Vector2i, terrain: String) -> void:
	pos = p
	terrain_id = terrain

func data() -> Dictionary:
	return DataLoader.terrain.get(terrain_id, {})

func is_building() -> bool:
	return bool(data().get("is_building", false))

func defense_bonus() -> int:
	return int(data().get("defense_bonus", 0))

func escape_bonus() -> int:
	return int(data().get("escape_bonus", 0))

func glyph() -> String:
	return String(data().get("glyph", "."))

func color() -> Color:
	var hex := String(data().get("color", "#7a8c5a"))
	return Color(hex)

func display_name() -> String:
	return String(data().get("name", terrain_id))

func add_entity(e) -> void:
	if not entities.has(e):
		entities.append(e)

func remove_entity(e) -> void:
	entities.erase(e)

func has_hostile() -> bool:
	for e in entities:
		if e.is_hostile():
			return true
	return false

func first_entity_glyph() -> String:
	if entities.is_empty():
		return ""
	# Priority: player > zombies > npcs (for visibility)
	var prio := 0
	var chosen = null
	for e in entities:
		var p: int = e.display_priority()
		if chosen == null or p > prio:
			prio = p
			chosen = e
	return chosen.glyph if chosen else ""
