class_name CombatResolver
extends RefCounted
## Pure-function combat resolution.
## Takes a player warband and enemy composition. Returns ordered event log + outcome.
## Deterministic when seeded RNG is provided.
##
## Combat model (G0):
## - Tick-based round system. Each round, units act in speed order (high speed first).
## - Each acting unit targets the lowest-HP opposing unit (front-line bias by index).
## - Damage = max(1, attacker.attack - defender.defense * 0.5), then crit chance check.
## - Crit multiplies damage by 2.
## - Battle ends when one side is fully dead.

const MAX_ROUNDS: int = 50  # safety cap

# Event kinds (string for clarity in logs / replays)
const EV_BATTLE_START := "battle_start"
const EV_ROUND_START := "round_start"
const EV_ATTACK := "attack"
const EV_DEATH := "death"
const EV_BATTLE_END := "battle_end"


class Combatant:
	extends RefCounted
	var unit_id: String           # orc.id for player orcs; "enemy_<id>_<n>" for enemies
	var display_name: String
	var team: int                 # 0 = player, 1 = enemy
	var source: Variant           # the Orc instance for players, the enemy dict for enemies
	var current_hp: int
	var max_hp: int
	var attack: int
	var defense: int
	var speed: int
	var is_ranged: bool = false
	var crit_chance: float = 0.05
	var traits: Array[String] = []
	var heal_on_kill: int = 0


static func resolve(
	player_orcs: Array,        # Array[Orc] living members
	enemy_composition: Dictionary,
	registry: Node,
	rng: Node                  # the Rng autoload or compatible
) -> Dictionary:
	var events: Array[Dictionary] = []
	var combatants: Array = []
	var player_team := []
	var enemy_team := []

	# Build player combatants
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
		c.traits = orc.traits.duplicate()
		c.is_ranged = _orc_is_ranged(orc, registry)
		c.crit_chance = _orc_crit_chance(orc, registry)
		c.heal_on_kill = _orc_heal_on_kill(orc, registry)
		combatants.append(c)
		player_team.append(c)

	# Build enemy combatants from composition
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
			var et: Array = enemy_def.get("traits", [])
			c.traits.clear()
			for t in et:
				c.traits.append(String(t))
			c.crit_chance = 0.05
			combatants.append(c)
			enemy_team.append(c)
			n_idx += 1

	events.append({
		"kind": EV_BATTLE_START,
		"player_count": player_team.size(),
		"enemy_count": enemy_team.size(),
		"player_names": player_team.map(func(c): return c.display_name),
		"enemy_names": enemy_team.map(func(c): return c.display_name),
	})

	var round_num := 0
	while round_num < MAX_ROUNDS:
		round_num += 1
		events.append({"kind": EV_ROUND_START, "round": round_num})
		# Build action order by current speed (stable sort: original index break tie)
		var actors: Array = combatants.duplicate()
		actors.sort_custom(func(a, b):
			if a.speed == b.speed:
				return a.unit_id < b.unit_id
			return a.speed > b.speed
		)
		for actor: Combatant in actors:
			if actor.current_hp <= 0:
				continue
			# Find target
			var target: Combatant = _find_target(actor, combatants)
			if target == null:
				break  # No targets — one team is wiped
			# Roll for crit
			var is_crit: bool = rng.roll_chance(actor.crit_chance)
			var raw_damage: int = max(1, actor.attack - int(actor.defense * 0.0) - int(target.defense / 2))
			if raw_damage < 1:
				raw_damage = 1
			var damage: int = raw_damage * (2 if is_crit else 1)
			# Apply damage
			var taken: int = min(target.current_hp, damage)
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
			# Death?
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
				# Heal-on-kill traits (e.g., Bloodthirsty)
				if actor.heal_on_kill > 0 and actor.current_hp > 0:
					var before: int = actor.current_hp
					actor.current_hp = min(actor.max_hp, actor.current_hp + actor.heal_on_kill)
					var healed: int = actor.current_hp - before
					if healed > 0:
						events.append({
							"kind": "heal",
							"round": round_num,
							"unit_id": actor.unit_id,
							"unit_name": actor.display_name,
							"amount": healed,
						})
				# Update player orc kill count if applicable
				if actor.team == 0 and actor.source is Orc:
					(actor.source as Orc).kills += 1
				# Check end condition
				if _team_dead(player_team):
					return _finalize(events, false, round_num, player_team, enemy_team, combatants)
				if _team_dead(enemy_team):
					return _finalize(events, true, round_num, player_team, enemy_team, combatants)
		# end of round
		if _team_dead(player_team):
			return _finalize(events, false, round_num, player_team, enemy_team, combatants)
		if _team_dead(enemy_team):
			return _finalize(events, true, round_num, player_team, enemy_team, combatants)

	# Hit safety cap — treat as player loss (stalemate is bad design surface)
	return _finalize(events, false, round_num, player_team, enemy_team, combatants)


static func _find_target(actor: Combatant, all: Array) -> Variant:
	var enemy_team_id: int = 1 - actor.team
	var candidates: Array = []
	for c: Combatant in all:
		if c.team == enemy_team_id and c.current_hp > 0:
			candidates.append(c)
	if candidates.is_empty():
		return null
	# Target lowest-HP alive opponent; tie-break on unit_id for determinism
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
	## Sum of all "team_modifiers.attack" granted by leader-like traits across the warband.
	var bonus := 0
	for orc: Orc in player_orcs:
		if not orc.is_alive():
			continue
		for tid in orc.traits:
			var t: Dictionary = registry.get_trait(String(tid))
			var tm: Dictionary = t.get("team_modifiers", {})
			bonus += int(tm.get("attack", 0))
	return bonus


static func _orc_is_ranged(orc: Orc, registry: Node) -> bool:
	for slot in orc.equipped_gear:
		var g: Dictionary = registry.get_gear(orc.equipped_gear[slot])
		if bool(g.get("is_ranged", false)):
			return true
	return false


static func _orc_crit_chance(orc: Orc, registry: Node) -> float:
	var base := 0.05
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		base += float(t.get("crit_chance_bonus", 0.0))
		if _orc_is_ranged(orc, registry):
			base += float(t.get("ranged_crit_bonus", 0.0))
	return clampf(base, 0.0, 0.95)


static func _orc_heal_on_kill(orc: Orc, registry: Node) -> int:
	var total := 0
	for tid in orc.traits:
		var t: Dictionary = registry.get_trait(String(tid))
		var ok: Dictionary = t.get("on_kill", {})
		total += int(ok.get("heal", 0))
	return total
