class_name MemorialScreen
extends Control
## Memorial screen: read-only wall of all fallen orcs.
## No gameplay effect (Pillar 2).
## Typography: orc names in Fell Red, dates/detail in Warband Gold,
## body text in Old Vellum — per art-bible §5.


func _ready() -> void:
	_populate()


func _populate() -> void:
	var count_label: Label = $VBox/CountLabel
	var grave_list: VBoxContainer = $VBox/ScrollContainer/GraveList
	var gravestone: Array = RunState.gravestone

	count_label.text = "Total fallen: %d" % gravestone.size()
	count_label.theme_override_colors["font_color"] = Palette.WARBAND_GOLD

	for child in grave_list.get_children():
		child.queue_free()

	if gravestone.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "None have fallen yet. The warband walks."
		lbl.theme_override_font_sizes["font_size"] = 9
		lbl.theme_override_colors["font_color"] = Palette.OLD_VELLUM
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grave_list.add_child(lbl)
		return

	for d in gravestone:
		var entry: VBoxContainer = VBoxContainer.new()
		entry.custom_minimum_size = Vector2(0.0, 28.0)

		# Orc name in Fell Red — Title variant size.
		var name_lbl: Label = Label.new()
		name_lbl.text = str(d.get("name", "Unknown")).to_upper()
		name_lbl.theme_override_font_sizes["font_size"] = 12
		name_lbl.theme_override_colors["font_color"] = Palette.FELL_RED

		# Battle detail line in Warband Gold.
		var arch: String = str(d.get("archetype_id", "?"))
		var battles: int = int(d.get("battles_fought", 0))
		var kills: int = int(d.get("kills", 0))
		var date_detail: Label = Label.new()
		date_detail.text = "[%s]  Battles: %d  Kills: %d" % [arch, battles, kills]
		date_detail.theme_override_font_sizes["font_size"] = 8
		date_detail.theme_override_colors["font_color"] = Palette.WARBAND_GOLD

		# Epitaph / killer in Old Vellum body text.
		var killer: String = str(d.get("killer_name", "unknown"))
		var epitaph: Label = Label.new()
		epitaph.text = "Felled by %s." % killer
		epitaph.theme_override_font_sizes["font_size"] = 7
		epitaph.theme_override_colors["font_color"] = Palette.OLD_VELLUM
		epitaph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var sep: HSeparator = HSeparator.new()

		entry.add_child(name_lbl)
		entry.add_child(date_detail)
		entry.add_child(epitaph)
		entry.add_child(sep)
		grave_list.add_child(entry)


func _on_back_pressed() -> void:
	if RunState.run_active:
		get_tree().change_scene_to_file("res://src/ui/CampaignMapScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
