class_name ScoutScreen
extends Control
## Pre-battle intel. Exposes archetype names + tier + biome modifier.
## Does NOT expose enemy stats (Pillar 4).

@onready var _composition_label: Label = $CompositionLabel
@onready var _members_list: VBoxContainer = $MembersList
@onready var _modifier_label: Label = $ModifierPanel/ModifierLabel
@onready var _commit_button: Button = $CommitButton


func _ready() -> void:
	RunState.phase_changed.connect(_on_phase_changed)
	_commit_button.pressed.connect(_on_commit)
	_render()


func _on_phase_changed(_p: int) -> void:
	if RunState.phase == RunState.Phase.BATTLE_PREP or RunState.phase == RunState.Phase.BATTLE:
		get_tree().change_scene_to_file("res://src/ui/BattleScreen.tscn")


func _render() -> void:
	var report: Dictionary = CampaignHolder.controller.current_scout_report
	if report.is_empty():
		_composition_label.text = "(no scout report)"
		return
	var name_text: String = String(report.get("composition_name", "?"))
	if report.get("is_boss_fight", false):
		name_text = "BOSS — " + name_text
	_composition_label.text = "%s  (tier %d)" % [name_text, int(report.get("composition_tier", 1))]
	for child in _members_list.get_children():
		child.queue_free()
	for m: Dictionary in report.get("members", []):
		var label := Label.new()
		var count: int = int(m.get("count", 1))
		var name_str: String = String(m.get("name", "?"))
		var tier: int = int(m.get("tier", 1))
		label.text = "  %d × %s  (tier %d)" % [count, name_str, tier]
		if m.get("is_boss", false):
			label.modulate = Color(0.788, 0.659, 0.298)  # warband gold
		_members_list.add_child(label)
	var mod: Dictionary = report.get("modifier", {})
	if mod.is_empty():
		_modifier_label.text = "Biome: no special modifier."
	else:
		_modifier_label.text = "Biome Modifier — %s\n%s" % [
			String(mod.get("name", "?")),
			String(mod.get("description", ""))
		]


func _on_commit() -> void:
	CampaignHolder.controller.commit_to_battle()
	get_tree().change_scene_to_file("res://src/ui/BattleScreen.tscn")
