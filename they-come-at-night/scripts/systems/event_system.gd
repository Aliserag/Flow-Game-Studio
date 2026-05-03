class_name EventSystem
extends RefCounted

# EU4-style event roller. On each turn, rolls a chance to fire one matching event.
# Events are gated by min_day, conditions, and weighted by `weight`.

const BASE_EVENT_CHANCE := 0.32

static func roll_for_event(grid: Grid) -> Dictionary:
	if RNG.randf_unit() > BASE_EVENT_CHANCE:
		return {}
	var lead = null if GameState.party.is_empty() else GameState.party[0]
	var current_tile: Tile = null
	if lead != null:
		current_tile = grid.get_tile(lead.pos)

	var pool: Array = []
	var weights: Array = []
	for id in DataLoader.events.keys():
		var ev: Dictionary = DataLoader.events[id]
		if int(ev.get("min_day", 1)) > GameState.day:
			continue
		if not _conditions_met(ev.get("conditions", {}), current_tile):
			continue
		pool.append(id)
		weights.append(int(ev.get("weight", 1)))
	if pool.is_empty():
		return {}
	var picked := String(RNG.weighted_pick(pool, weights))
	return _build_payload(picked)

static func _conditions_met(conds: Dictionary, current_tile: Tile) -> bool:
	if conds.is_empty():
		return true
	if conds.get("on_building", false):
		if current_tile == null or not current_tile.is_building():
			return false
	if conds.get("has_base", false):
		if not GameState.has_base:
			return false
	if conds.get("has_party", false):
		if GameState.party.is_empty():
			return false
	if conds.get("min_party", 0) > 0:
		if GameState.party.size() < int(conds["min_party"]):
			return false
	return true

static func _build_payload(event_id: String) -> Dictionary:
	var ev: Dictionary = DataLoader.events[event_id].duplicate(true)
	ev["id"] = event_id
	# Substitute placeholders ({party_member}) in description.
	if ev.has("description"):
		ev["description"] = _substitute(String(ev["description"]))
	return ev

static func _substitute(text: String) -> String:
	if text.find("{party_member}") != -1 and not GameState.party.is_empty():
		var pick = RNG.pick(GameState.party)
		text = text.replace("{party_member}", pick.display_name)
	return text

static func resolve_choice(event: Dictionary, choice_index: int, grid: Grid) -> Dictionary:
	GameState.stats["events_seen"] += 1
	var options: Array = event.get("options", [])
	if choice_index < 0 or choice_index >= options.size():
		return {"text": "Nothing happens.", "effects": {}}
	var opt: Dictionary = options[choice_index]

	# Pay cost if any.
	if opt.has("cost"):
		for item_id in opt["cost"].keys():
			if not GameState.remove_from_inventory(String(item_id), int(opt["cost"][item_id])):
				return {"text": "You can't afford this option.", "effects": {}}

	# Roll outcome by weight.
	var outcomes: Array = opt.get("outcomes", [])
	if outcomes.is_empty():
		return {"text": "Nothing happens.", "effects": {}}
	var weights: Array = []
	for o in outcomes:
		weights.append(int(o.get("weight", 1)))
	var chosen: Dictionary = RNG.weighted_pick(outcomes, weights)
	_apply_effects(chosen.get("effects", {}), grid)
	EventBus.emit_signal("event_resolved", String(event.get("id", "")), choice_index)
	return chosen

static func _apply_effects(eff: Dictionary, grid: Grid) -> void:
	for key in eff.keys():
		var val = eff[key]
		match key:
			"items":
				for item_id in val.keys():
					var n: int = int(val[item_id])
					if n >= 0:
						GameState.add_to_inventory(String(item_id), n)
					else:
						GameState.remove_from_inventory(String(item_id), -n)
			"hp":
				GameState.adjust_lead_hp(int(val))
			"morale":
				GameState.adjust_morale(int(val))
			"noise":
				GameState.noise_level = max(GameState.noise_level, int(val))
			"recruit_random_faction":
				if bool(val):
					_recruit_random()
			"recruit_specific_faction":
				_recruit_faction(String(val))
			"kill_random_party":
				if not GameState.party.is_empty():
					var victim = RNG.pick(GameState.party)
					if not victim.is_lead:
						_kill_member(victim, grid)
					else:
						# Lead can't be killed by chance — convert to HP loss.
						GameState.adjust_lead_hp(-4)
			"force_move":
				if bool(val) and not GameState.party.is_empty():
					_force_move_lead(grid)
			"spawn_zombies_nearby":
				_spawn_near_player(String(val), grid)
			"spawn_hostile_npc":
				_spawn_npc_of(String(val), grid)
			"trigger_siege":
				_trigger_siege(String(val), grid)
			"supply_loss":
				_lose_supplies(float(val))
			"knowledge":
				if not GameState.knowledge.has(String(val)):
					GameState.knowledge.append(String(val))
			"companion":
				EventBus.log_good("%s joins you." % String(val).capitalize())
			"vetting_bonus":
				if bool(val) and not GameState.party.is_empty():
					var newest = GameState.party.back()
					if newest.has_method("set"):
						newest.faction_revealed = true
			"defense_temp", "preparation_bonus", "tension":
				pass # tracked but not yet wired into combat math

