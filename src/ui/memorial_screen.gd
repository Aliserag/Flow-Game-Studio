class_name MemorialScreen
extends Control
## Memorial screen: read-only wall of all fallen orcs.
## No gameplay effect (Pillar 2).


func _ready() -> void:
	_populate()


func _populate() -> void:
	var count_label: Label = $VBox/CountLabel
	var grave_list: VBoxContainer = $VBox/ScrollContainer/GraveList
	var gravestone: Array = RunState.gravestone

	count_label.text = "Total fallen: %d" % gravestone.size()

	for child in grave_list.get_children():
		child.queue_free()

	if gravestone.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "None have fallen yet. The warband walks."
		lbl.theme_override_font_sizes["font_size"] = 9
		lbl.theme_override_colors["font_color"] = Color(0.4, 0.4, 0.3, 1.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grave_list.add_child(lbl)
		return

	for d in gravestone:
		var entry: VBoxContainer = VBoxContainer.new()
		entry.custom_minimum_size = Vector2(0.0, 28.0)

		var name_lbl: Label = Label.new()
		name_lbl.text = str(d.get("name", "Unknown"))
		name_lbl.theme_override_font_sizes["font_size"] = 10
		name_lbl.theme_override_colors["font_color"] = Color(0.545, 0.102, 0.102, 1.0)

		var detail_lbl: Label = Label.new()
		var arch: String = str(d.get("archetype_id", "?"))
		var battles: int = int(d.get("battles_fought", 0))
		var kills: int = int(d.get("kills", 0))
		var killer: String = str(d.get("killer_name", "unknown"))
		detail_lbl.text = "[%s]  Battles: %d  Kills: %d  Felled by: %s" % [arch, battles, kills, killer]
		detail_lbl.theme_override_font_sizes["font_size"] = 7
		detail_lbl.theme_override_colors["font_color"] = Color(0.3, 0.3, 0.2, 1.0)
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var sep: HSeparator = HSeparator.new()

		entry.add_child(name_lbl)
		entry.add_child(detail_lbl)
		entry.add_child(sep)
		grave_list.add_child(entry)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/TavernScreen.tscn")
