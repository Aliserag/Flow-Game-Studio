extends Control

# Top-level gameplay screen. Owns the grid renderer and side panels,
# routes input, and drives turn flow.

@onready var grid_renderer: Control = $Layout/GridArea/Scroll/GridRenderer
@onready var hud_label: RichTextLabel = $Layout/Right/HUD/HUDText
@onready var party_label: RichTextLabel = $Layout/Right/Party/PartyText
@onready var inventory_label: RichTextLabel = $Layout/Right/Inventory/InventoryText
@onready var action_box: HFlowContainer = $Layout/GridArea/Bottom/Actions
@onready var log_label: RichTextLabel = $Layout/GridArea/Bottom/LogScroll/LogText
@onready var tile_info_label: RichTextLabel = $Layout/Right/TileInfo/TileInfoText
@onready var event_modal: Control = $EventModal
@onready var build_panel: Control = $BuildPanel
@onready var assign_panel: Control = $AssignPanel
@onready var knowledge_panel: Control = $KnowledgePanel
@onready var trade_panel: Control = $TradePanel
@onready var settlement_view: Control = $SettlementView
@onready var game_over: Control = $GameOver
@onready var game_over_label: Label = $GameOver/Panel/V/Message
@onready var game_over_btn: Button = $GameOver/Panel/V/MenuBtn

var _selected_tile: Vector2i = Vector2i(-1, -1)
var _move_mode: bool = false

func _ready() -> void:
	if GameState.has_meta("_resuming_save"):
		GameState.remove_meta("_resuming_save")
		if SaveSystem.load_run():
			EventBus.log_good("Save loaded.")
		else:
			EventBus.log_warn("Save failed to load — starting fresh.")
			_init_world()
	else:
		_init_world()
	_wire_signals()
	_rebuild_actions()
	_refresh_all()

func _init_world() -> void:
	GameState.grid = MapGenerator.generate(GameState.map_size)
	# Place lead survivor on a non-building tile near centre.
	var lead := Survivor.make_lead()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	# Seed starting inventory.
	GameState.add_to_inventory("knife", 1)
	GameState.add_to_inventory("bandage", 2)
	GameState.add_to_inventory("canned_food", 3)
	GameState.add_to_inventory("water_bottle", 2)
	GameState.add_to_inventory("scrap", 4)
	GameState.add_to_inventory("wood", 4)
	# Auto-assign knife to lead.
	InventorySystem.assign(lead.id, "knife")

	var spawn := _find_spawn(GameState.grid)
	lead.pos = spawn
	GameState.grid.add_entity(lead)

	if GameState.mode == GameState.Mode.SETTLED:
		BaseSystem.establish(spawn, GameState.grid)
		GameState.add_to_inventory("scrap", 6)
		GameState.add_to_inventory("wood", 6)
		GameState.day = 1

	TurnManager.recompute_vision(GameState.grid)
	# A few initial zombies elsewhere on the map.
	for _i in 4:
		var z: ZombieUnit = ZombieUnit.make("single")
		z.pos = GameState.grid.random_edge_position()
		GameState.grid.add_entity(z)
	# A wandering NPC.
	var npc: Npc = Npc.spawn_random()
	npc.pos = GameState.grid.random_edge_position()
	GameState.grid.add_entity(npc)
	EventBus.log_info("Day 1. You are %s. Survive." % lead.display_name)

func _find_nearby_npc(lead) -> Npc:
	if GameState.grid == null:
		return null
	for e in GameState.grid.entities:
		if e is Npc and GameState.grid.chebyshev(e.pos, lead.pos) <= 1:
			return e
	return null

