class_name BattleSetup
extends RefCounted
## Selects an enemy composition for the next battle.
## G0: random pick from all compositions, weighted toward tier 1 in early battles.


static func pick_composition(registry: Node, rng: Node, battles_completed: int) -> Dictionary:
	var ids: Array[String] = registry.composition_ids()
	if ids.is_empty():
		return {}
	# Filter by tier appropriate to battle count
	var preferred_tier := 1
	if battles_completed >= 2:
		preferred_tier = 2
	if battles_completed >= 4:
		preferred_tier = 3
	# Try to match preferred tier; fall back to whole list
	var matching: Array = []
	for id in ids:
		var comp: Dictionary = registry.get_composition(id)
		if int(comp.get("tier", 1)) == preferred_tier:
			matching.append(id)
	var pool: Array = matching if not matching.is_empty() else ids
	var chosen_id: String = rng.pick(pool)
	return registry.get_composition(chosen_id)


static func compute_rewards(comp: Dictionary, registry: Node, rng: Node) -> Dictionary:
	var econ: Dictionary = registry.get_economy()
	var stipend: int = int(econ.get("battle_stipend", 15))
	var kill_bonus_by_tier: Dictionary = econ.get("kill_bonus_per_tier", {})
	var members: Array = comp.get("members", [])
	var total_gold: int = stipend
	var enemies_killed: int = 0
	for m: Dictionary in members:
		var enemy_id: String = String(m.get("enemy_id", ""))
		var count: int = int(m.get("count", 1))
		var enemy: Dictionary = registry.get_enemy(enemy_id)
		var tier_key: String = str(enemy.get("tier", 1))
		var bonus_per: int = int(kill_bonus_by_tier.get(tier_key, 5))
		total_gold += bonus_per * count
		enemies_killed += count
	# Drop rolls — each enemy rolls once against its drop table
	var drops: Array = []
	for m: Dictionary in members:
		var enemy_id: String = String(m.get("enemy_id", ""))
		var count: int = int(m.get("count", 1))
		var enemy: Dictionary = registry.get_enemy(enemy_id)
		var drop_table: Array = enemy.get("drops", [])
		for k in count:
			if drop_table.is_empty():
				continue
			var choices: Array = []
			var weights: Array = []
			for d: Dictionary in drop_table:
				choices.append(String(d.get("item_id", "")))
				weights.append(int(d.get("weight", 1)))
			var rolled: String = rng.pick_weighted(choices, weights)
			if rolled.is_empty():
				continue
			if rolled.begins_with("GOLD:"):
				var range_str: String = rolled.substr(5)
				var lo: int = int(range_str.split("-")[0])
				var hi: int = int(range_str.split("-")[1])
				total_gold += rng.roll_int(lo, hi)
			else:
				drops.append(rolled)
	return {
		"gold": total_gold,
		"drops": drops,
		"enemies_killed": enemies_killed,
		"xp_per_orc": int(econ.get("xp_per_battle_won", 10)),
	}
