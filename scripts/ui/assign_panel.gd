extends Control

@onready var party_list: VBoxContainer = $Panel/Margin/V/Body/PartyCol/PartyScroll/PartyList
@onready var stash_list: VBoxContainer = $Panel/Margin/V/Body/StashCol/StashScroll/StashList
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

var _selected_survivor_id: int = -1

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false)
	EventBus.party_changed.connect(_on_party_or_supplies_changed)
	EventBus.supplies_changed.connect(_on_party_or_supplies_changed)

func _on_party_or_supplies_changed() -> void:
	if visible:
		_populate()

func show_panel() -> void:
	visible = true
	if GameState.party.size() > 0 and _selected_survivor_id == -1:
		_selected_survivor_id = GameState.party[0].id
	_populate()

func _populate() -> void:
	for c in party_list.get_children():
		c.queue_free()
	for c in stash_list.get_children():
		c.queue_free()

	for s in GameState.party:
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		var btn := Button.new()
		var faction := ""
		if s.faction_revealed:
			faction = " — %s" % DataLoader.factions.get(s.faction_id, {}).get("name", s.faction_id)
		var marker := ""
		if s.id == _selected_survivor_id: marker = "> "
		btn.text = "%s%s%s   HP %d/%d  ATK %d" % [marker, s.display_name, faction, s.hp, s.max_hp, s.attack]
		var sid: int = int(s.id)
		btn.pressed.connect(func() -> void:
			_selected_survivor_id = sid
			_populate()
		)
		v.add_child(btn)
		var assigned: Array = GameState.assignments.get(s.id, [])
		if not assigned.is_empty():
			var inner := HBoxContainer.new()
			for it in assigned:
				var item_btn := Button.new()
				item_btn.text = "x %s" % DataLoader.items.get(it, {}).get("name", it)
				var iid: String = String(it)
				var sid2: int = int(s.id)
				item_btn.pressed.connect(func(): InventorySystem.unassign(sid2, iid))
				inner.add_child(item_btn)
			v.add_child(inner)
		party_list.add_child(row)

	# Stash with assign / use buttons.
	if GameState.inventory.is_empty():
		var l := Label.new()
		l.text = "(empty)"
		stash_list.add_child(l)
	else:
		var keys: Array = GameState.inventory.keys()
		keys.sort()
		for item_id in keys:
			var item: Dictionary = DataLoader.items.get(item_id, {})
			var n: int = int(GameState.inventory[item_id])
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%dx %s" % [n, item.get("name", item_id)]
			l.custom_minimum_size = Vector2(180, 0)
			row.add_child(l)
			var category: String = String(item.get("category", ""))
			if category in ["weapon", "armor"]:
				var assign_btn := Button.new()
				assign_btn.text = "Assign"
				if _selected_survivor_id < 0:
					assign_btn.disabled = true
				var iid: String = String(item_id)
				assign_btn.pressed.connect(func(): InventorySystem.assign(_selected_survivor_id, iid))
				row.add_child(assign_btn)
			elif category in ["consumable", "food"]:
				var use_btn := Button.new()
				use_btn.text = "Use"
				if _selected_survivor_id < 0:
					use_btn.disabled = true
				var iid: String = String(item_id)
				use_btn.pressed.connect(func():
					var r: Dictionary = InventorySystem.use_consumable(_selected_survivor_id, iid)
					EventBus.log_info(r.msg)
				)
				row.add_child(use_btn)
			stash_list.add_child(row)
