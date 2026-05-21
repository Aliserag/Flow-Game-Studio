class_name MarketScreen
extends Control
## Buy gear from rotating stock, sell what your orcs already have.

@onready var _gold_label: Label = $GoldLabel
@onready var _stock_list: VBoxContainer = $MainArea/StockPanel/StockList
@onready var _roster_list: VBoxContainer = $MainArea/RosterPanel/RosterList
@onready var _leave_button: Button = $LeaveButton


func _ready() -> void:
	RunState.gold_changed.connect(_refresh_hud)
	RunState.market_stock_changed.connect(_refresh_stock)
	RunState.roster_changed.connect(_refresh_roster)
	RunState.phase_changed.connect(_on_phase_changed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_refresh_hud(RunState.gold)
	_refresh_stock()
	_refresh_roster()


func _on_phase_changed(_p: int) -> void:
	if RunState.phase == RunState.Phase.MAP:
		get_tree().change_scene_to_file("res://src/ui/CampaignMapScreen.tscn")


func _refresh_hud(_g: int = 0) -> void:
	_gold_label.text = "Gold: %d" % RunState.gold


func _refresh_stock() -> void:
	for child in _stock_list.get_children():
		child.queue_free()
	for i in RunState.market_stock.size():
		var entry: Dictionary = RunState.market_stock[i]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s (%s) %dg" % [
			String(entry.get("name", "?")),
			String(entry.get("tier", "?")),
			int(entry.get("price", 0))
		]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		# Buy buttons per orc target — keep it simple: one button "Buy → Hero"
		# and one button "Buy → cheapest member without slot filled"
		var btn := Button.new()
		btn.text = "Buy → Hero"
		btn.disabled = int(entry.get("price", 0)) > RunState.gold
		btn.pressed.connect(_on_buy_pressed.bind(i, RunState.hero))
		row.add_child(btn)
		_stock_list.add_child(row)


func _refresh_roster() -> void:
	for child in _roster_list.get_children():
		child.queue_free()
	var orcs: Array[Orc] = []
	if RunState.hero != null:
		orcs.append(RunState.hero)
	for o in RunState.roster:
		orcs.append(o)
	for orc: Orc in orcs:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s (%s)" % [orc.name, orc.archetype_id]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		# For each equipped gear slot, add a "Sell <slot>" button
		for slot: String in orc.equipped_gear.keys():
			var btn := Button.new()
			var gid: String = String(orc.equipped_gear[slot])
			var g: Dictionary = ItemRegistry.get_gear(gid)
			var half: int = int(g.get("price", 0)) / 2
			btn.text = "Sell %s (%dg)" % [slot, half]
			btn.pressed.connect(_on_sell_pressed.bind(orc, slot))
			row.add_child(btn)
		_roster_list.add_child(row)


func _on_buy_pressed(stock_index: int, target_orc: Orc) -> void:
	if target_orc == null:
		return
	CampaignHolder.controller.buy_from_market(stock_index, target_orc)


func _on_sell_pressed(orc: Orc, slot: String) -> void:
	CampaignHolder.controller.sell_orc_gear(orc, slot)


func _on_leave_pressed() -> void:
	CampaignHolder.controller.leave_market()
