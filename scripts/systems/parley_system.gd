class_name ParleySystem
extends RefCounted

# Builds a parley payload (reuses the EventModal UI) for a stranger NPC.
# Recruit / Trade / Walk away. Recruit reveals faction; some hostile factions
# trigger a betrayal-style outcome on accept.

static func build_parley(npc: Npc) -> Dictionary:
	var faction: Dictionary = DataLoader.factions.get(npc.faction_id, {})
	var faction_name: String = String(faction.get("name", npc.faction_id))
	var alignment: String = String(faction.get("alignment", "neutral"))
	var join_chance: float = float(faction.get("join_chance", 0.5))
	var intro_lines: Array = faction.get("intro_lines", ["Hello."])
	var intro_text: String = String(RNG.pick(intro_lines))

	# Mark faction-warned cannibals visibly if knowledge is present.
	var ominous_warning: String = ""
	if npc.faction_id == "cannibals" and GameState.knowledge.has("cannibal_warning"):
		ominous_warning = "\n\n[color=red]You recognize the look. The careful smile. The clean clothes. Long Pig.[/color]"

	var description: String = "%s says: \"%s\"%s" % [npc.display_name, intro_text, ominous_warning]

	var options: Array = []
	# Recruit option.
	options.append({
		"text": "Invite them to join (%d%% chance)" % int(join_chance * 100),
		"outcomes": _recruit_outcomes(npc, faction_name, alignment, join_chance, faction)
	})
	# Vetting (slower, safer).
	options.append({
		"text": "Question them carefully first",
		"outcomes": [
			{"weight": 100, "text": "You ask careful questions. Their answers tell you more than they meant to. (Faction revealed.)",
				"effects": {"reveal_npc_faction": npc.id}}
		]
	})
	# Trade — opens the TradePanel via a routed effect.
	options.append({
		"text": "Trade",
		"outcomes": [
			{"weight": 100, "text": "%s opens their pack." % npc.display_name,
				"effects": {"open_trade_with_npc": npc.id}}
		]
	})
	# Walk away.
	options.append({
		"text": "Walk away",
		"outcomes": [
			{"weight": 100, "text": "You nod and keep moving.", "effects": {}}
		]
	})

	return {
		"id": "parley_%d" % npc.id,
		"title": "Stranger on the road",
		"description": description,
		"options": options,
		"_parley_npc_id": npc.id  # marker so resolution can clean up the NPC
	}

static func _recruit_outcomes(npc: Npc, faction_name: String, alignment: String,
		join_chance: float, faction: Dictionary) -> Array:
	var success_weight: int = int(join_chance * 100)
	var fail_weight: int = max(1, 100 - success_weight)
	var outs: Array = []

	if alignment == "hostile":
		# Hostile factions accepting your invite is bad.
		outs.append({
			"weight": success_weight,
			"text": "%s smiles. \"Yeah. Yeah, I'd like that.\" They follow you home." % npc.display_name,
			"effects": {
				"recruit_specific_faction": npc.faction_id,
				"reveal_recruit_faction": true,
				"consume_npc": npc.id
			}
		})
		outs.append({
			"weight": fail_weight,
			"text": "%s looks you over and shakes their head. They walk on." % npc.display_name,
			"effects": {"consume_npc": npc.id}
		})
	else:
		outs.append({
			"weight": success_weight,
			"text": "%s smiles, relieved. \"Thank you. I'll pull my weight, I promise.\"" % npc.display_name,
			"effects": {
				"recruit_specific_faction": npc.faction_id,
				"reveal_recruit_faction": true,
				"morale": 1,
				"consume_npc": npc.id
			}
		})
		outs.append({
			"weight": fail_weight,
			"text": "%s hesitates. \"...not yet. Maybe another time.\" They walk on." % npc.display_name,
			"effects": {"consume_npc": npc.id}
		})
	return outs

static func consume_npc(npc_id: int) -> void:
	if GameState.grid == null:
		return
	for e in GameState.grid.entities.duplicate():
		if e is Npc and e.id == npc_id:
			GameState.grid.remove_entity(e)
			break

static func reveal_npc(npc_id: int) -> void:
	if GameState.grid == null:
		return
	for e in GameState.grid.entities:
		if e is Npc and e.id == npc_id:
			e.revealed = true
			# Add to knowledge if cannibal — turns into an in-game warning later.
			if e.faction_id == "cannibals" and not GameState.knowledge.has("cannibal_warning"):
				GameState.knowledge.append("cannibal_warning")
			break
