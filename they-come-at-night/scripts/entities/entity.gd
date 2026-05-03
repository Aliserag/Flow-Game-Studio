class_name Entity
extends RefCounted

# Base class for anything that occupies a grid tile.

enum Kind { SURVIVOR, ZOMBIE, NPC }

var id: int = 0
var pos: Vector2i = Vector2i.ZERO
var kind: int = Kind.SURVIVOR
var hp: int = 1
var max_hp: int = 1
var attack: int = 1
var glyph: String = "?"
var color: Color = Color.WHITE
var display_name: String = "?"

static var _next_id: int = 1

func _init() -> void:
	id = _next_id
	_next_id += 1

func is_hostile() -> bool:
	return false

func is_player_party() -> bool:
	return false

func display_priority() -> int:
	# Higher = drawn on top in tile glyph stacking.
	return 0

func tick_turn(_grid: Grid) -> void:
	# Subclasses override.
	pass

func describe() -> String:
	return display_name
