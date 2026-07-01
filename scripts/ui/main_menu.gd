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
@onready var credits_btn: Button = $Panel/VBox/CreditsButton
@onready var credits_screen: Control = $CreditsScreen

const RESUMING_FLAG := "_resuming_save"

func _ready() -> void:
	solo_btn.pressed.connect(_start_solo)
	settled_btn.pressed.connect(_start_settled)
	continue_btn.pressed.connect(_continue_save)
	quit_btn.pressed.connect(func(): get_tree().quit())
	if settings_btn != null:
		settings_btn.pressed.connect(func(): settings_menu.show_panel())
	if credits_btn != null:
		credits_btn.pressed.connect(func(): credits_screen.show_panel())
	about_label.text = "%s — survive until the megahorde." % BuildInfo.build_id
	# Menu music — switches to gameplay ambient when the run starts.
	if AudioDirector != null:
		AudioDirector.play_menu_music()
	_maybe_show_content_warning()
	_maybe_show_last_crash_hint()

func _maybe_show_content_warning() -> void:
	if SettingsService == null:
		return
	if SettingsService.tutorial_shown:  # piggyback the first-run flag
		return
	# Custom in-canvas overlay instead of OS Window — needed because the
	# web build's canvas can't physically contain an OS-level Window.
	var overlay := Control.new()
	overlay.name = "ContentWarningOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.85)
	overlay.add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_top = -180
	panel.offset_right = 280
	panel.offset_bottom = 180
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var title := Label.new()
	title.text = "Content warning"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.4))
	v.add_child(title)
	var body := Label.new()
	body.text = "This game depicts a zombie apocalypse with themes of death, betrayal, cannibalism, infection, hopelessness, and the loss of children. The graphics are 32x32 pixel art (nothing explicit) but the tone is dark.\n\nIf those themes are not for you, the game is not for you."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var btn := Button.new()
	btn.text = "I understand"
	btn.pressed.connect(func() -> void:
		SettingsService.tutorial_shown = true
		SettingsService.save_to_disk()
		overlay.queue_free()
	)
	v.add_child(btn)
	add_child(overlay)

func _maybe_show_last_crash_hint() -> void:
	if not FileAccess.file_exists("user://crash.log"):
		return
	var f := FileAccess.open("user://crash.log", FileAccess.READ)
	if f == null:
		return
	var first_line: String = f.get_line()
	f.close()
	# Show a hint at the bottom of the menu (non-blocking).
	var l := Label.new()
	l.text = "Last run crashed — see user://crash.log\n%s" % first_line.substr(0, 80)
	l.modulate = Color(0.95, 0.5, 0.5, 1.0)
	$Panel/VBox.add_child(l)
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
