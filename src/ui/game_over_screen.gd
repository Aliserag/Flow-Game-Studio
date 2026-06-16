class_name GameOverScreen
extends Control
## Game over screen: hero is dead, campaign ends.
## Shows career summary and full gravestone.
## Typography: Title variant for headline, Header for section labels,
## orc names in Fell Red, dates/stats in Warband Gold, body text in Old Vellum.


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
		for d in gravestone:
			if d.get("is_hero", false):
				hero_name = str(d.get("name", "Unknown"))
				killer = str(d.get("killer_name", "unknown"))
				break
		if hero_name == "Unknown" and not gravestone.is_empty():
			var last: Dictionary = gravestone[gravestone.size() - 1]
			hero_name = str(last.get("name", "Unknown"))
			killer = str(last.get("killer_name", "unknown"))
	elif RunState.hero != null:
		hero_name = RunState.hero.name

	# Subtitle: Old Vellum body text.
	subtitle.text = "%s fell in battle, slain by %s." % [hero_name, killer]
	subtitle.theme_override_colors["font_color"] = Palette.OLD_VELLUM

	# Stats: Warband Gold.
	var battles: int = RunState.battles_completed
	var won: int = RunState.battles_won
	var orcs_lost: int = gravestone.size()
	var gold_remaining: int = RunState.gold
	stats_label.text = "Battles fought: %d    Battles won: %d\nOrcs lost: %d    Gold remaining: %d" % [
		battles, won, orcs_lost, gold_remaining,
	]
	stats_label.theme_override_colors["font_color"] = Palette.WARBAND_GOLD

	for child in grave_list.get_children():
		child.queue_free()

	if gravestone.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "The warband left no grave-marks."
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Palette.OLD_VELLUM
		grave_list.add_child(lbl)
		return

	for d in gravestone:
		var entry: VBoxContainer = VBoxContainer.new()

		# Orc name — Fell Red.
		var name_lbl: Label = Label.new()
		var n: String = str(d.get("name", "?"))
		name_lbl.text = n.to_upper()
		name_lbl.theme_override_font_sizes["font_size"] = 10
		name_lbl.theme_override_colors["font_color"] = Palette.FELL_RED

		# Detail line — Warband Gold (date stand-in: archetype).
		var arch: String = str(d.get("archetype_id", "?"))
		var k: String = str(d.get("killer_name", "unknown"))
		var detail_lbl: Label = Label.new()
		detail_lbl.text = "[%s] — felled by %s" % [arch, k]
		detail_lbl.theme_override_font_sizes["font_size"] = 8
		detail_lbl.theme_override_colors["font_color"] = Palette.WARBAND_GOLD

		entry.add_child(name_lbl)
		entry.add_child(detail_lbl)
		grave_list.add_child(entry)


func _on_new_campaign_pressed() -> void:
	CampaignHolder.clear()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