static func _recruit_random() -> void:
	var s: Survivor = Survivor.make_random_recruit()
	GameState.party.append(s)
	GameState.assignments[s.id] = []
	GameState.stats["npcs_recruited"] += 1
	EventBus.emit_signal("party_changed")
	EventBus.log_good("%s joins you." % s.display_name)
	# Place them on the lead's tile.
	if not GameState.party.is_empty() and GameState.grid != null:
		s.pos = GameState.party[0].pos
		GameState.grid.add_entity(s)

static func _recruit_faction(faction_id: String) -> void:
	var s: Survivor = Survivor.make_random_recruit()
	s.faction_id = faction_id
	s.betrayal_chance = float(DataLoader.factions.get(faction_id, {}).get("betrayal_chance", 0.0))
	GameState.party.append(s)
	GameState.assignments[s.id] = []
	GameState.stats["npcs_recruited"] += 1
	EventBus.emit_signal("party_changed")
	EventBus.log_good("%s joins you." % s.display_name)
	if not GameState.party.is_empty() and GameState.grid != null:
		s.pos = GameState.party[0].pos
		GameState.grid.add_entity(s)

static func _kill_member(s, grid: Grid) -> void:
	GameState.party.erase(s)
	GameState.assignments.erase(s.id)
	if grid != null:
		grid.remove_entity(s)
	EventBus.emit_signal("party_changed")
	EventBus.log_danger("%s is gone." % s.display_name)

static func _force_move_lead(grid: Grid) -> void:
	var lead = GameState.party[0]
	var ns: Array = grid.neighbors4(lead.pos)
	ns.shuffle()
	for np in ns:
		var t := grid.get_tile(np)
		if t != null and not t.has_hostile():
			grid.move_entity(lead, np)
			# Drag party with lead.
			for member in GameState.party:
				if member != lead:
					grid.move_entity(member, np)
			GameState.has_base = false
			EventBus.emit_signal("base_lost")
			return

static func _spawn_near_player(unit_id: String, grid: Grid) -> void:
	if GameState.party.is_empty(): return
	var p: Vector2i = GameState.party[0].pos
	var n: Array = grid.neighbors8(p)
	n.shuffle()
	if n.is_empty(): return
	var z: ZombieUnit = ZombieUnit.make(unit_id)
	z.pos = n[0]
	grid.add_entity(z)

static func _spawn_npc_of(faction_id: String, grid: Grid) -> void:
	if GameState.party.is_empty(): return
	var p: Vector2i = GameState.party[0].pos
	var n: Array = grid.neighbors8(p)
	n.shuffle()
	if n.is_empty(): return
	var npc: Npc = Npc.spawn_random()
	npc.faction_id = faction_id
	npc.hostile_intent = true
	npc.pos = n[0]
	grid.add_entity(npc)

static func _trigger_siege(unit_id: String, grid: Grid) -> void:
	# Force a combat right now by spawning zombie on the player's tile.
	if GameState.party.is_empty(): return
	var z: ZombieUnit = ZombieUnit.make(unit_id)
	z.pos = GameState.party[0].pos
	grid.add_entity(z)
	var result := CombatResolver.resolve_attack(z, grid)
	EventBus.log_danger("Siege! %d zombies dropped, %d casualties." % [result.damage_to_zombie, result.casualties])

static func _lose_supplies(fraction: float) -> void:
	for item_id in GameState.inventory.keys():
		var have: int = int(GameState.inventory[item_id])
		var lose: int = int(ceil(have * fraction))
		GameState.remove_from_inventory(item_id, lose)
