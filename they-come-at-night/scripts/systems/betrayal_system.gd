class_name BetrayalSystem
extends RefCounted

# Nightly betrayal roll. Each non-lead party member with non-zero betrayal_chance
# rolls against an effective chance modulated by current tension.
#
# Tension factors:
#   + 0.5x   recently fed all members (low tension; betrayal less likely)
#   + 1.0x   baseline
#   + 1.5x   missed a meal in last 3 days
#   + 2.0x   morale at or below 3
#
# When a betrayal fires, one of three weighted outcomes:
#   - steal_and_flee: removes member, takes random items
#   - open_the_gates: spawns a hostile zombie group near base/lead
#   - knife_in_the_dark: damages a random other party member
#
# `tension` event effect adds +0.25 modifier to night rolls for N turns.

const STEAL_OUTCOME_WEIGHT := 50
const GATES_OUTCOME_WEIGHT := 25
const KNIFE_OUTCOME_WEIGHT := 25

const STEAL_ITEM_COUNT_MIN := 1
const STEAL_ITEM_COUNT_MAX := 3

static func nightly_check(grid: Grid) -> void:
	if GameState.party.size() <= 1:
		return  # solo lead can't betray themselves
	var tension_mod: float = _current_tension_modifier()
	# Iterate snapshot — outcomes mutate the party.
	var snapshot: Array = GameState.party.duplicate()
	for member in snapshot:
		if member.is_lead:
			continue
		if not (member is Survivor):
			continue
		if member.betrayal_chance <= 0.0:
			continue
		var effective: float = clamp(member.betrayal_chance * tension_mod, 0.0, 0.95)
		if RNG.chance(effective):
			_fire_betrayal(member, grid)
			break  # one betrayal per night

	# Decay temporary tension bonus.
	if GameState._betrayal_tension_bonus_turns > 0:
		GameState._betrayal_tension_bonus_turns -= 1

static func add_tension(turns: int = 3) -> void:
	# Called by event effects with kind "tension".
	GameState._betrayal_tension_bonus_turns += turns

static func _current_tension_modifier() -> float:
	var modifier: float = 1.0
	if GameState.morale <= 3:
		modifier = max(modifier, 2.0)
	elif GameState.morale <= 5:
		modifier = max(modifier, 1.5)
	if GameState._betrayal_tension_bonus_turns > 0:
		modifier += 0.25
	return modifier

static func _fire_betrayal(member, grid: Grid) -> void:
	GameState.stats["npcs_betrayed"] = int(GameState.stats.get("npcs_betrayed", 0)) + 1
	var pick: String = String(RNG.weighted_pick(
		["steal", "gates", "knife"],
		[STEAL_OUTCOME_WEIGHT, GATES_OUTCOME_WEIGHT, KNIFE_OUTCOME_WEIGHT]
	))
	match pick:
		"steal":
			_steal_and_flee(member, grid)
		"gates":
			_open_the_gates(member, grid)
		"knife":
			_knife_in_the_dark(member, grid)

static func _steal_and_flee(member, grid: Grid) -> void:
	# Take 1-3 random items from the stash.
	var taken: Array = []
	var item_keys: Array = GameState.inventory.keys().duplicate()
	item_keys.shuffle()
	var take_count: int = RNG.randi_range_inclusive(STEAL_ITEM_COUNT_MIN, STEAL_ITEM_COUNT_MAX)
	for i in min(take_count, item_keys.size()):
		var item_id: String = String(item_keys[i])
		var have: int = int(GameState.inventory.get(item_id, 0))
		if have <= 0:
			continue
		var amt: int = max(1, have / 2)
		GameState.remove_from_inventory(item_id, amt)
		taken.append("%dx %s" % [amt, DataLoader.items.get(item_id, {}).get("name", item_id)])
	GameState.party.erase(member)
	GameState.assignments.erase(member.id)
	if grid != null:
		grid.remove_entity(member)
	EventBus.emit_signal("party_changed")
	var faction_name: String = String(DataLoader.factions.get(member.faction_id, {}).get("name", member.faction_id))
	if taken.is_empty():
		EventBus.log_danger("%s (%s) vanished in the night with what little you had." % [member.display_name, faction_name])
	else:
		EventBus.log_danger("%s (%s) fled with: %s" % [member.display_name, faction_name, ", ".join(taken)])
	GameState.adjust_morale(-2)

static func _open_the_gates(member, grid: Grid) -> void:
	var faction_name: String = String(DataLoader.factions.get(member.faction_id, {}).get("name", member.faction_id))
	EventBus.log_danger("%s (%s) opened the gates. Something came in." % [member.display_name, faction_name])
	# Member also dies in the assault.
	GameState.party.erase(member)
	GameState.assignments.erase(member.id)
	if grid != null:
		grid.remove_entity(member)
	# Spawn a pack on or adjacent to lead/base.
	if not GameState.party.is_empty() and grid != null:
		var anchor: Vector2i = GameState.base_pos if GameState.has_base else GameState.party[0].pos
		var neighbors: Array = grid.neighbors8(anchor)
		neighbors.shuffle()
		var spawn_pos: Vector2i = neighbors[0] if not neighbors.is_empty() else anchor
		var z: ZombieUnit = ZombieUnit.make("group")
		z.pos = spawn_pos
		grid.add_entity(z)
	EventBus.emit_signal("party_changed")
	GameState.adjust_morale(-3)

static func _knife_in_the_dark(member, grid: Grid) -> void:
	# Pick a random other party member (not the betrayer); damage them.
	var others: Array = []
	for s in GameState.party:
		if s != member:
			others.append(s)
	if others.is_empty():
		# Falls back to steal-and-flee if there's no one to stab.
		_steal_and_flee(member, grid)
		return
	var victim = RNG.pick(others)
	var damage: int = RNG.randi_range_inclusive(2, 5)
	victim.hp -= damage
	var faction_name: String = String(DataLoader.factions.get(member.faction_id, {}).get("name", member.faction_id))
	EventBus.log_danger("%s (%s) attacked %s in the night for %d damage." %
		[member.display_name, faction_name, victim.display_name, damage])
	# The betrayer flees too.
	GameState.party.erase(member)
	GameState.assignments.erase(member.id)
	if grid != null:
		grid.remove_entity(member)
	# Handle victim death — promote lead if needed.
	if victim.hp <= 0:
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
		EventBus.log_danger("%s did not survive the wound." % victim.display_name)
		if GameState.party.is_empty():
			GameState.end_run(false, "Betrayal in the night ended your run.")
	EventBus.emit_signal("party_changed")
	GameState.adjust_morale(-2)
