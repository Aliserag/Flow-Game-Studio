class_name CombatResolver
extends RefCounted
## Pure-function combat resolution.
##
## Takes a player warband, enemy composition, optional biome modifier, and an RNG node.
## Returns ordered event log + outcome. Deterministic when seeded RNG is provided.
##
## Combat model (G1):
## - Tick-based round system. Each round, units act in speed order (high speed first).
## - Each acting unit targets the lowest-HP opposing unit (front-line bias by index).
## - Damage = max(1, attacker.attack - floor(defender.defense / 2)), then trait/crit modifiers.
## - Crit multiplies damage by 2.
## - Wounded-target bonus (Butcher trait): +15% damage vs targets below 50% HP.
## - Round-end heal (Spirit-Touched trait): heals most-wounded ally.
## - Vengeful trait: +2 attack permanently after an ally dies.
## - Biome modifier (e.g., enemy_speed_bonus_early): applies for first N rounds.
## - Boss phase 2: triggers when boss HP crosses configured threshold. Boss gains
##   stat bonuses and an event is emitted (battle-display can play a special toast).
## - Battle ends when one side is fully dead.

const MAX_ROUNDS: int = 80

const EV_BATTLE_START := "battle_start"
const EV_ROUND_START := "round_start"
const EV_ATTACK := "attack"
const EV_DEATH := "death"
const EV_HEAL := "heal"
const EV_PHASE_CHANGE := "phase_change"
const EV_BATTLE_END := "battle_end"


class Combatant:
	extends RefCounted
	var unit_id: String
	var display_name: String
	var team: int                 # 0 = player, 1 = enemy
	var source: Variant
	var current_hp: int
	var max_hp: int
	var attack: int
	var defense: int
	var speed: int
	var base_speed: int           # snapshot of starting speed (for biome modifier expiry)
	var is_ranged: bool = false
	var crit_chance: float = 0.05
	var traits: Array[String] = []
	var heal_on_kill: int = 0
	var round_heal_ally: int = 0  # Spirit-Touched
	var wounded_bonus: float = 0.0  # Butcher
	var vengeful_pending: int = 0   # +attack on ally death; consumed once.
	var is_boss: bool = false
	var boss_phase_threshold: float = 0.0
	var boss_phase_modifier: Dictionary = {}
	var boss_phase_message: String = ""
	var phase_2_triggered: bool = false


