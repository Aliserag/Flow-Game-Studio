class_name BattleScreen
extends Control
## Battle screen: shows both sides, resolves battle, animates events one at a time.
## After animation completes, transitions to ResolutionScreen.
##
## Event timing is governed by EVENT_TIMING — a per-kind table in seconds.
## Kill-banner toasts appear above the event log for "death" events.
## Screen shake is applied to the BattleArea container per hit severity.

## Per-kind delay table (seconds to wait after processing each event kind).
## "death" is longer because art-bible §9 specifies 0.75x speed playback
## (a 0.2s base stretched to ~0.27s). Round-start gets breathing room.
const EVENT_TIMING: Dictionary = {
	"round_start": 0.4,
	"attack_crit": 0.25,
	"attack": 0.2,
	"death": 0.27,
	"phase_change": 0.35,
	"default": 0.2,
}

## Kill-banner tween durations (seconds).
const BANNER_FADE_IN: float = 0.4
const BANNER_HOLD: float = 0.6
const BANNER_FADE_OUT: float = 0.3

@onready var _comp_label: Label = $VBox/HeaderBar/CompLabel
@onready var _enemy_list: VBoxContainer = $VBox/BattleArea/EnemyPanel/EnemyList
@onready var _player_list: VBoxContainer = $VBox/BattleArea/PlayerPanel/PlayerList
@onready var _log_label: Label = $VBox/EventLog
@onready var _action_btn: Button = $VBox/ActionButton
@onready var _battle_area: HBoxContainer = $VBox/BattleArea

## Maps orc id -> HBoxContainer row so we can update HP bars during replay.
var _player_rows: Dictionary = {}
## Current HP values tracked locally during event replay.
var _hp_map: Dictionary = {}
## Battle events to animate through.
var _events: Array = []
var _event_index: int = 0
var _animating: bool = false
## Active kill-banner label (so we can clear it before a new one appears).
var _banner_label: Label = null


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
	# Sprite (composited from base body + scars + gear overlays)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = SpriteComposer.get_orc_sprite(orc)
	sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Scale up 2x for visibility
	sprite.custom_minimum_size = Vector2(48, 64) if orc.is_hero else Vector2(36, 48)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(sprite)

	var lbl: Label = Label.new()
	lbl.name = "NameHp"
	if is_enemy:
		lbl.text = orc.name
	else:
		lbl.text = "%s  %d/%d" % [orc.name, orc.current_hp, orc.max_hp]
	lbl.theme_override_font_sizes["font_size"] = 8
	lbl.theme_override_colors["font_color"] = Palette.OLD_VELLUM
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
		lbl.theme_override_colors["font_color"] = Palette.BONE
		_enemy_list.add_child(lbl)
		return

	for m in members:
		if not m is Dictionary:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var enemy_id: String = String(m.get("enemy_id", ""))
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = SpriteComposer.get_enemy_sprite(enemy_id)
		sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var enemy: Dictionary = ItemRegistry.get_enemy(enemy_id)
		var is_boss: bool = bool(enemy.get("is_boss", false))
		sprite.custom_minimum_size = Vector2(48, 64) if is_boss else Vector2(36, 48)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(sprite)
		var lbl: Label = Label.new()
		lbl.text = "%d × %s" % [int(m.get("count", 1)), str(m.get("name", enemy_id))]
		lbl.theme_override_font_sizes["font_size"] = 8
		var label_color: Color = Palette.WARBAND_GOLD if is_boss else Palette.BONE
		lbl.theme_override_colors["font_color"] = label_color
		row.add_child(lbl)
		_enemy_list.add_child(row)


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

	var delay: float = _delay_for(ev)
	await get_tree().create_timer(delay).timeout
	_animate_next_event()


## Returns the event delay in seconds for this specific event dict.
func _delay_for(ev: Dictionary) -> float:
	var kind: String = ev.get("kind", "")
	if kind == "attack":
		if ev.get("crit", false):
			return EVENT_TIMING["attack_crit"]
		return EVENT_TIMING["attack"]
	if EVENT_TIMING.has(kind):
		return EVENT_TIMING[kind]
	return EVENT_TIMING["default"]


