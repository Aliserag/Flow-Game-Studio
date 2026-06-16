class_name MainMenu
extends Control
## Main menu screen. Entry point for new runs.


func _ready() -> void:
	AudioBus.play_music("menu")


func _on_start_pressed() -> void:
	AudioBus.play_sfx("ui_click")
	CampaignHolder.create_controller()
	CampaignHolder.controller.begin_new_run()
	get_tree().change_scene_to_file("res://src/ui/TavernScreen.tscn")


func _on_quit_pressed() -> void:
	AudioBus.play_sfx("ui_click")
	get_tree().quit()
