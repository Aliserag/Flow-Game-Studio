extends Control

@onready var solo_btn: Button = $Panel/VBox/SoloButton
@onready var settled_btn: Button = $Panel/VBox/SettledButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton
@onready var about_label: Label = $Panel/VBox/About

func _ready() -> void:
	solo_btn.pressed.connect(_start_solo)
	settled_btn.pressed.connect(_start_settled)
	quit_btn.pressed.connect(func(): get_tree().quit())
	about_label.text = "v0.1 — survive until the megahorde."

func _start_solo() -> void:
	GameState.reset_run(GameState.Mode.SOLO)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")

func _start_settled() -> void:
	GameState.reset_run(GameState.Mode.SETTLED)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")
