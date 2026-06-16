class_name TavernScreen
extends Control
## Tavern screen: hire candidates, view roster, navigate to battle or memorial.
## Binds to RunState signals for reactive updates.

## Archetype color map for ColorRect placeholders (G0, no art assets).
const ARCHETYPE_COLORS: Dictionary = {
	"berserker": Color(0.545, 0.102, 0.102, 1.0),
	"brute":     Color(0.396, 0.267, 0.153, 1.0),
	"archer":    Color(0.153, 0.396, 0.153, 1.0),
	"chieftain": Color(0.788, 0.659, 0.298, 1.0),
	"shaman":    Color(0.4,   0.1,   0.6,   1.0),
}
const ENEMY_COLOR: Color = Color(0.4, 0.4, 0.4, 1.0)

@onready var _gold_label: Label = $HUDBar/GoldLabel
@onready var _hero_label: Label = $HUDBar/HeroLabel
@onready var _battles_label: Label = $HUDBar/BattlesLabel
@onready var _roster_list: VBoxContainer = $MainArea/RosterPanel/RosterList
@onready var _candidates_list: HBoxContainer = $MainArea/CandidatesPanel/CandidatesList


func _ready() -> void:
	AudioBus.play_music("tavern")
	RunState.gold_changed.connect(_on_gold_changed)
	RunState.roster_changed.connect(_refresh_roster)
	RunState.hero_changed.connect(_refresh_roster)
	RunState.candidates_changed.connect(_refresh_candidates)
	_refresh_hud()
	_refresh_roster()
	_refresh_candidates()


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Gold: %d" % new_gold
	_refresh_candidates()


func _refresh_hud() -> void:
	_gold_label.text = "Gold: %d" % RunState.gold
	_battles_label.text = "Battles: %d" % RunState.battles_completed
	if RunState.hero != null:
		_hero_label.text = "%s  HP: %d/%d" % [
			RunState.hero.name,
			RunState.hero.current_hp,
			RunState.hero.max_hp,
		]
	else:
		_hero_label.text = "No Hero"


func _refresh_roster() -> void:
	_refresh_hud()
	for child in _roster_list.get_children():
		child.queue_free()

	var all_orcs: Array = []
	if RunState.hero != null:
		all_orcs.append(RunState.hero)
	for o in RunState.roster:
		all_orcs.append(o)

	for orc in all_orcs:
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 18.0)

		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(12.0, 12.0)
		swatch.color = ARCHETYPE_COLORS.get(orc.archetype_id.to_lower(), ENEMY_COLOR)

		var lbl: Label = Label.new()
		var hero_tag: String = " [HERO]" if orc.is_hero else ""
		lbl.text = "%s%s  Lv%d  HP:%d/%d  [%s]" % [
			orc.name, hero_tag, orc.level,
			orc.current_hp, orc.max_hp,
			orc.archetype_id,
		]
		lbl.theme_override_font_sizes["font_size"] = 8
		lbl.theme_override_colors["font_color"] = Color(0.102, 0.102, 0.122, 1.0)

		row.add_child(swatch)
		row.add_child(lbl)
		_roster_list.add_child(row)


func _refresh_candidates() -> void:
	for child in _candidates_list.get_children():
		child.queue_free()

	var max_size: int = int(RunState.economy().get("max_roster_size", 6)) - 1
	var roster_full: bool = RunState.roster.size() >= max_size

	for candidate in RunState.candidates:
		var price: int = RunState.price_for(candidate)
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(80.0, 100.0)

		var vbox: VBoxContainer = VBoxContainer.new()

		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(0.0, 24.0)
		swatch.color = ARCHETYPE_COLORS.get(candidate.archetype_id.to_lower(), ENEMY_COLOR)

		var name_lbl: Label = Label.new()
		name_lbl.text = candidate.name
		name_lbl.theme_override_font_sizes["font_size"] = 8
		name_lbl.theme_override_colors["font_color"] = Color(0.102, 0.102, 0.122, 1.0)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var arch_lbl: Label = Label.new()
		arch_lbl.text = candidate.archetype_id
		arch_lbl.theme_override_font_sizes["font_size"] = 7
		arch_lbl.theme_override_colors["font_color"] = Color(0.3, 0.3, 0.3, 1.0)
		arch_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var traits_lbl: Label = Label.new()
		traits_lbl.text = ", ".join(candidate.traits) if not candidate.traits.is_empty() else "No traits"
		traits_lbl.theme_override_font_sizes["font_size"] = 7
		traits_lbl.theme_override_colors["font_color"] = Color(0.2, 0.2, 0.2, 1.0)
		traits_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var price_lbl: Label = Label.new()
		price_lbl.text = "%d Gold" % price
		price_lbl.theme_override_font_sizes["font_size"] = 8
		price_lbl.theme_override_colors["font_color"] = Color(0.788, 0.659, 0.298, 1.0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var hire_btn: Button = Button.new()
		hire_btn.text = "Hire"
		hire_btn.disabled = roster_full or not RunState.can_afford(price)
		var orc_ref: Orc = candidate
		hire_btn.pressed.connect(func() -> void: _on_hire_pressed(orc_ref))

		vbox.add_child(swatch)
		vbox.add_child(name_lbl)
		vbox.add_child(arch_lbl)
		vbox.add_child(traits_lbl)
		vbox.add_child(price_lbl)
		vbox.add_child(hire_btn)
		card.add_child(vbox)
		_candidates_list.add_child(card)


func _on_hire_pressed(orc: Orc) -> void:
	CampaignHolder.controller.hire(orc)


func _on_battle_pressed() -> void:
	# G1 flow: leave tavern → campaign map. The map's nodes drive the battle entry.
	CampaignHolder.controller.leave_tavern_for_map()
	get_tree().change_scene_to_file("res://src/ui/CampaignMapScreen.tscn")


func _on_memorial_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/MemorialScreen.tscn")


func _on_quit_run_pressed() -> void:
	CampaignHolder.clear()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")


func _exit_tree() -> void:
	if RunState.gold_changed.is_connected(_on_gold_changed):
		RunState.gold_changed.disconnect(_on_gold_changed)
	if RunState.roster_changed.is_connected(_refresh_roster):
		RunState.roster_changed.disconnect(_refresh_roster)
	if RunState.hero_changed.is_connected(_refresh_roster):
		RunState.hero_changed.disconnect(_refresh_roster)
	if RunState.candidates_changed.is_connected(_refresh_candidates):
		RunState.candidates_changed.disconnect(_refresh_candidates)
