class_name NpcBehavior
extends RefCounted

# Per-faction NPC movement behaviors. Replaces Npc.choose_move's random walk
# with strategy varied by faction:
#   lone_wolf, scavengers — drift toward player, occasional wandering
#   doctors                — drift toward injured survivors, heal adjacent allies
#   militia                — patrol roads, attack adjacent zombies
#   raiders                — stalk player at distance; attack on contact when armed
#   cannibals              — friendly pacing until within 1 of player at night
#   cultists               — drift toward nearest zombie horde
#   federal_remnant, free_traders, etc. — fall back to neutral drift

static func post_step_action(npc: Npc, grid: Grid) -> void:
	# Faction-specific actions taken after movement (e.g. doctors heal,
	# raiders strike). Called by ZombieAi.tick after move resolves.
	if GameState.party.is_empty():
		return
	var lead = GameState.party[0]
	var adj_to_lead: bool = grid.chebyshev(npc.pos, lead.pos) <= 1
	if not adj_to_lead:
		return
	match npc.faction_id:
		"doctors":
			# Heal lead 1 HP if injured.
			if lead.hp < lead.max_hp:
				lead.hp += 1
				EventBus.log_good("%s patches up %s." % [npc.display_name, lead.display_name])
				EventBus.emit_signal("hud_refresh_requested")
		"raiders":
			# Attempt to mug — small HP loss to lead, raider walks off.
			if RNG.chance(0.35):
				var dmg: int = RNG.randi_range_inclusive(1, 3)
				lead.hp -= dmg
				EventBus.log_danger("%s strikes %s for %d." % [npc.display_name, lead.display_name, dmg])
				if lead.hp <= 0:
					GameState.adjust_lead_hp(0)  # triggers death check
				EventBus.emit_signal("hud_refresh_requested")

static func step(npc: Npc, grid: Grid) -> Vector2i:
	match npc.faction_id:
		"doctors":
			return _drift_to_injured(npc, grid)
		"militia":
			return _patrol_roads(npc, grid)
		"raiders":
			return _stalk_player(npc, grid)
		"cannibals":
			return _stalk_player_cautious(npc, grid)
		"cultists":
			return _drift_to_zombies(npc, grid)
		"scavengers":
			return _drift_to_buildings(npc, grid)
		_:
			return _default_drift(npc, grid)

# --- helpers ---

static func _step_random(npc: Npc) -> Vector2i:
	var dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.ZERO, Vector2i.ZERO]
	return npc.pos + RNG.pick(dirs)

static func _step_toward(grid: Grid, from: Vector2i, to: Vector2i) -> Vector2i:
	return grid.step_toward(from, to)

static func _default_drift(npc: Npc, grid: Grid) -> Vector2i:
	var nearest = grid.nearest_entity(npc.pos, func(e): return e.is_player_party())
	if nearest != null and grid.chebyshev(npc.pos, nearest.pos) <= 6 and RNG.chance(0.4):
		return _step_toward(grid, npc.pos, nearest.pos)
	return _step_random(npc)

static func _drift_to_injured(npc: Npc, grid: Grid) -> Vector2i:
	# Find any survivor below max_hp; head their way.
	var injured = grid.nearest_entity(npc.pos, func(e):
		return e.is_player_party() and e.hp < e.max_hp
	)
	if injured != null and grid.chebyshev(npc.pos, injured.pos) <= 8 and RNG.chance(0.7):
		return _step_toward(grid, npc.pos, injured.pos)
	# Otherwise drift toward any survivor.
	return _default_drift(npc, grid)

static func _patrol_roads(npc: Npc, grid: Grid) -> Vector2i:
	# Prefer adjacent road tiles; otherwise default drift.
	var ns: Array = grid.neighbors4(npc.pos)
	ns.shuffle()
	for n in ns:
		var t: Tile = grid.get_tile(n)
		if t != null and t.terrain_id == "road":
			return n
	return _default_drift(npc, grid)

static func _stalk_player(npc: Npc, grid: Grid) -> Vector2i:
	if GameState.party.is_empty():
		return _step_random(npc)
	var lead = GameState.party[0]
	var dist: int = grid.chebyshev(npc.pos, lead.pos)
	# Approach until 2-3 tiles, then circle.
	if dist > 3 and RNG.chance(0.6):
		return _step_toward(grid, npc.pos, lead.pos)
	if dist <= 1 and RNG.chance(0.4):
		# Maintain a knife-throw distance until parley.
		return _step_random(npc)
	return _step_random(npc)

static func _stalk_player_cautious(npc: Npc, grid: Grid) -> Vector2i:
	# Cannibals approach but pretend nonchalance.
	if GameState.party.is_empty():
		return _step_random(npc)
	var lead = GameState.party[0]
	var dist: int = grid.chebyshev(npc.pos, lead.pos)
	if dist > 5 and RNG.chance(0.3):
		return _step_toward(grid, npc.pos, lead.pos)
	if dist > 2 and RNG.chance(0.45):
		return _step_toward(grid, npc.pos, lead.pos)
	return _step_random(npc)

static func _drift_to_zombies(npc: Npc, grid: Grid) -> Vector2i:
	var z = grid.nearest_entity(npc.pos, func(e): return e is ZombieUnit)
	if z != null and grid.chebyshev(npc.pos, z.pos) <= 8 and RNG.chance(0.55):
		return _step_toward(grid, npc.pos, z.pos)
	return _step_random(npc)

static func _drift_to_buildings(npc: Npc, grid: Grid) -> Vector2i:
	# Wander toward nearest unsearched building tile.
	var best: Tile = null
	var best_dist: int = 9999
	# Sample a small radius — full grid scan is fine for our sizes.
	for x in grid.size.x:
		for y in grid.size.y:
			var t: Tile = grid.get_tile(Vector2i(x, y))
			if t == null or not t.is_building() or t.searched:
				continue
			var d: int = grid.chebyshev(npc.pos, Vector2i(x, y))
			if d < best_dist:
				best_dist = d
				best = t
	if best != null and best_dist <= 8 and RNG.chance(0.5):
		return _step_toward(grid, npc.pos, best.pos)
	return _default_drift(npc, grid)
