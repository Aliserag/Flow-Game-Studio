class_name ResolutionScreen
extends Control
## Resolution screen: shows battle outcome, loot, dead orcs.
## Reads last_battle_result from CampaignHolder.
## "Continue" calls CampaignController.continue_from_resolution() then routes
## to TavernScreen (run active) or GameOverScreen (run ended).


func _ready() -> void:
	var result: Dictionary = CampaignHolder.last_battle_result
	_populate(result)


func _populate(result: Dictionary) -> void:
	var victory: bool = result.get("victory", false)

	var title: Label = $VBox/TitleLabel
	if victory:
		title.text = "VICTORY"
		title.theme_override_colors["font_color"] = Color(0.788, 0.659, 0.298, 1.0)
	else:
		title.text = "DEFEAT"
		title.theme_override_colors["font_color"] = Color(0.545, 0.102, 0.102, 1.0)

	var stats: Label = $VBox/StatsLabel
	var rounds: int = int(result.get("rounds", 0))
	var killed: int = int(result.get("enemies_killed", 0))
	var rewards: Dictionary = result.get("rewards", {})
	var gold_gained: int = int(rewards.get("gold", 0))
	var xp_each: int = int(rewards.get("xp_per_orc", 0))
	var drops: Array = rewards.get("drops", [])
	stats.text = "Rounds: %d    Enemies killed: %d\nGold gained: %d    XP per orc: %d\nDrops: %s" % [
		rounds, killed, gold_gained, xp_each,
		", ".join(drops) if not drops.is_empty() else "none",
	]

	var dead_list_node: VBoxContainer = $VBox/ScrollContainer/DeadList
	var player_dead: Array = result.get("player_dead", [])

	if player_dead.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "None fell."
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.6, 0.6, 0.6, 1.0)
		dead_list_node.add_child(lbl)
	else:
		for d in player_dead:
			var orc_name: String
			var killer: String
			if d is Dictionary:
				orc_name = str(d.get("name", "Unknown"))
				killer = str(d.get("killer_name", "unknown"))
			else:
				orc_name = str(d)
				killer = "unknown"
			var lbl: Label = Label.new()
			lbl.text = "%s — FELLED BY %s" % [orc_name, killer]
			lbl.theme_override_font_sizes["font_size"] = 8
			lbl.theme_override_colors["font_color"] = Color(0.545, 0.102, 0.102, 1.0)
			dead_list_node.add_child(lbl)


func _on_continue_pressed() -> void:
	CampaignHolder.controller.continue_from_resolution()
	if RunState.run_active:
		get_tree().change_scene_to_file("res://src/ui/TavernScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://src/ui/GameOverScreen.tscn")
