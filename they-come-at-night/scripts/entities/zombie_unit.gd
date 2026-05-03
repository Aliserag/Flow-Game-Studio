class_name ZombieUnit
extends Entity

# A zombie token: single, group, horde, swarm, or megahorde.
# Moves randomly with a bias toward the closest survivor.

var unit_id: String = "single"
var size: int = 1            # number of zombies — feeds combat damage
var noise_radius: int = 1
var has_left_map: bool = false

func _init() -> void:
	super()
	kind = Kind.ZOMBIE

func is_hostile() -> bool:
	return true

func display_priority() -> int:
	# Larger zombie tokens render on top.
	return 30 + size

func describe() -> String:
	return "%s (%d)" % [display_name, size]

static func make(unit_id_in: String) -> ZombieUnit:
	var z := ZombieUnit.new()
	z.unit_id = unit_id_in
	var d: Dictionary = DataLoader.zombie_units.get(unit_id_in, {})
	z.display_name = String(d.get("name", "Wanderer"))
	z.size = RNG.randi_range_inclusive(int(d.get("size_min", 1)), int(d.get("size_max", 1)))
	z.attack = int(d.get("attack", 2))
	z.max_hp = int(d.get("hp", 4))
	z.hp = z.max_hp
	z.noise_radius = int(d.get("noise_radius", 1))
	z.glyph = String(d.get("glyph", "z"))
	z.color = Color(String(d.get("color", "#5a8a4a")))
	return z

func choose_move(grid: Grid) -> Vector2i:
	# 60% bias toward nearest survivor when within noise radius * 3, else random.
	var nearest = grid.nearest_entity(pos, func(e): return e.is_player_party())
	if nearest != null:
		var dist: int = grid.chebyshev(pos, nearest.pos)
		var detect_radius: int = noise_radius * 3 + GameState.noise_level
		if dist <= detect_radius and RNG.chance(0.55 + min(0.4, 0.05 * (detect_radius - dist))):
			return grid.step_toward(pos, nearest.pos)
	# Random walk — including walking off the map.
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.ZERO]
	var d: Vector2i = RNG.pick(dirs)
	return pos + d
