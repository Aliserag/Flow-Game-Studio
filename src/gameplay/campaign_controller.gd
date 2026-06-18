class_name CampaignController
extends RefCounted
## Orchestrates the campaign flow for G1:
##   TAVERN -> MAP -> SCOUT -> BATTLE_PREP -> BATTLE -> RESOLUTION -> MAP
##   Map nodes can also be MARKET (RunState.market_stock) or REST (heal warband).
##   Boss node = final node in row; defeating it = VICTORY.
##
## Does NOT render anything. UI subscribes to RunState signals.

var registry: Node
var rng: Node
var run_state: Node

var current_enemy_comp: Dictionary = {}
var current_biome: Dictionary = {}
var current_scout_report: Dictionary = {}
var last_battle_result: Dictionary = {}


func _init(registry_node: Node, rng_node: Node, run_state_node: Node) -> void:
	registry = registry_node
	rng = rng_node
	run_state = run_state_node


func begin_new_run(seed_value: int = -1) -> void:
	run_state.start_new_run(seed_value)
	# Pick the active biome — G1 has one
	var biome_ids: Array[String] = registry.biome_ids()
	if biome_ids.is_empty():
		Console.error("No biomes defined", "campaign")
		return
	run_state.current_biome_id = biome_ids[0]
	current_biome = registry.get_biome(run_state.current_biome_id)
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


func leave_tavern_for_map() -> void:
	## Player commits — clears candidates and generates the campaign map.
	run_state.clear_candidates()
	if run_state.campaign_map.is_empty():
		run_state.campaign_map = CampaignMap.generate(run_state.current_biome_id, registry, rng)
	run_state.set_phase(run_state.Phase.MAP)
	run_state.emit_signal("map_changed")


func get_available_map_nodes() -> Array:
	return CampaignMap.get_available_next_nodes(run_state.campaign_map)


func enter_map_node(node_id: String) -> void:
	CampaignMap.enter_node(run_state.campaign_map, node_id)
	var node = run_state.campaign_map["nodes"][node_id]
	match node.node_type:
		CampaignMap.NodeType.BATTLE, CampaignMap.NodeType.BOSS:
			enter_scout(node.composition_id)
		CampaignMap.NodeType.MARKET:
			enter_market()
		CampaignMap.NodeType.REST:
			do_rest()
		CampaignMap.NodeType.EVENT:
			do_event()
		_:
			Console.warn("Unknown node type: %d" % node.node_type, "campaign")


func enter_scout(comp_id: String) -> void:
	current_enemy_comp = registry.get_composition(comp_id)
	current_scout_report = ScoutReport.generate(current_enemy_comp, current_biome, registry)
	run_state.set_phase(run_state.Phase.SCOUT)


func commit_to_battle() -> void:
	## Player accepts the scout report and enters battle.
	run_state.set_phase(run_state.Phase.BATTLE_PREP)


func resolve_battle() -> Dictionary:
	run_state.set_phase(run_state.Phase.BATTLE)
	if current_enemy_comp.is_empty():
		Console.error("No enemy comp set; cannot resolve", "campaign")
		return {}
	var player_orcs: Array = run_state.get_all_living_orcs()
	for o in player_orcs:
		o.full_heal()
		o.battles_fought += 1
	var biome_mod: Dictionary = current_biome.get("battle_modifier", {})
	last_battle_result = CombatResolver.resolve(player_orcs, current_enemy_comp, registry, rng, biome_mod)
	_apply_battle_consequences(last_battle_result)
	run_state.battles_completed += 1
	if last_battle_result.get("victory", false):
		run_state.battles_won += 1
		var rewards: Dictionary = BattleSetup.compute_rewards(current_enemy_comp, registry, rng)
		run_state.add_gold(int(rewards.get("gold", 0)))
		run_state.award_xp_to_warband(int(rewards.get("xp_per_orc", 10)))
		_auto_equip_drops(rewards.get("drops", []))
		run_state.emit_signal("battle_won", rewards)
		last_battle_result["rewards"] = rewards
	else:
		run_state.emit_signal("battle_lost")
	current_enemy_comp = {}
	current_scout_report = {}
	# Don't clobber GAME_OVER if hero died during battle
	if run_state.run_active:
		run_state.set_phase(run_state.Phase.RESOLUTION)
	return last_battle_result


