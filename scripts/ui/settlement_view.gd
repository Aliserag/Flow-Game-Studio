extends Control

# Settlement detail screen. Shows party with stats, food/water reserves with daily
# burn rate, enhancements, and task assignment. Accessible from GameView when at base.

@onready var party_list: VBoxContainer = $Panel/Margin/V/Body/PartyCol/Scroll/List
@onready var reserves_label: RichTextLabel = $Panel/Margin/V/Body/InfoCol/ReservesLabel
@onready var enhancements_label: RichTextLabel = $Panel/Margin/V/Body/InfoCol/EnhancementsLabel
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false)
	EventBus.party_changed.connect(_refresh_if_visible)
	EventBus.supplies_changed.connect(_refresh_if_visible)
	EventBus.day_advanced.connect(_on_day_advanced)

func _on_day_advanced(_d: int) -> void:
	_refresh_if_visible()

func _refresh_if_visible() -> void:
	if visible:
		_populate()

func show_panel() -> void:
	visible = true
	_populate()

func _populate() -> void:
	for c in party_list.get_children():
		c.queue_free()
	# Party with stats and task assignment.
	for s in GameState.party:
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		var name_lbl := Label.new()
		var marker: String = "> " if s.is_lead else "* "
		var faction: String = ""
		if s.faction_revealed:
			faction = "  [%s]" % DataLoader.factions.get(s.faction_id, {}).get("name", s.faction_id)
		name_lbl.text = "%s%s%s   HP %d/%d  ATK %d" % [marker, s.display_name, faction, s.hp, s.max_hp, s.attack]
		v.add_child(name_lbl)
		var stats_lbl := Label.new()
		stats_lbl.text = "    STR %d   SMA %d   STE %d" % [s.strength, s.smarts, s.stealth]
		v.add_child(stats_lbl)
		# Task row.
		var task_row := HBoxContainer.new()
		var task_label := Label.new()
		task_label.text = "    Task: %s" % TaskSystem.task_label(s.daily_task)
		task_label.custom_minimum_size = Vector2(180, 0)
		task_row.add_child(task_label)
		var sid: int = int(s.id)
		for task_id in TaskSystem.TASK_IDS:
			var btn := Button.new()
			btn.text = TaskSystem.task_label(task_id)
			var tid: String = String(task_id)
			btn.pressed.connect(func() -> void:
				TaskSystem.assign_task(sid, tid)
			)
			task_row.add_child(btn)
		var clear_btn := Button.new()
		clear_btn.text = "Idle"
		clear_btn.pressed.connect(func() -> void:
			TaskSystem.assign_task(sid, "")
		)
		task_row.add_child(clear_btn)
		v.add_child(task_row)
		party_list.add_child(row)

	# Reserves with burn rate.
	var food: int = int(GameState.inventory.get("canned_food", 0)) + int(GameState.inventory.get("mre", 0))
	var water: int = int(GameState.inventory.get("water_bottle", 0))
	var burn: int = max(1, GameState.party.size())
	var food_days: float = food / float(max(1, burn))
	var reserve_lines: Array = [
		"[b]Reserves[/b]",
		"Food: %d  (burn %d/day → %.1f days)" % [food, burn, food_days],
		"Water: %d" % water,
		"Scrap: %d   Wood: %d" % [int(GameState.inventory.get("scrap", 0)), int(GameState.inventory.get("wood", 0))],
	]
	reserves_label.text = "\n".join(reserve_lines)

	# Enhancements.
	var enh_lines: Array = ["[b]Built[/b]"]
	if GameState.base_enhancements.is_empty():
		enh_lines.append("[color=gray](none)[/color]")
	for id in GameState.base_enhancements:
		var enh: Dictionary = DataLoader.enhancements.get(id, {})
		enh_lines.append("- %s" % String(enh.get("name", id)))
	if GameState.building_enhancement_id != "":
		var enh2: Dictionary = DataLoader.enhancements.get(GameState.building_enhancement_id, {})
		enh_lines.append("[b]Building[/b]")
		enh_lines.append("- %s (%d days)" % [enh2.get("name", GameState.building_enhancement_id), GameState.building_days_left])
	enhancements_label.text = "\n".join(enh_lines)
