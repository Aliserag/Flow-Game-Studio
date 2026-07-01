class_name ZombieAi
extends RefCounted

# Per-turn movement & spawning for zombie tokens.
# Spawn rates scale with day index, mirroring "increasing pressure".

const BASE_SPAWN_CHANCE := 0.35
const PROXIMITY_BONUS_PER_TILE := 0.04   # hostile chance grows as zombies near survivor

static func tick(grid: Grid) -> void:
	# Move all existing zombies first.
	for e in grid.entities.duplicate():
		if e is ZombieUnit:
			_step_zombie(e, grid)

	# Move NPCs.
	for e in grid.entities.duplicate():
		if e is Npc:
			_step_npc(e, grid)

	# Maybe spawn new zombies at the edge.
	_maybe_spawn_zombie(grid)
	# Maybe spawn a new wandering NPC.
	_maybe_spawn_npc(grid)

static func _step_zombie(z: ZombieUnit, grid: Grid) -> void:
	var target: Vector2i = z.choose_move(grid)
	if not grid.in_bounds(target):
		# Walked off the map.
		grid.remove_entity(z)
		return
	grid.move_entity(z, target)
	# Bias proximity-driven aggression: increasing chance the zombie steps
	# additionally toward the player when extremely close.
	if not GameState.party.is_empty():
		var lead = GameState.party[0]
		var dist: int = grid.chebyshev(z.pos, lead.pos)
		var aggro_chance: float = clamp(0.1 + PROXIMITY_BONUS_PER_TILE * (10 - dist), 0.0, 0.85)
		if dist <= 5 and RNG.chance(aggro_chance):
			var step_again: Vector2i = grid.step_toward(z.pos, lead.pos)
			if grid.in_bounds(step_again):
				grid.move_entity(z, step_again)

static func _step_npc(n: Npc, grid: Grid) -> void:
	var target: Vector2i = n.choose_move(grid)
	if not grid.in_bounds(target):
		# Walked off — gone.
		grid.remove_entity(n)
		return
	grid.move_entity(n, target)
	NpcBehavior.post_step_action(n, grid)

static func _maybe_spawn_zombie(grid: Grid) -> void:
	var chance: float = (BASE_SPAWN_CHANCE + 0.01 * GameState.day) * DifficultyConfig.zombie_spawn_multiplier()
	if not RNG.chance(min(0.95, chance)):
		return
	var pool := _spawn_pool_for_day(GameState.day)
	if pool.is_empty():
		return
	var unit_id: String = String(RNG.weighted_pick_dict(pool))
	var z: ZombieUnit = ZombieUnit.make(unit_id)
	z.pos = grid.random_edge_position()
	grid.add_entity(z)

static func _maybe_spawn_npc(grid: Grid) -> void:
	# NPCs are rarer.
	if RNG.chance(0.10):
		var n: Npc = Npc.spawn_random()
		n.pos = grid.random_edge_position()
		grid.add_entity(n)

static func _spawn_pool_for_day(day: int) -> Dictionary:
	var pool: Dictionary = {}
	var phase_key: String = "spawn_weight_early"
	if day >= 30:
		phase_key = "spawn_weight_late"
	elif day >= 12:
		phase_key = "spawn_weight_mid"
	for k in DataLoader.zombie_units.keys():
		var d: Dictionary = DataLoader.zombie_units[k]
		var w: int = int(d.get(phase_key, 0))
		if w > 0:
			pool[k] = w
	return pool
