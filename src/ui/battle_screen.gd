class_name BattleScreen
extends Control
## Battle screen: shows both sides, resolves battle, animates events one at a time.
## After animation completes, transitions to ResolutionScreen.

const EVENT_DELAY: float = 0.2

@onready var _comp_label: Label = $VBox/HeaderBar/CompLabel
@onready var _enemy_list: VBoxContainer = $VBox/BattleArea/EnemyPanel/EnemyList
@onready var _player_list: VBoxContainer = $VBox/BattleArea/PlayerPanel/PlayerList
@onready var _log_label: Label = $VBox/EventLog
@onready var _action_btn: Button = $VBox/ActionButton

## Maps orc id -> HBoxContainer row so we can update HP bars during replay.
var _player_rows: Dictionary = {}
## Current HP values tracked locally during event replay.
var _hp_map: Dictionary = {}
## Battle events to animate through.
var _events: Array = []
var _event_index: int = 0
var _animating: bool = false


func _ready() -> void:
	_comp_label.text = "BATTLE"
	_action_btn.text = "RESOLVE BATTLE"
	_action_btn.pressed.connect(_on_resolve_pressed)
	_build_player_side()
	_build_enemy_side()


func _build_player_side() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_player_rows.clear()
	_hp_map.clear()

	var orcs: Array = RunState.get_all_living_orcs()
	for orc in orcs:
		_hp_map[orc.id] = orc.current_hp
		var row: HBoxContainer = _make_orc_row(orc, false)
		_player_rows[orc.id] = row
		_player_list.add_child(row)


func _make_orc_row(orc: Orc, is_enemy: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "row_" + orc.id

	var arch_id: String = orc.archetype_id.to_lower() if not is_enemy else "enemy"
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10.0, 10.0)
	if is_enemy:
		swatch.color = Color(0.4, 0.4, 0.4, 1.0)
	else:
		var cols: Dictionary = {
			"berserker": Color(0.545, 0.102, 0.102, 1.0),
			"brute":     Color(0.396, 0.267, 0.153, 1.0),
			"archer":    Color(0.153, 0.396, 0.153, 1.0),
			"chieftain": Color(0.788, 0.659, 0.298, 1.0),
			"shaman":    Color(0.4,   0.1,   0.6,   1.0),
		}
		swatch.color = cols.get(arch_id, Color(0.4, 0.4, 0.4, 1.0))

	var lbl: Label = Label.new()
	lbl.name = "NameHp"
	if is_enemy:
		lbl.text = orc.name
	else:
		lbl.text = "%s  %d/%d" % [orc.name, orc.current_hp, orc.max_hp]
	lbl.theme_override_font_sizes["font_size"] = 8
	lbl.theme_override_colors["font_color"] = Color(0.9, 0.9, 0.9, 1.0)

	row.add_child(swatch)
	row.add_child(lbl)
	return row


func _build_enemy_side() -> void:
	for child in _enemy_list.get_children():
		child.queue_free()

	var comp: Dictionary = {}
	if CampaignHolder.controller != null:
		comp = CampaignHolder.controller.current_enemy_comp

	var comp_name: String = comp.get("name", "Unknown Enemy")
	var tier: int = int(comp.get("tier", 1))
	_comp_label.text = "%s  [Tier %d]" % [comp_name, tier]

	var members: Array = comp.get("members", [])
	if members.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "Enemy composition unknown"
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.8, 0.8, 0.8, 1.0)
		_enemy_list.add_child(lbl)
		return

	for m in members:
		var lbl: Label = Label.new()
		if m is Dictionary:
			lbl.text = "%s" % str(m.get("name", "Enemy"))
		else:
			lbl.text = str(m)
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.8, 0.8, 0.8, 1.0)
		_enemy_list.add_child(lbl)


func _on_resolve_pressed() -> void:
	_action_btn.disabled = true
	_action_btn.text = "Resolving..."

	var result: Dictionary = CampaignHolder.controller.resolve_battle()
	CampaignHolder.last_battle_result = result
	_events = result.get("events", [])
	_event_index = 0
	_animating = true
	_animate_next_event()


func _animate_next_event() -> void:
	if _event_index >= _events.size():
		_on_animation_done()
		return

	var ev: Dictionary = _events[_event_index]
	_event_index += 1
	_process_event(ev)

	await get_tree().create_timer(EVENT_DELAY).timeout
	_animate_next_event()


func _process_event(ev: Dictionary) -> void:
	var kind: String = ev.get("kind", "")
	match kind:
		"round_start":
			var round_n: int = int(ev.get("round", 0))
			_log_label.text = "-- Round %d --" % round_n
			_log_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

		"attack":
			var attacker: String = ev.get("attacker_name", "?")
			var target: String = ev.get("target_name", "?")
			var dmg: int = int(ev.get("damage", 0))
			var is_crit: bool = ev.get("crit", false)
			var target_id: String = str(ev.get("target_id", ""))
			var crit_tag: String = " CRIT!" if is_crit else ""
			_log_label.text = "%s hits %s for %d%s" % [attacker, target, dmg, crit_tag]
			_log_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
			# Update tracked HP
			if _hp_map.has(target_id):
				_hp_map[target_id] = max(0, _hp_map[target_id] - dmg)
				_update_player_hp_bar(target_id)

		"death":
			var killer: String = ev.get("killer_name", "?")
			var victim: String = ev.get("victim_name", "?")
			_log_label.text = "%s FELLS %s" % [killer, victim]
			_log_label.modulate = Color(0.545, 0.102, 0.102, 1.0)

		_:
			pass


func _update_player_hp_bar(orc_id: String) -> void:
	if not _player_rows.has(orc_id):
		return
	var row: HBoxContainer = _player_rows[orc_id]
	var lbl: Label = row.get_node_or_null("NameHp")
	if lbl == null:
		return
	# Find orc name from RunState for the label
	var hp: int = _hp_map.get(orc_id, 0)
	# Find max_hp from RunState
	var all_orcs: Array = RunState.get_all_living_orcs()
	for orc in all_orcs:
		if orc.id == orc_id:
			lbl.text = "%s  %d/%d" % [orc.name, hp, orc.max_hp]
			if hp <= 0:
				lbl.modulate = Color(0.545, 0.102, 0.102, 1.0)
			return
	# Orc already removed from RunState (dead); just show 0
	lbl.text = lbl.text.split("  ")[0] + "  0/?"
	lbl.modulate = Color(0.545, 0.102, 0.102, 1.0)


func _on_animation_done() -> void:
	_animating = false
	_action_btn.disabled = false
	_action_btn.text = "Continue to Resolution"
	_action_btn.pressed.disconnect(_on_resolve_pressed)
	_action_btn.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/ResolutionScreen.tscn")
