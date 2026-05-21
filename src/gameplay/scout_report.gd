class_name ScoutReport
extends RefCounted
## Generates a pre-battle intel report exposing archetype NAMES + tier + biome modifier.
## Does NOT expose enemy stats — Pillar 4 (Watch and Learn) is satisfied by
## archetype-recognition skill, not by stat-sheet revelation.


static func generate(composition: Dictionary, biome: Dictionary, registry: Node) -> Dictionary:
	var members_in: Array = composition.get("members", [])
	var members_out: Array = []
	for m: Dictionary in members_in:
		var enemy_id: String = String(m.get("enemy_id", ""))
		var enemy: Dictionary = registry.get_enemy(enemy_id)
		members_out.append({
			"enemy_id": enemy_id,
			"name": enemy.get("name", enemy_id),
			"count": int(m.get("count", 1)),
			"tier": int(enemy.get("tier", 1)),
			"is_boss": bool(enemy.get("is_boss", false)),
		})
	var modifier: Dictionary = biome.get("battle_modifier", {})
	return {
		"composition_id": composition.get("id", ""),
		"composition_name": composition.get("name", ""),
		"composition_tier": int(composition.get("tier", 1)),
		"biome_id": biome.get("id", ""),
		"biome_name": biome.get("name", ""),
		"members": members_out,
		"is_boss_fight": bool(composition.get("is_boss_fight", false)),
		"modifier": {
			"name": modifier.get("name", ""),
			"description": modifier.get("description", ""),
		} if not modifier.is_empty() else {},
	}
