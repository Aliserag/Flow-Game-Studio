class_name TurnManager
extends RefCounted

# Orchestrates per-turn flow.

const VISION_RADIUS_BASE := 2

static func vision_radius() -> int:
	var r := VISION_RADIUS_BASE
	if GameState.has_base and GameState.base_enhancements.has("watchtower"):
		r += int(DataLoader.enhancements["watchtower"].get("vision_bonus", 0))
	return r

static func recompute_vision(grid: Grid) -> void:
	if GameState.party.is_empty():
		return
	grid.recompute_visibility(GameState.party[0].pos, vision_radius())

static func end_turn(grid: Grid) -> void:
	# 1. Player phase already done (move/scavenge/etc applied before calling end_turn).
	# 2. Zombie/NPC AI tick.
	ZombieAi.tick(grid)
	# 3. Check for combat — any zombie now sharing player's tile triggers fight.
	_resolve_collisions(grid)
	# 4. Day advance (in solo mode, every turn = a day).
	GameState.day += 1
	GameState.turns_today = 0
	GameState.noise_level = max(0, GameState.noise_level - 1)
	# 5. Tick base build progress, daily yields.
	BaseSystem.tick_day()
	# 6. Hunger / morale erosion.
	_daily_upkeep()
	# 7. Tick swarm/megahorde.
	SwarmSystem.on_day_advanced(GameState.day, grid)
	# 8. Check infections — turn into zombie if untreated for too long.
	_tick_infections(grid)
	# 8b. Nightly betrayal roll for high-betrayal-chance recruits.
	BetrayalSystem.nightly_check(grid)
	# 8c. Decay temporary defense buff.
	if GameState._defense_temp_turns > 0:
		GameState._defense_temp_turns -= 1
		if GameState._defense_temp_turns <= 0:
			GameState._defense_temp_bonus = 0
	# 9. Roll for an event.
	var ev: Dictionary = EventSystem.roll_for_event(grid)
	# 10. Recompute visibility & emit signals.
	recompute_vision(grid)
	EventBus.emit_signal("day_advanced", GameState.day)
	EventBus.emit_signal("hud_refresh_requested")
	if not ev.is_empty():
		EventBus.emit_signal("request_event_modal", ev)

static func _resolve_collisions(grid: Grid) -> void:
	if GameState.party.is_empty(): return
	var lead = GameState.party[0]
	var t: Tile = grid.get_tile(lead.pos)
	if t == null: return
	for e in t.entities.duplicate():
		if e is ZombieUnit:
			var result := CombatResolver.resolve_attack(e, grid)
			EventBus.log_danger("Combat with %s — %d damage dealt, %d casualties." % [e.display_name, result.damage_to_zombie, result.casualties])

static func _daily_upkeep() -> void:
	# Each member needs ~1 unit of food per day (canned_food, mre, water_bottle).
	var need: int = max(1, GameState.party.size())
	var fed: int = 0
	for food_id in ["mre", "canned_food", "water_bottle"]:
		while fed < need and GameState.has_item(food_id, 1):
			GameState.remove_from_inventory(food_id, 1)
			fed += 1
	if fed < need:
		EventBus.log_warn("Not enough food. Morale drops.")
		GameState.adjust_morale(-1)

static func _tick_infections(grid: Grid) -> void:
	var to_kill: Array = []
	for s in GameState.party:
		if s.infected and RNG.chance(0.25):
			# Untreated infection turns into a zombie roll; antibiotics use is manual.
			to_kill.append(s)
	for victim in to_kill:
		EventBus.log_danger("%s turns in the night." % victim.display_name)
		var was_lead: bool = victim.is_lead
		GameState.party.erase(victim)
		GameState.assignments.erase(victim.id)
		if grid != null:
			grid.remove_entity(victim)
		if was_lead and not GameState.party.is_empty():
			var new_lead = GameState.party[0]
			new_lead.is_lead = true
			new_lead.faction_revealed = true
			EventBus.log_warn("%s steps up as lead." % new_lead.display_name)
		EventBus.emit_signal("party_changed")
		# Spawn a single zombie at their location.
		var z: ZombieUnit = ZombieUnit.make("single")
		z.pos = victim.pos
		grid.add_entity(z)
		if GameState.party.is_empty():
			GameState.end_run(false, "Your last survivor turned.")

static func attempt_move(grid: Grid, target: Vector2i) -> bool:
	if GameState.party.is_empty(): return false
	var lead = GameState.party[0]
	if grid.chebyshev(lead.pos, target) > 1:
		EventBus.log_warn("Can't move that far in one turn.")
		return false
	if not grid.in_bounds(target):
		return false
	var from := lead.pos
	# If target tile has a hostile, that's combat (handled at end_turn collision).
	grid.move_entity(lead, target)
	# Drag party with lead.
	for s in GameState.party:
		if s != lead:
			grid.move_entity(s, target)
	# If we moved off the base, lose the base unless it was abandoned intentionally.
	if GameState.has_base and target != GameState.base_pos:
		# Remaining base tile keeps `has_base` flag; player isn't 'in' it anymore.
		# Walking back will re-engage it via UI.
		pass
	EventBus.emit_signal("player_moved", from, target)
	return true
