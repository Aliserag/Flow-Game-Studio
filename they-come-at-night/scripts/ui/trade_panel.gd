extends Control

@onready var title_lbl: Label = $Panel/Margin/V/Title
@onready var npc_list: VBoxContainer = $Panel/Margin/V/Body/NpcCol/Scroll/List
@onready var your_list: VBoxContainer = $Panel/Margin/V/Body/YourCol/Scroll/List
@onready var status_lbl: Label = $Panel/Margin/V/Status
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

var _npc: Npc = null
var _stock: Dictionary = {}

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false)

func open_trade(npc: Npc) -> void:
	_npc = npc
	_stock = TradeSystem.generate_stock(npc)
	visible = true
	title_lbl.text = "Trading with %s — currency: scrap" % npc.display_name
	status_lbl.text = "You have %d scrap." % int(GameState.inventory.get("scrap", 0))
	_populate()

func _populate() -> void:
	for c in npc_list.get_children():
		c.queue_free()
	for c in your_list.get_children():
		c.queue_free()
	# NPC stock — buy from them.
	if _stock.is_empty():
		var l := Label.new()
		l.text = "(they have nothing to trade)"
		npc_list.add_child(l)
	else:
		var keys: Array = _stock.keys()
		keys.sort()
		for item_id in keys:
			var item: Dictionary = DataLoader.items.get(item_id, {})
			var price: int = TradeSystem.sell_price(item_id, _npc)
			var n: int = int(_stock[item_id])
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%dx %s — %d scrap" % [n, item.get("name", item_id), price]
			l.custom_minimum_size = Vector2(220, 0)
			row.add_child(l)
			var btn := Button.new()
			btn.text = "BUY"
			if not TradeSystem.can_buy(item_id, _npc):
				btn.disabled = true
			var iid := item_id
			btn.pressed.connect(func() -> void:
				if TradeSystem.execute_buy(iid, _npc, _stock):
					_refresh_status()
					_populate()
			)
			row.add_child(btn)
			npc_list.add_child(row)
	# Your inventory — sell to them. Skip currency itself.
	var keys2: Array = GameState.inventory.keys()
	keys2.sort()
	for item_id in keys2:
		if item_id == TradeSystem.CURRENCY:
			continue
		var item: Dictionary = DataLoader.items.get(item_id, {})
		var price: int = TradeSystem.buy_price(item_id, _npc)
		var n: int = int(GameState.inventory[item_id])
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%dx %s — %d scrap" % [n, item.get("name", item_id), price]
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "SELL"
		var iid := item_id
		btn.pressed.connect(func() -> void:
			if TradeSystem.execute_sell(iid, _npc, _stock):
				_refresh_status()
				_populate()
		)
		row.add_child(btn)
		your_list.add_child(row)

func _refresh_status() -> void:
	status_lbl.text = "You have %d scrap." % int(GameState.inventory.get("scrap", 0))