func _find_spawn(g: Grid) -> Vector2i:
	# Try centre, then ripple outward.
	var c := g.size / 2
	for r in range(0, max(g.size.x, g.size.y)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p := Vector2i(c.x + dx, c.y + dy)
				if not g.in_bounds(p): continue
				var t := g.get_tile(p)
				if t != null and not t.is_building() and not t.has_hostile():
					return p
	return c

func _wire_signals() -> void:
	grid_renderer.tile_clicked.connect(_on_tile_clicked)
	grid_renderer.tile_hovered.connect(_on_tile_hovered)
	EventBus.log_message.connect(_on_log)
	EventBus.hud_refresh_requested.connect(_refresh_all)
	EventBus.party_changed.connect(_refresh_all)
	EventBus.supplies_changed.connect(_refresh_all)
	EventBus.day_advanced.connect(func(_d): _refresh_all())
	EventBus.player_moved.connect(func(_a, _b):
		TurnManager.recompute_vision(GameState.grid)
		grid_renderer.refresh()
		_refresh_all()
	)
	EventBus.entity_added.connect(func(_e): grid_renderer.refresh())
	EventBus.entity_removed.connect(func(_e): grid_renderer.refresh())
	EventBus.entity_moved.connect(func(_e, _a, _b): grid_renderer.refresh())
	EventBus.request_event_modal.connect(_on_event_modal_request)
	EventBus.open_trade_request.connect(_on_open_trade_request)
	EventBus.game_over.connect(_on_game_over)
	game_over_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	# Pause overlay buttons.
	var pause_resume: Button = $PauseOverlay/Panel/Margin/V/ResumeBtn if has_node("PauseOverlay/Panel/Margin/V/ResumeBtn") else null
	var pause_quit: Button = $PauseOverlay/Panel/Margin/V/QuitBtn if has_node("PauseOverlay/Panel/Margin/V/QuitBtn") else null
	if pause_resume != null:
		pause_resume.pressed.connect(_toggle_pause)
	if pause_quit != null:
		pause_quit.pressed.connect(func() -> void:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		)

func _on_event_modal_request(payload: Dictionary) -> void:
	GameState.phase = GameState.Phase.EVENT
	event_modal.show_event(payload)
	# resume after modal closed
	if not event_modal.is_connected("choice_selected", _on_event_resolved):
		event_modal.choice_selected.connect(_on_event_resolved)

func _on_event_resolved(_idx: int) -> void:
	GameState.phase = GameState.Phase.PLAYING
	_refresh_all()

func _on_open_trade_request(npc_id: int) -> void:
	if GameState.grid == null: return
	for e in GameState.grid.entities:
		if e is Npc and e.id == npc_id:
			trade_panel.open_trade(e)
			return

func _on_tile_clicked(c: Vector2i) -> void:
	_selected_tile = c
	if _move_mode:
		_move_mode = false
		var ok := TurnManager.attempt_move(GameState.grid, c)
		if ok:
			# moving spends the day; auto end-turn
			TurnManager.end_turn(GameState.grid)
		_rebuild_actions()
	_refresh_tile_info()

func _on_tile_hovered(c: Vector2i) -> void:
	_selected_tile = c
	_refresh_tile_info()

func _on_log(msg: String, severity: String) -> void:
	var color := "white"
	match severity:
		"warn": color = "yellow"
		"danger": color = "tomato"
		"good": color = "lightgreen"
	log_label.append_text("[color=%s]Day %d: %s[/color]\n" % [color, GameState.day, msg])

func _refresh_all() -> void:
	_refresh_hud()
	_refresh_party()
	_refresh_inventory()
	_refresh_tile_info()
	_rebuild_actions()
	grid_renderer.refresh()

func _refresh_hud() -> void:
	var lines: Array = []
	lines.append("[b]Day %d[/b]" % GameState.day)
	lines.append("Morale: %d/10" % GameState.morale)
	if GameState.has_base:
		var base_t: Tile = GameState.grid.get_tile(GameState.base_pos)
		lines.append("Base: %s @ (%d,%d)" % [base_t.display_name() if base_t else "?", GameState.base_pos.x, GameState.base_pos.y])
		lines.append("Defense: +%d" % (GameState.base_defense_bonus + _enh_defense()))
		if GameState.building_enhancement_id != "":
			var enh: Dictionary = DataLoader.enhancements.get(GameState.building_enhancement_id, {})
			lines.append("Building %s: %d days" % [enh.get("name", GameState.building_enhancement_id), GameState.building_days_left])
	else:
		lines.append("Base: [color=gray]none[/color]")
	if not GameState.swarm_pending.is_empty():
		var k: String = String(GameState.swarm_pending["kind"])
		var eta: int = int(GameState.swarm_pending["eta_days"])
		lines.append("[color=orange]%s incoming: %d days[/color]" % [k.capitalize(), eta])
	if GameState.megahorde_unlocked:
		lines.append("[color=red][b]MEGAHORDE in %d days[/b][/color]" % GameState.megahorde_eta)
	hud_label.text = "\n".join(lines)

func _enh_defense() -> int:
	var d := 0
	for id in GameState.base_enhancements:
		d += int(DataLoader.enhancements.get(id, {}).get("defense_bonus", 0))
	return d

func _refresh_party() -> void:
	var lines: Array = ["[b]Party (%d)[/b]" % GameState.party.size()]
	for s in GameState.party:
		var faction_str: String = ""
		if s.faction_revealed:
			faction_str = " — %s" % DataLoader.factions.get(s.faction_id, {}).get("name", s.faction_id)
		var hp_color := "lightgreen"
		if s.hp <= s.max_hp / 3: hp_color = "tomato"
		elif s.hp <= s.max_hp / 2: hp_color = "yellow"
		var bullet := "* "
		if s.is_lead: bullet = ">"
		var infect: String = " [color=red][infected][/color]" if s.infected else ""
		lines.append("%s [b]%s[/b]%s [color=%s]HP %d/%d[/color]%s" % [bullet, s.display_name, faction_str, hp_color, s.hp, s.max_hp, infect])
		# Show items.
		var assigned: Array = GameState.assignments.get(s.id, [])
		if not assigned.is_empty():
			var names: Array = []
			for it in assigned:
				names.append(String(DataLoader.items.get(it, {}).get("name", it)))
			lines.append("    [color=gray]%s[/color]" % ", ".join(names))
	party_label.text = "\n".join(lines)

func _refresh_inventory() -> void:
	var lines: Array = ["[b]Stash[/b]"]
	if GameState.inventory.is_empty():
		lines.append("[color=gray](empty)[/color]")
	else:
		var keys: Array = GameState.inventory.keys()
		keys.sort()
		for item_id in keys:
			var n: int = int(GameState.inventory[item_id])
			var name: String = String(DataLoader.items.get(item_id, {}).get("name", item_id))
			lines.append("%dx %s" % [n, name])
	inventory_label.text = "\n".join(lines)

func _refresh_tile_info() -> void:
	if _selected_tile.x < 0 or GameState.grid == null:
		tile_info_label.text = "[color=gray]Hover or click a tile[/color]"
		return
	var t: Tile = GameState.grid.get_tile(_selected_tile)
	if t == null:
		tile_info_label.text = "[color=gray](off map)[/color]"
		return
	var lines: Array = []
	if not t.explored:
		lines.append("[color=gray]Unexplored.[/color]")
	else:
		lines.append("[b]%s[/b] (%d,%d)" % [t.display_name(), t.pos.x, t.pos.y])
		lines.append("[color=gray]%s[/color]" % t.data().get("description", ""))
		lines.append("Defense +%d, Escape %+d" % [t.defense_bonus(), t.escape_bonus()])
		if t.has_base:
			lines.append("[color=yellow]YOUR BASE[/color]")
		if not t.searched and t.supplies > 0:
			lines.append("Possible supplies here.")
		elif t.searched:
			lines.append("[color=gray]Already searched.[/color]")
		if t.visible and not t.entities.is_empty():
			for e in t.entities:
				lines.append("- %s" % e.describe())
	tile_info_label.text = "\n".join(lines)

func _rebuild_actions() -> void:
	for c in action_box.get_children():
		c.queue_free()
	if GameState.phase != GameState.Phase.PLAYING:
		return
	if GameState.party.is_empty():
		return
	var lead = GameState.party[0]
	var t: Tile = GameState.grid.get_tile(lead.pos)

	_add_action("Move (click adjacent tile)", func():
		_move_mode = true
		EventBus.log_info("Click an adjacent tile to move.")
	)
	if t != null and not t.searched:
		_add_action("Scavenge tile", func():
			var r := InventorySystem.scavenge_tile(GameState.grid)
			EventBus.log_info(r.msg)
			TurnManager.end_turn(GameState.grid)
		)
	if t != null:
		if not GameState.has_base:
			_add_action("Establish base here", func():
				BaseSystem.establish(lead.pos, GameState.grid)
				_refresh_all()
			)
		elif lead.pos == GameState.base_pos:
			_add_action("Open Build menu", func():
				build_panel.show_panel()
			)
			_add_action("Settlement", func():
				settlement_view.show_panel()
			)
			_add_action("Abandon base", func():
				BaseSystem.abandon()
				_refresh_all()
			)
	# Parley with any NPC on lead's tile or adjacent.
	var nearby_npc: Npc = _find_nearby_npc(lead)
	if nearby_npc != null:
		var npc_ref := nearby_npc
		var npc_label: String = "Talk to %s" % nearby_npc.display_name
		if nearby_npc.faction_id == "cannibals" and GameState.knowledge.has("cannibal_warning"):
			npc_label += "  ⚠ LONG PIG"
		_add_action(npc_label, func():
			var payload: Dictionary = ParleySystem.build_parley(npc_ref)
			EventBus.request_event_modal.emit(payload)
		)

	_add_action("Open Inventory / Assign", func():
		assign_panel.show_panel()
	)
	_add_action("Knowledge (%d)" % GameState.knowledge.size(), func():
		knowledge_panel.show_panel()
	)
	_add_action("Rest (end day)", func():
		# Resting tries to heal the lead 1 HP.
		GameState.adjust_lead_hp(1)
		TurnManager.end_turn(GameState.grid)
	)
	_add_action("End Day (no action)", func():
		TurnManager.end_turn(GameState.grid)
	)
	_add_action("Save", func():
		if SaveSystem.save():
			EventBus.log_good("Saved.")
		else:
			EventBus.log_warn("Save failed.")
	)

func _add_action(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.pressed.connect(cb)
	action_box.add_child(b)

func _on_game_over(victory: bool, summary: String) -> void:
	game_over.visible = true
	if victory:
		game_over_label.text = "VICTORY\n\n" + summary + "\n\nDays survived: %d\nZombies killed: %d\nRecruits: %d" % [GameState.stats.days_survived, GameState.stats.zombies_killed, GameState.stats.npcs_recruited]
	else:
		game_over_label.text = "GAME OVER\n\n" + summary + "\n\nDays survived: %d\nZombies killed: %d\nRecruits: %d" % [GameState.stats.days_survived, GameState.stats.zombies_killed, GameState.stats.npcs_recruited]

func _input(event: InputEvent) -> void:
	# Esc: prefer cancelling Move mode, else open pause overlay.
	if event.is_action_pressed("ui_cancel"):
		if _move_mode:
			_move_mode = false
			_rebuild_actions()
			return
		if not _any_modal_open():
			_toggle_pause()
	# F12: take a screenshot (G8).
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_take_screenshot()

func _any_modal_open() -> bool:
	return event_modal.visible or build_panel.visible or assign_panel.visible \
		or knowledge_panel.visible or trade_panel.visible or settlement_view.visible \
		or game_over.visible

func _toggle_pause() -> void:
	var overlay: Control = $PauseOverlay if has_node("PauseOverlay") else null
	if overlay == null:
		return
	overlay.visible = not overlay.visible
	get_tree().paused = overlay.visible

func _take_screenshot() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
	var img: Image = get_viewport().get_texture().get_image()
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://screenshots/screenshot-%s.png" % ts
	var err := img.save_png(path)
	if err == OK:
		EventBus.log_good("Screenshot saved: %s" % path)
	else:
		EventBus.log_warn("Screenshot failed (err %d)" % err)