static func resolve(
	player_orcs: Array,
	enemy_composition: Dictionary,
	registry: Node,
	rng: Node,
	biome_modifier: Dictionary = {}
) -> Dictionary:
	var events: Array[Dictionary] = []
	var combatants: Array = []
	var player_team := []
	var enemy_team := []

	for orc: Orc in player_orcs:
		if not orc.is_alive():
			continue
		var team_attack_bonus := _team_attack_bonus_from(player_orcs, registry)
		var stats: Dictionary = orc.effective_stats(registry, team_attack_bonus)
		var c := Combatant.new()
		c.unit_id = orc.id
		c.display_name = orc.name
		c.team = 0
		c.source = orc
		c.max_hp = int(stats["max_hp"])
		c.current_hp = min(orc.current_hp, c.max_hp)
		c.attack = int(stats["attack"])
		c.defense = int(stats["defense"])
		c.speed = int(stats["speed"])
		c.base_speed = c.speed
		c.traits = orc.traits.duplicate()
		c.is_ranged = _orc_is_ranged(orc, registry)
		c.crit_chance = _orc_crit_chance(orc, registry)
		c.heal_on_kill = _orc_heal_on_kill(orc, registry)
		c.round_heal_ally = _orc_round_heal_ally(orc, registry)
		c.wounded_bonus = _orc_wounded_bonus(orc, registry)
		combatants.append(c)
		player_team.append(c)

	var members: Array = enemy_composition.get("members", [])
	var n_idx: int = 0
	for member: Dictionary in members:
		var enemy_id: String = String(member.get("enemy_id", ""))
		var count: int = int(member.get("count", 1))
		var enemy_def: Dictionary = registry.get_enemy(enemy_id)
		if enemy_def.is_empty():
			continue
		for i in count:
			var c := Combatant.new()
			c.unit_id = "enemy_%s_%d" % [enemy_id, n_idx]
			c.display_name = enemy_def.get("name", enemy_id)
			c.team = 1
			c.source = enemy_def
			var es: Dictionary = enemy_def.get("stats", {})
			c.max_hp = int(es.get("max_hp", 20))
			c.current_hp = c.max_hp
			c.attack = int(es.get("attack", 4))
			c.defense = int(es.get("defense", 1))
			c.speed = int(es.get("speed", 3))
			c.base_speed = c.speed
			var et: Array = enemy_def.get("traits", [])
			c.traits.clear()
			for t in et:
				c.traits.append(String(t))
			c.crit_chance = 0.05
			# Boss properties
			c.is_boss = bool(enemy_def.get("is_boss", false))
			if c.is_boss:
				c.boss_phase_threshold = float(enemy_def.get("phase_2_threshold", 0.5))
				c.boss_phase_modifier = enemy_def.get("phase_2_modifier", {})
				c.boss_phase_message = String(enemy_def.get("phase_2_message", "The boss enrages!"))
			# Heal/bonus traits for enemies too
			c.round_heal_ally = _team_trait_round_heal(c, registry)
			combatants.append(c)
			enemy_team.append(c)
			n_idx += 1

	events.append({
		"kind": EV_BATTLE_START,
		"player_count": player_team.size(),
		"enemy_count": enemy_team.size(),
		"player_names": player_team.map(func(c): return c.display_name),
		"enemy_names": enemy_team.map(func(c): return c.display_name),
		"biome_modifier": biome_modifier,
	})

	# Apply biome modifier at battle start where applicable.
	_apply_biome_modifier_start(combatants, biome_modifier)

	var round_num := 0
	while round_num < MAX_ROUNDS:
		round_num += 1
		events.append({"kind": EV_ROUND_START, "round": round_num})

		# Biome modifier round expiry
		_apply_biome_modifier_round(combatants, biome_modifier, round_num)

		# Action order
		var actors: Array = combatants.duplicate()
		actors.sort_custom(func(a, b):
			if a.speed == b.speed:
				return a.unit_id < b.unit_id
			return a.speed > b.speed
		)

		for actor: Combatant in actors:
			if actor.current_hp <= 0:
				continue
			var target: Combatant = _find_target(actor, combatants)
			if target == null:
				break
			var is_crit: bool = rng.roll_chance(actor.crit_chance)
			var raw: int = max(1, actor.attack - int(target.defense / 2))
			var damage: float = float(raw)
			if is_crit:
				damage *= 2.0
			if actor.wounded_bonus > 0.0 and target.current_hp * 2 < target.max_hp:
				damage *= (1.0 + actor.wounded_bonus)
			var damage_int: int = max(1, int(damage))
			var taken: int = min(target.current_hp, damage_int)
			target.current_hp -= taken
			events.append({
				"kind": EV_ATTACK,
				"round": round_num,
				"attacker_id": actor.unit_id,
				"attacker_name": actor.display_name,
				"target_id": target.unit_id,
				"target_name": target.display_name,
				"damage": taken,
				"crit": is_crit,
				"target_hp_after": target.current_hp,
			})
			# Boss phase 2 trigger
			if target.is_boss and not target.phase_2_triggered:
				if target.current_hp > 0 and float(target.current_hp) <= float(target.max_hp) * target.boss_phase_threshold:
					target.phase_2_triggered = true
					var atk_bonus: int = int(target.boss_phase_modifier.get("attack", 0))
					var def_bonus: int = int(target.boss_phase_modifier.get("defense", 0))
					var spd_bonus: int = int(target.boss_phase_modifier.get("speed", 0))
					target.attack += atk_bonus
					target.defense += def_bonus
					target.speed += spd_bonus
					target.base_speed += spd_bonus
					events.append({
						"kind": EV_PHASE_CHANGE,
						"round": round_num,
						"unit_id": target.unit_id,
						"unit_name": target.display_name,
						"message": target.boss_phase_message,
						"attack_bonus": atk_bonus,
						"defense_bonus": def_bonus,
						"speed_bonus": spd_bonus,
					})
			if target.current_hp <= 0:
				events.append({
					"kind": EV_DEATH,
					"round": round_num,
					"victim_id": target.unit_id,
					"victim_name": target.display_name,
					"killer_id": actor.unit_id,
					"killer_name": actor.display_name,
					"victim_team": target.team,
				})
				# Heal-on-kill
				if actor.heal_on_kill > 0 and actor.current_hp > 0:
					var before: int = actor.current_hp
					actor.current_hp = min(actor.max_hp, actor.current_hp + actor.heal_on_kill)
					var healed: int = actor.current_hp - before
					if healed > 0:
						events.append({
							"kind": EV_HEAL,
							"round": round_num,
							"unit_id": actor.unit_id,
							"unit_name": actor.display_name,
							"amount": healed,
						})
				# Vengeful: living allies of the victim's team gain +2 attack permanently
				_apply_vengeful_on_death(target, combatants)
				# Player orc kill counter
				if actor.team == 0 and actor.source is Orc:
					(actor.source as Orc).kills += 1
				if _team_dead(player_team):
					return _finalize(events, false, round_num, player_team, enemy_team, combatants)
				if _team_dead(enemy_team):
					return _finalize(events, true, round_num, player_team, enemy_team, combatants)
		# End-of-round: round-heal traits (Shaman, Hedge Witch)
		_apply_round_heals(combatants, events, round_num)
		if _team_dead(player_team):
			return _finalize(events, false, round_num, player_team, enemy_team, combatants)
		if _team_dead(enemy_team):
			return _finalize(events, true, round_num, player_team, enemy_team, combatants)

	return _finalize(events, false, round_num, player_team, enemy_team, combatants)