func _apply_battle_consequences(result: Dictionary) -> void:
	var dead_list: Array = result.get("player_dead", [])
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
	## Pre-G1 behavior: auto-equip to empty slot, sell otherwise.
	## G1 keeps auto-equip but ALSO adds the drop's gold value back if it'd be useless.
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
			run_state.add_gold(int(gear.get("price", 0)) / 2)


func continue_from_resolution() -> void:
	## After a normal battle: complete the map node and return to MAP.
	## After a BOSS battle: advance to next biome if one exists, else VICTORY.
	if not run_state.run_active:
		return
	var map: Dictionary = run_state.campaign_map
	var current_id: String = String(map.get("current_node_id", ""))
	var was_boss: bool = CampaignMap.is_boss_node(map, current_id) if not current_id.is_empty() else false
	CampaignMap.complete_current(map)
	run_state.emit_signal("map_changed")
	if was_boss and last_battle_result.get("victory", false):
		# Boss down. Does this biome chain to another?
		var next_biome_id: String = String(current_biome.get("next_biome_id", ""))
		if next_biome_id.is_empty():
			# Final biome cleared — campaign won
			run_state.set_phase(run_state.Phase.VICTORY)
			run_state.end_run(true)
			return
		# Chain into next biome: fresh map, same warband (full-healed)
		run_state.current_biome_id = next_biome_id
		current_biome = registry.get_biome(next_biome_id)
		run_state.campaign_map = CampaignMap.generate(next_biome_id, registry, rng)
		run_state.full_heal_warband()
		Console.info("Biome cleared. Advancing to %s." % next_biome_id, "campaign")
		run_state.emit_signal("map_changed")
		run_state.set_phase(run_state.Phase.MAP)
		return
	run_state.set_phase(run_state.Phase.MAP)


func enter_market() -> void:
	run_state.set_phase(run_state.Phase.MARKET)
	var biome: Dictionary = current_biome
	var tier: int = int(biome.get("tier_range", [1, 2])[1])
	run_state.market_stock = Market.roll_stock(registry, rng, tier)
	run_state.emit_signal("market_stock_changed")


func buy_from_market(stock_index: int, target_orc: Orc) -> bool:
	if stock_index < 0 or stock_index >= run_state.market_stock.size():
		return false
	var entry: Dictionary = run_state.market_stock[stock_index]
	var ok: bool = Market.buy(registry, run_state, entry, target_orc)
	if ok:
		run_state.market_stock.remove_at(stock_index)
		run_state.emit_signal("market_stock_changed")
		run_state.emit_signal("roster_changed")
	return ok


func sell_orc_gear(orc: Orc, slot: String) -> int:
	var gained: int = Market.sell(run_state, registry, orc, slot)
	if gained > 0:
		run_state.emit_signal("roster_changed")
	return gained


func leave_market() -> void:
	CampaignMap.complete_current(run_state.campaign_map)
	run_state.market_stock.clear()
	run_state.emit_signal("market_stock_changed")
	run_state.emit_signal("map_changed")
	run_state.set_phase(run_state.Phase.MAP)


func do_rest() -> void:
	## REST node heals the warband halfway between current and max.
	for o in run_state.get_all_living_orcs():
		var heal_amount: int = int((o.max_hp - o.current_hp) / 2)
		o.heal(heal_amount)
	CampaignMap.complete_current(run_state.campaign_map)
	run_state.emit_signal("map_changed")
	run_state.emit_signal("roster_changed")
	run_state.set_phase(run_state.Phase.MAP)


func do_event() -> void:
	## G1 event node: deterministic gold gift (small) OR random trait blessing.
	## Keep simple — just give some gold.
	var gift: int = rng.roll_int(15, 30)
	run_state.add_gold(gift)
	CampaignMap.complete_current(run_state.campaign_map)
	run_state.emit_signal("map_changed")
	run_state.set_phase(run_state.Phase.MAP)
