class_name CampaignController
extends RefCounted
## Orchestrates the campaign flow: TAVERN -> BATTLE_PREP -> BATTLE -> RESOLUTION -> TAVERN ...
## Does NOT render anything. UI subscribes to RunState signals.

var registry: Node
var rng: Node
var run_state: Node
var current_enemy_comp: Dictionary = {}
var last_battle_result: Dictionary = {}


func _init(registry_node: Node, rng_node: Node, run_state_node: Node) -> void:
	registry = registry_node
	rng = rng_node
	run_state = run_state_node


func begin_new_run(seed_value: int = -1) -> void:
	run_state.start_new_run(seed_value)
	enter_tavern()


func enter_tavern() -> void:
	run_state.set_phase(run_state.Phase.TAVERN)
	var econ: Dictionary = registry.get_economy()
	var count: int = int(econ.get("tavern_candidates_per_visit", 3))
	var rolled: Array = TavernRecruit.roll_candidates(registry, rng, count)
	var orcs: Array[Orc] = []
	var prices: Array[int] = []
	for entry: Dictionary in rolled:
		orcs.append(entry["orc"])
		prices.append(int(entry["price"]))
	run_state.set_candidates(orcs, prices)
	Console.info("Tavern entered. %d candidates rolled." % orcs.size(), "campaign")


func get_candidate_price(orc: Orc) -> int:
	return run_state.price_for(orc)


func hire(orc: Orc) -> bool:
	return run_state.hire_candidate(orc)


func enter_battle_prep() -> void:
	run_state.set_phase(run_state.Phase.BATTLE_PREP)
	# Clear remaining candidates — passed orcs are forever gone (Pillar 2)
	run_state.clear_candidates()
	# Pick enemy composition
	current_enemy_comp = BattleSetup.pick_composition(registry, rng, run_state.battles_completed)
	Console.info("Battle prep. Composition: %s" % str(current_enemy_comp.get("name", "?")), "campaign")


func resolve_battle() -> Dictionary:
	## Runs the full battle simulation and applies all consequences to RunState.
	## Returns the battle result dictionary with events + outcome.
	run_state.set_phase(run_state.Phase.BATTLE)
	if current_enemy_comp.is_empty():
		Console.error("No enemy comp set; cannot resolve battle", "campaign")
		return {}
	var player_orcs: Array = run_state.get_all_living_orcs()
	# Reset per-battle HP to max for the player side at battle start.
	for o in player_orcs:
		o.full_heal()
		o.battles_fought += 1
	last_battle_result = CombatResolver.resolve(player_orcs, current_enemy_comp, registry, rng)
	# Apply consequences
	_apply_battle_consequences(last_battle_result)
	run_state.battles_completed += 1
	if last_battle_result.get("victory", false):
		run_state.battles_won += 1
		var rewards: Dictionary = BattleSetup.compute_rewards(current_enemy_comp, registry, rng)
		run_state.add_gold(int(rewards.get("gold", 0)))
		# Award XP to survivors
		var xp_each: int = int(rewards.get("xp_per_orc", 10))
		run_state.award_xp_to_warband(xp_each)
		# Distribute drops to inventory — for G0, drops are equipped to whoever has an empty slot
		_auto_equip_drops(rewards.get("drops", []))
		run_state.emit_signal("battle_won", rewards)
		last_battle_result["rewards"] = rewards
	else:
		run_state.emit_signal("battle_lost")
	current_enemy_comp = {}
	run_state.set_phase(run_state.Phase.RESOLUTION)
	return last_battle_result


func _apply_battle_consequences(result: Dictionary) -> void:
	## Record deaths in RunState (permadeath). Killer name attached for memorial.
	var dead_list: Array = result.get("player_dead", [])
	# Identify killers via events
	var events: Array = result.get("events", [])
	var killer_by_victim: Dictionary = {}
	for ev: Dictionary in events:
		if ev.get("kind", "") == "death" and ev.get("victim_team", -1) == 0:
			killer_by_victim[String(ev.get("victim_id", ""))] = String(ev.get("killer_name", "unknown"))
	for d: Dictionary in dead_list:
		var orc: Orc = d.get("source")
		if orc == null:
			continue
		var killer_name: String = killer_by_victim.get(orc.id, "unknown")
		run_state.record_orc_death(orc, killer_name)


func _auto_equip_drops(drops: Array) -> void:
	## Equips dropped gear to any warband member with an empty slot.
	## Sells the rest as gold (50% of price).
	var orcs: Array = run_state.get_all_living_orcs()
	for gid: String in drops:
		var gear: Dictionary = registry.get_gear(gid)
		if gear.is_empty():
			continue
		var slot: String = String(gear.get("slot", "weapon"))
		var placed := false
		for o: Orc in orcs:
			if not o.equipped_gear.has(slot):
				o.equipped_gear[slot] = gid
				placed = true
				break
		if not placed:
			# Sell for 50%
			run_state.add_gold(int(gear.get("price", 0)) / 2)


func continue_from_resolution() -> void:
	## Player presses Continue on the Resolution screen.
	if not run_state.run_active:
		# Hero died; no more tavern. Game already in GAME_OVER phase.
		return
	# If no living grunts AND only the hero remains alive, that's still OK to continue.
	enter_tavern()


