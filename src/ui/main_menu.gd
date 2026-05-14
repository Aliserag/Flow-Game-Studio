class_name MainMenu
extends Control
## Main menu screen. Entry point for new runs.
## Instantiates CampaignController via CampaignHolder autoload, then transitions
## to TavernScreen.tscn after begin_new_run().


func _ready() -> void:
	pass


func _on_start_pressed() -> void:
	CampaignHolder.create_controller()
	CampaignHolder.controller.begin_new_run()
	get_tree().change_scene_to_file("res://src/ui/TavernScreen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
