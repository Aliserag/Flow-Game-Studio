extends Control

@onready var solo_btn: Button = $Panel/VBox/SoloButton
@onready var settled_btn: Button = $Panel/VBox/SettledButton
@onready var continue_btn: Button = $Panel/VBox/ContinueButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton
@onready var about_label: Label = $Panel/VBox/About
@onready var difficulty_btn: OptionButton = $Panel/VBox/DifficultyButton
@onready var mapsize_btn: OptionButton = $Panel/VBox/MapSizeButton
@onready var settings_btn: Button = $Panel/VBox/SettingsButton
@onready var settings_menu: Control = $SettingsMenu

const RESUMING_FLAG := "_resuming_save"

func _ready() -> void:
	solo_btn.pressed.connect(_start_solo)
	settled_btn.pressed.connect(_start_settled)
	continue_btn.pressed.connect(_continue_save)
	quit_btn.pressed.connect(func(): get_tree().quit())
	if settings_btn != null:
		settings_btn.pressed.connect(func(): settings_menu.show_panel())
	about_label.text = "v0.3 — survive until the megahorde."
	continue_btn.disabled = not SaveSystem.has_save()
	if continue_btn.disabled:
		continue_btn.text = "CONTINUE (no save)"
	_init_dropdowns()

func _init_dropdowns() -> void:
	if difficulty_btn != null:
		difficulty_btn.clear()
		difficulty_btn.add_item("Tourist", GameState.Difficulty.TOURIST)
		difficulty_btn.add_item("Standard", GameState.Difficulty.STANDARD)
		difficulty_btn.add_item("Apocalypse", GameState.Difficulty.APOCALYPSE)
		difficulty_btn.add_item("Permadeath", GameState.Difficulty.PERMADEATH)
		difficulty_btn.select(GameState.Difficulty.STANDARD)
	if mapsize_btn != null:
		mapsize_btn.clear()
		mapsize_btn.add_item("Quick (10x10)", 0)
		mapsize_btn.add_item("Standard (14x14)", 1)
		mapsize_btn.add_item("Long (20x20)", 2)
		mapsize_btn.select(1)

func _selected_difficulty() -> int:
	if difficulty_btn == null:
		return GameState.Difficulty.STANDARD
	return int(difficulty_btn.get_selected_id())

func _selected_map_size() -> Vector2i:
	if mapsize_btn == null:
		return Vector2i(14, 14)
	match mapsize_btn.get_selected_id():
		0: return Vector2i(10, 10)
		2: return Vector2i(20, 20)
		_: return Vector2i(14, 14)

func _start_solo() -> void:
	GameState.reset_run(GameState.Mode.SOLO, 0, _selected_difficulty(), _selected_map_size())
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")

func _start_settled() -> void:
	GameState.reset_run(GameState.Mode.SETTLED, 0, _selected_difficulty(), _selected_map_size())
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")

func _continue_save() -> void:
	GameState.set_meta(RESUMING_FLAG, true)
	get_tree().change_scene_to_file("res://scenes/GameView.tscn")