static func _find_target(actor: Combatant, all: Array) -> Variant:
	var enemy_team_id: int = 1 - actor.team
	var candidates: Array = []
	for c: Combatant in all:
		if c.team == enemy_team_id and c.current_hp > 0:
			candidates.append(c)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a, b):
		if a.current_hp == b.current_hp:
			return a.unit_id < b.unit_id
		return a.current_hp < b.current_hp
	)
	return candidates[0]


static func _team_dead(team: Array) -> bool:
	for c: Combatant in team:
		if c.current_hp > 0:
			return false
	return true


static func _finalize(
	events: Array[Dictionary],
	victory: bool,
	rounds: int,
	player_team: Array,
	enemy_team: Array,
	_combatants: Array
) -> Dictionary:
	var player_survivors: Array = []
	var player_dead: Array = []
	var enemy_dead: Array = []
	for c: Combatant in player_team:
		if c.current_hp > 0:
			player_survivors.append({
				"unit_id": c.unit_id,
				"name": c.display_name,
				"hp_after": c.current_hp,
				"source": c.source,
			})
		else:
			player_dead.append({
				"unit_id": c.unit_id,
				"name": c.display_name,
				"source": c.source,
			})
	for c: Combatant in enemy_team:
		if c.current_hp <= 0:
			enemy_dead.append({
				"unit_id": c.unit_id,
				"name": c.display_name,
				"enemy_def": c.source,
			})
	events.append({
		"kind": EV_BATTLE_END,
		"victory": victory,
		"rounds": rounds,
		"player_survivor_count": player_survivors.size(),
		"player_dead_count": player_dead.size(),
		"enemy_dead_count": enemy_dead.size(),
	})
	return {
		"victory": victory,
		"rounds": rounds,
		"events": events,
		"player_survivors": player_survivors,
		"player_dead": player_dead,
		"enemy_dead": enemy_dead,
	}


static func _team_attack_bonus_from(player_orcs: Array, registry: Node) -> int:
	## Sum of all team_modifiers.attack from leader-like traits AND gear (e.g., Warband Banner).
	var bonus := 0
	for orc: Orc in player_orcs:
		if not orc.is_alive():
			continue
		for tid in orc.traits:
			var t: Dictionary = registry.get_trait(String(tid))
			var tm: Dictionary = t.get("team_modifiers", {})
			bonus += int(tm.get("attack", 0))
		for slot in orc.equipped_gear:
			var g: Dictionary = registry.get_gear(orc.equipped_gear[slot])
			var gm: Dictionary = g.get("team_modifiers", {})
			bonus += int(gm.get("attack", 0))
	return bonus


