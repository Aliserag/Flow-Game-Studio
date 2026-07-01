extends Control

@onready var list: VBoxContainer = $Panel/Margin/V/Scroll/List
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false)
	EventBus.enhancement_built.connect(_on_built)
	EventBus.supplies_changed.connect(_on_supplies_changed)

func _on_built(_id: String) -> void:
	if visible:
		_populate()

func _on_supplies_changed() -> void:
	if visible:
		_populate()

func show_panel() -> void:
	visible = true
	_populate()

func _populate() -> void:
	for c in list.get_children():
		c.queue_free()
	for id in DataLoader.enhancements.keys():
		var enh: Dictionary = DataLoader.enhancements[id]
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		var title := Label.new()
		var built: bool = GameState.base_enhancements.has(id)
		var building: bool = GameState.building_enhancement_id == id
		var prefix := ""
		if built: prefix = "[BUILT] "
		elif building: prefix = "[BUILDING %d days] " % GameState.building_days_left
		title.text = "%s%s (Tier %d)" % [prefix, enh.get("name", id), int(enh.get("tier", 1))]
		v.add_child(title)
		var desc := Label.new()
		desc.text = String(enh.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(desc)
		var cost_lbl := Label.new()
		var bits: Array = []
		for k in enh.get("cost", {}).keys():
			bits.append("%dx %s" % [int(enh["cost"][k]), k])
		var requires: Array = enh.get("requires", [])
		var req_str := ""
		if not requires.is_empty():
			req_str = "  (requires: %s)" % ", ".join(requires)
		cost_lbl.text = "Cost: %s, %d days%s" % [", ".join(bits), int(enh.get("build_days", 1)), req_str]
		v.add_child(cost_lbl)
		if not built and not building:
			var btn := Button.new()
			btn.text = "Begin construction"
			var check := BaseSystem.can_build(id)
			if not check.ok:
				btn.disabled = true
				btn.text += "  (%s)" % check.reason
			var build_id: String = String(id)
			btn.pressed.connect(func() -> void:
				if BaseSystem.start_build(build_id):
					_populate()
			)
			v.add_child(btn)
		list.add_child(row)
