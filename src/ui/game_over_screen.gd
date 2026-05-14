class_name GameOverScreen
extends Control
## Game over screen: hero is dead, campaign ends.
## Shows career summary and full gravestone.


func _ready() -> void:
	_populate()


func _populate() -> void:
	var subtitle: Label = $VBox/SubtitleLabel
	var stats_label: Label = $VBox/StatsLabel
	var grave_list: VBoxContainer = $VBox/ScrollContainer/GraveList

	# Hero info from last gravestone entry or RunState.hero
	var gravestone: Array = RunState.gravestone
	var hero_name: String = "Unknown"
	var killer: String = "unknown"

	if not gravestone.is_empty():
		# Hero death is recorded last in permadeath flow
		for d in gravestone:
			if d.get("is_hero", false):
				hero_name = str(d.get("name", "Unknown"))
				killer = str(d.get("killer_name", "unknown"))
				break
		# If no hero found in gravestone, fallback to last entry
		if hero_name == "Unknown" and not gravestone.is_empty():
			var last: Dictionary = gravestone[gravestone.size() - 1]
			hero_name = str(last.get("name", "Unknown"))
			killer = str(last.get("killer_name", "unknown"))
	elif RunState.hero != null:
		hero_name = RunState.hero.name

	subtitle.text = "%s fell in battle, slain by %s." % [hero_name, killer]

	var battles: int = RunState.battles_completed
	var won: int = RunState.battles_won
	var orcs_lost: int = gravestone.size()
	var gold_remaining: int = RunState.gold
	stats_label.text = "Battles fought: %d    Battles won: %d\nOrcs lost: %d    Gold remaining: %d" % [
		battles, won, orcs_lost, gold_remaining,
	]

	for child in grave_list.get_children():
		child.queue_free()

	if gravestone.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "The warband left no grave-marks."
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.6, 0.6, 0.6, 1.0)
		grave_list.add_child(lbl)
		return

	for d in gravestone:
		var lbl: Label = Label.new()
		var n: String = str(d.get("name", "?"))
		var arch: String = str(d.get("archetype_id", "?"))
		var k: String = str(d.get("killer_name", "unknown"))
		lbl.text = "%s [%s] — felled by %s" % [n, arch, k]
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.545, 0.102, 0.102, 1.0)
		grave_list.add_child(lbl)


func _on_new_campaign_pressed() -> void:
	CampaignHolder.clear()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
