extends Control

@onready var solo_btn: Button = $Panel/VBox/SoloButton
@onready var settled_btn: Button = $Panel/VBox/SettledButton
@onready var continue_btn: Button = $Panel/VBox/ContinueButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton
@onready var about_label: Label = $Panel/VBox/About

const RESUMING_FLAG := "_resuming_save"

func _ready() -> void:
	solo_btn.pressed.connect(_start_solo)
	settled_btn.pressed.connect(_start_settled)
	continue_btn.pressed.connect(_continue_save)
	quit_btn.pressed.connect(func(): get_tree().quit())
	about_label.text = "v0.2 — survive until the megahorde."
	continue_btn.disabled = not SaveSystem.has_save()
	if continue_btn.disabled:
		continue_btn.text = "CONTINUE (no save)"

func _start_solo() -> void:
	GameState.reset_run(GameState.Mode.SOLO)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")

func _start_settled() -> void:
	GameState.reset_run(GameState.Mode.SETTLED)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")

func _continue_save() -> void:
	# Mark a flag in GameState so GameView skips world init.
	GameState.set_meta(RESUMING_FLAG, true)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")
