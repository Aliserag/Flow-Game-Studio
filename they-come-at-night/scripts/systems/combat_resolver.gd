class_name CombatResolver
extends RefCounted

# Resolves zombie/horde encounters. Combat is deterministic-ish dice math:
#   attacker_power = sum(survivor.attack) + best_weapon + base.attack_bonus
#   defender_power = zombie.attack * (1 + 0.05*size)
# Modified by terrain defense / escape.

static func party_attack_power() -> int:
	var p := 0
	for s in GameState.party:
		if s.hp > 0:
			p += s.attack
	# Best equipped weapon among party adds attack value.
	var best := 0
	for items_arr in GameState.assignments.values():
		for item_id in items_arr:
			var item: Dictionary = DataLoader.items.get(item_id, {})
			best = max(best, int(item.get("attack", 0)))
	if GameState.base_enhancements.has("armory"):
		best += int(DataLoader.enhancements["armory"].get("attack_bonus", 0))
	return p + best

static func party_defense() -> int:
	var d := 0
	for items_arr in GameState.assignments.values():
		for item_id in items_arr:
			var item: Dictionary = DataLoader.items.get(item_id, {})
			d += int(item.get("defense", 0))
	if GameState.has_base:
		d += GameState.base_defense_bonus
		for enh in GameState.base_enhancements:
			d += int(DataLoader.enhancements.get(enh, {}).get("defense_bonus", 0))
	# Temporary defense buffs from events (defense_temp).
	if GameState._defense_temp_turns > 0:
		d += GameState._defense_temp_bonus
	return d

static func _consume_preparation_bonus_for(zombie: ZombieUnit) -> int:
	# One-shot bonus consumed only on swarm/megahorde combat.
	if zombie.unit_id != "swarm" and zombie.unit_id != "megahorde":
		return 0
	var bonus: int = GameState._preparation_bonus_pending
	GameState._preparation_bonus_pending = 0
	return bonus

static func resolve_attack(zombie: ZombieUnit, grid: Grid) -> Dictionary:
	var attack := party_attack_power()
	var defense := party_defense() + _consume_preparation_bonus_for(zombie)
	var z_attack: int = zombie.attack + int(zombie.size * 0.5)
	var damage_to_zombie: int = max(1, attack + RNG.randi_range_inclusive(0, 4))
	var damage_to_party: int = max(0, z_attack - defense + RNG.randi_range_inclusive(-2, 3))

	zombie.hp -= damage_to_zombie
	var killed := zombie.hp <= 0

	var party_casualties: Array = []
	if damage_to_party > 0:
		# Spread damage; lead first.
		var remaining := damage_to_party
		for survivor in GameState.party.duplicate():
			if remaining <= 0:
				break
			var hit: int = min(remaining, RNG.randi_range_inclusive(1, 3))
			survivor.hp -= hit
			remaining -= hit
			# Bite chance — only if a survivor took damage.
			if RNG.chance(0.10):
				survivor.infected = true
			if survivor.hp <= 0:
				party_casualties.append(survivor)

	# Apply casualties.
	for c in party_casualties:
		_remove_party_member(c, grid)

	if killed:
		GameState.stats["zombies_killed"] += zombie.size
		grid.remove_entity(zombie)
		if zombie.unit_id == "megahorde":
			GameState.end_run(true, "You broke the megahorde. The dead return to the dirt.")

	GameState.noise_level = max(GameState.noise_level, 2)
	EventBus.emit_signal("hud_refresh_requested")

	return {
		"zombie_killed": killed,
		"damage_to_zombie": damage_to_zombie,
		"damage_to_party": damage_to_party,
		"casualties": party_casualties.size()
	}

static func resolve_flee(zombie: ZombieUnit, grid: Grid, current_tile: Tile) -> Dictionary:
	# Open terrain favours fleeing; buildings make it dangerous.
	var escape_bonus: int = current_tile.escape_bonus()
	var roll := RNG.randi_range_inclusive(1, 10) + escape_bonus
	var success: bool = roll >= 6
	var damage := 0
	var casualties: Array = []
	if not success:
		damage = max(1, zombie.attack - escape_bonus + RNG.randi_range_inclusive(0, 3))
		var remaining := damage
		for survivor in GameState.party.duplicate():
			if remaining <= 0: break
			var hit: int = min(remaining, RNG.randi_range_inclusive(1, 3))
			survivor.hp -= hit
			remaining -= hit
			if survivor.hp <= 0:
				casualties.append(survivor)
		for c in casualties:
			_remove_party_member(c, grid)
	# If success, move player to a random safe neighbor (open terrain preferred).
	if success and GameState.party.size() > 0:
		var lead = GameState.party[0]
		var neighbors: Array = grid.neighbors4(lead.pos)
		neighbors.shuffle()
		for np in neighbors:
			var t := grid.get_tile(np)
			if t != null and not t.has_hostile():
				grid.move_entity(lead, np)
				break
	return {"success": success, "damage": damage, "casualties": casualties.size()}

static func _remove_party_member(s, grid: Grid) -> void:
	var was_lead: bool = s.is_lead
	GameState.party.erase(s)
	if grid != null:
		grid.remove_entity(s)
	# Remove their assignments.
	GameState.assignments.erase(s.id)
	# Promote the next-in-line if the lead fell so HUD/AI agree on who the lead is.
	if was_lead and not GameState.party.is_empty():
		var new_lead = GameState.party[0]
		new_lead.is_lead = true
		new_lead.faction_revealed = true
		EventBus.log_warn("%s steps up as lead." % new_lead.display_name)
	EventBus.emit_signal("party_changed")
	EventBus.log_danger("%s is dead." % s.display_name)
	if GameState.party.is_empty():
		GameState.end_run(false, "Your party was wiped out.")
