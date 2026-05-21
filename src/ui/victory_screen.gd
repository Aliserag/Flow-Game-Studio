class_name VictoryScreen
extends Control

@onready var _stats_label: Label = $StatsLabel
@onready var _continue_button: Button = $ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue)
	SaveSystem.record_campaign_won()
	var lines := PackedStringArray([
		"Hero: %s" % (RunState.hero.name if RunState.hero != null else "—"),
		"Battles fought: %d" % RunState.battles_completed,
		"Battles won: %d" % RunState.battles_won,
		"Fallen of the warband: %d" % RunState.gravestone.size(),
		"Gold at end: %d" % RunState.gold,
	])
	_stats_label.text = "\n".join(lines)


func _on_continue() -> void:
	CampaignHolder.clear()
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
