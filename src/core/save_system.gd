extends Node
## In-memory save system for G0. localStorage / FileAccess backend at G1.

var _slot: Dictionary = {}
var _meta_progression: Dictionary = {
	"campaigns_started": 0,
	"campaigns_won": 0,
	"hero_deaths": 0,
	"legends": [],
}


func has_save() -> bool:
	return not _slot.is_empty()


func save_run(snapshot: Dictionary) -> void:
	_slot = snapshot.duplicate(true)
	Console.info("Run saved to in-memory slot", "save")


func load_run() -> Dictionary:
	return _slot.duplicate(true) if has_save() else {}


func clear_run() -> void:
	_slot.clear()


func record_campaign_started() -> void:
	_meta_progression["campaigns_started"] = int(_meta_progression.get("campaigns_started", 0)) + 1


func record_campaign_won() -> void:
	_meta_progression["campaigns_won"] = int(_meta_progression.get("campaigns_won", 0)) + 1


func record_hero_death(hero_dict: Dictionary) -> void:
	_meta_progression["hero_deaths"] = int(_meta_progression.get("hero_deaths", 0)) + 1
	var legends: Array = _meta_progression.get("legends", [])
	if hero_dict.get("battles_fought", 0) >= 1:
		legends.append({
			"name": hero_dict.get("name", "unknown"),
			"archetype": hero_dict.get("archetype_id", "unknown"),
			"kills": hero_dict.get("kills", 0),
			"battles": hero_dict.get("battles_fought", 0),
			"killer": hero_dict.get("killer_name", "unknown"),
		})
	_meta_progression["legends"] = legends


func get_meta_progression() -> Dictionary:
	return _meta_progression.duplicate(true)