func _process_event(ev: Dictionary) -> void:
	var kind: String = ev.get("kind", "")
	match kind:
		"round_start":
			var round_n: int = int(ev.get("round", 0))
			_log_label.text = "-- Round %d --" % round_n
			_log_label.modulate = Palette.WHITE

		"attack":
			var attacker: String = ev.get("attacker_name", "?")
			var target: String = ev.get("target_name", "?")
			var dmg: int = int(ev.get("damage", 0))
			var is_crit: bool = ev.get("crit", false)
			var target_id: String = str(ev.get("target_id", ""))
			var crit_tag: String = " CRIT!" if is_crit else ""
			_log_label.text = "%s hits %s for %d%s" % [attacker, target, dmg, crit_tag]
			_log_label.modulate = Palette.WHITE
			# Update tracked HP
			if _hp_map.has(target_id):
				_hp_map[target_id] = max(0, _hp_map[target_id] - dmg)
				_update_player_hp_bar(target_id)
			# Screen shake: crit = 6px/10f, normal = 3px/6f
			if is_crit:
				ScreenShake.shake(_battle_area, 6.0, 10, get_tree())
			else:
				ScreenShake.shake(_battle_area, 3.0, 6, get_tree())

		"death":
			var killer: String = ev.get("killer_name", "?")
			var victim: String = ev.get("victim_name", "?")
			# Update event log (plain text fallback)
			_log_label.text = "%s FELLS %s" % [killer.to_upper(), victim.to_upper()]
			_log_label.modulate = Palette.FELL_RED
			# Kill-banner toast
			_show_kill_banner(killer, victim)
			# Death shake: 4px / 8 frames
			ScreenShake.shake(_battle_area, 4.0, 8, get_tree())

		_:
			pass


## Displays a two-part kill-banner toast at upper-center screen.
## Killer name in white, victim name in Fell Red. Format: KILLER FELLS VICTIM.
## Tween: fade in 0.4s → hold 0.6s → fade out 0.3s.
func _show_kill_banner(killer_name: String, victim_name: String) -> void:
	# Remove any previous banner still on screen.
	if _banner_label != null and is_instance_valid(_banner_label):
		_banner_label.queue_free()
		_banner_label = null

	# Use a RichTextLabel so we can colour parts of the text independently.
	var banner: RichTextLabel = RichTextLabel.new()
	banner.bbcode_enabled = true
	banner.text = "[color=#FFFFFF]%s[/color] [color=#8B1A1A]FELLS %s[/color]" % [
		killer_name.to_upper(), victim_name.to_upper()
	]
	banner.fit_content = true
	banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.theme_override_font_sizes["normal_font_size"] = 11

	# Position at the top-centre of the screen using anchor layout.
	banner.set_anchor_and_offset(SIDE_LEFT, 0.5, -150.0)
	banner.set_anchor_and_offset(SIDE_RIGHT, 0.5, 150.0)
	banner.set_anchor_and_offset(SIDE_TOP, 0.0, 8.0)
	banner.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 30.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(banner)
	_banner_label = banner

	# Tween: fade in -> hold -> fade out.
	var tw: Tween = create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, BANNER_FADE_IN)
	tw.tween_interval(BANNER_HOLD)
	tw.tween_property(banner, "modulate:a", 0.0, BANNER_FADE_OUT)
	tw.tween_callback(banner.queue_free)


func _update_player_hp_bar(orc_id: String) -> void:
	if not _player_rows.has(orc_id):
		return
	var row: HBoxContainer = _player_rows[orc_id]
	var lbl: Label = row.get_node_or_null("NameHp")
	if lbl == null:
		return
	var hp: int = _hp_map.get(orc_id, 0)
	var all_orcs: Array = RunState.get_all_living_orcs()
	for orc in all_orcs:
		if orc.id == orc_id:
			lbl.text = "%s  %d/%d" % [orc.name, hp, orc.max_hp]
			if hp <= 0:
				lbl.modulate = Palette.FELL_RED
			return
	# Orc already removed from RunState (dead); just show 0
	lbl.text = lbl.text.split("  ")[0] + "  0/?"
	lbl.modulate = Palette.FELL_RED


func _on_animation_done() -> void:
	_animating = false
	_action_btn.disabled = false
	_action_btn.text = "Continue to Resolution"
	_action_btn.pressed.disconnect(_on_resolve_pressed)
	_action_btn.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/ResolutionScreen.tscn")