static func _orc_is_ranged(orc: Orc, registry: Node) -> bool:
	for slot in orc.equipped_gear:
		var g: Dictionary = registry.get_gear(orc.equipped_gear[slot])
		if bool(g.get("is_ranged", false)):
			return true
	return false


static func _orc_crit_chance(orc: Orc, registry: Node) -> float:
	var base := 0.05
	var ranged := _orc_is_ranged(orc, registry)
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		base += float(t.get("crit_chance_bonus", 0.0))
		if ranged:
			base += float(t.get("ranged_crit_bonus", 0.0))
	return clampf(base, 0.0, 0.95)


static func _orc_heal_on_kill(orc: Orc, registry: Node) -> int:
	var total := 0
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		var ok: Dictionary = t.get("on_kill", {})
		total += int(ok.get("heal", 0))
	return total


static func _orc_round_heal_ally(orc: Orc, registry: Node) -> int:
	var total := 0
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		total += int(t.get("round_heal_ally", 0))
	return total


static func _orc_wounded_bonus(orc: Orc, registry: Node) -> float:
	var total := 0.0
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		total += float(t.get("wounded_target_bonus", 0.0))
	return total


static func _team_trait_round_heal(c: Combatant, registry: Node) -> int:
	var total := 0
	for tid in c.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		total += int(t.get("round_heal_ally", 0))
	return total


static func _apply_round_heals(combatants: Array, events: Array[Dictionary], round_num: int) -> void:
	## For each combatant with round_heal_ally > 0, heal the most-wounded living ally on their team.
	for healer: Combatant in combatants:
		if healer.current_hp <= 0 or healer.round_heal_ally <= 0:
			continue
		var target: Combatant = null
		var worst_gap: int = 0
		for c: Combatant in combatants:
			if c.team != healer.team or c.current_hp <= 0:
				continue
			var gap: int = c.max_hp - c.current_hp
			if gap > worst_gap:
				worst_gap = gap
				target = c
		if target != null and worst_gap > 0:
			var before: int = target.current_hp
			target.current_hp = min(target.max_hp, target.current_hp + healer.round_heal_ally)
			var amt: int = target.current_hp - before
			if amt > 0:
				events.append({
					"kind": EV_HEAL,
					"round": round_num,
					"unit_id": target.unit_id,
					"unit_name": target.display_name,
					"healer_name": healer.display_name,
					"amount": amt,
				})


static func _apply_vengeful_on_death(victim: Combatant, combatants: Array) -> void:
	## Allies of the victim (same team, alive) with Vengeful trait gain +2 attack permanently.
	for c: Combatant in combatants:
		if c.team != victim.team or c.unit_id == victim.unit_id:
			continue
		if c.current_hp <= 0:
			continue
		if c.traits.has("vengeful") and not c.vengeful_pending:
			c.attack += 2
			c.vengeful_pending = 1


static func _apply_biome_modifier_start(combatants: Array, modifier: Dictionary) -> void:
	if modifier.is_empty():
		return
	var rule: String = String(modifier.get("rule", ""))
	if rule == "enemy_speed_bonus_early":
		var bonus: int = int(modifier.get("params", {}).get("bonus", 1))
		for c: Combatant in combatants:
			if c.team == 1:
				c.speed += bonus  # Will be removed after N rounds in _apply_biome_modifier_round


static func _apply_biome_modifier_round(combatants: Array, modifier: Dictionary, round_num: int) -> void:
	if modifier.is_empty():
		return
	var rule: String = String(modifier.get("rule", ""))
	if rule == "enemy_speed_bonus_early":
		var rounds: int = int(modifier.get("params", {}).get("rounds", 3))
		if round_num == rounds + 1:
			# Expire bonus
			for c: Combatant in combatants:
				if c.team == 1:
					c.speed = c.base_speed
