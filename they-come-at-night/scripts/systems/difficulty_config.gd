class_name DifficultyConfig
extends RefCounted

# Difficulty-derived multipliers and ranges. Single source of truth — every
# system that scales with difficulty reads these helpers.

static func zombie_spawn_multiplier() -> float:
	match GameState.difficulty:
		GameState.Difficulty.TOURIST: return 0.6
		GameState.Difficulty.STANDARD: return 1.0
		GameState.Difficulty.APOCALYPSE: return 1.35
		GameState.Difficulty.PERMADEATH: return 1.35
		_: return 1.0

static func food_consumption_multiplier() -> float:
	match GameState.difficulty:
		GameState.Difficulty.TOURIST: return 0.75
		GameState.Difficulty.STANDARD: return 1.0
		GameState.Difficulty.APOCALYPSE: return 1.5
		GameState.Difficulty.PERMADEATH: return 1.5
		_: return 1.0

static func megahorde_unlock_range() -> Array:
	# [min_day, max_day] for the random unlock roll.
	match GameState.difficulty:
		GameState.Difficulty.TOURIST: return [35, 50]
		GameState.Difficulty.STANDARD: return [20, 50]
		GameState.Difficulty.APOCALYPSE: return [15, 30]
		GameState.Difficulty.PERMADEATH: return [15, 30]
		_: return [20, 50]

static func permadeath() -> bool:
	return GameState.difficulty == GameState.Difficulty.PERMADEATH

static func map_size_for_pick(pick: String) -> Vector2i:
	# Used by main menu when the player picks a size.
	match pick:
		"quick": return Vector2i(10, 10)
		"standard": return Vector2i(14, 14)
		"long": return Vector2i(20, 20)
		_: return Vector2i(14, 14)

static func megahorde_unlock_day_for_map_size(size: Vector2i) -> int:
	# Larger maps give more time before the megahorde.
	var area: int = size.x * size.y
	var range_arr: Array = megahorde_unlock_range()
	var base_min: int = int(range_arr[0])
	var base_max: int = int(range_arr[1])
	var scale: float = float(area) / float(14 * 14)
	return RNG.randi_range_inclusive(int(base_min * scale), int(base_max * scale))

static func difficulty_label() -> String:
	match GameState.difficulty:
		GameState.Difficulty.TOURIST: return "Tourist"
		GameState.Difficulty.STANDARD: return "Standard"
		GameState.Difficulty.APOCALYPSE: return "Apocalypse"
		GameState.Difficulty.PERMADEATH: return "Permadeath"
		_: return "?"
