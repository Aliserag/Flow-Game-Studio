extends Control

@onready var master_slider: HSlider = $Panel/Margin/V/AudioBox/MasterSlider
@onready var music_slider: HSlider = $Panel/Margin/V/AudioBox/MusicSlider
@onready var sfx_slider: HSlider = $Panel/Margin/V/AudioBox/SfxSlider
@onready var mute_toggle: CheckBox = $Panel/Margin/V/AudioBox/MuteToggle
@onready var fullscreen_toggle: CheckBox = $Panel/Margin/V/DisplayBox/FullscreenToggle
@onready var vsync_toggle: CheckBox = $Panel/Margin/V/DisplayBox/VsyncToggle
@onready var text_scale_slider: HSlider = $Panel/Margin/V/AccessBox/TextScaleSlider
@onready var reduce_motion_toggle: CheckBox = $Panel/Margin/V/AccessBox/ReduceMotionToggle
@onready var colorblind_toggle: CheckBox = $Panel/Margin/V/AccessBox/ColorblindToggle
@onready var difficulty_btn: OptionButton = $Panel/Margin/V/GameplayBox/DifficultyButton
@onready var autosave_toggle: CheckBox = $Panel/Margin/V/GameplayBox/AutosaveToggle
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_on_close)
	master_slider.value_changed.connect(func(v): SettingsService.master_volume = v)
	music_slider.value_changed.connect(func(v): SettingsService.music_volume = v)
	sfx_slider.value_changed.connect(func(v): SettingsService.sfx_volume = v)
	mute_toggle.toggled.connect(func(v): SettingsService.muted = v)
	fullscreen_toggle.toggled.connect(func(v): SettingsService.fullscreen = v)
	vsync_toggle.toggled.connect(func(v): SettingsService.vsync = v)
	text_scale_slider.value_changed.connect(func(v): SettingsService.text_scale = v)
	reduce_motion_toggle.toggled.connect(func(v): SettingsService.reduce_motion = v)
	colorblind_toggle.toggled.connect(func(v): SettingsService.colorblind_mode = v)
	autosave_toggle.toggled.connect(func(v): SettingsService.autosave_on_end_day = v)
	# Populate difficulty options.
	difficulty_btn.clear()
	difficulty_btn.add_item("Tourist", GameState.Difficulty.TOURIST)
	difficulty_btn.add_item("Standard", GameState.Difficulty.STANDARD)
	difficulty_btn.add_item("Apocalypse", GameState.Difficulty.APOCALYPSE)
	difficulty_btn.add_item("Permadeath", GameState.Difficulty.PERMADEATH)
	difficulty_btn.item_selected.connect(func(idx): SettingsService.default_difficulty = difficulty_btn.get_item_id(idx))

func show_panel() -> void:
	_load_into_ui()
	visible = true

func _load_into_ui() -> void:
	master_slider.value = SettingsService.master_volume
	music_slider.value = SettingsService.music_volume
	sfx_slider.value = SettingsService.sfx_volume
	mute_toggle.button_pressed = SettingsService.muted
	fullscreen_toggle.button_pressed = SettingsService.fullscreen
	vsync_toggle.button_pressed = SettingsService.vsync
	text_scale_slider.value = SettingsService.text_scale
	reduce_motion_toggle.button_pressed = SettingsService.reduce_motion
	colorblind_toggle.button_pressed = SettingsService.colorblind_mode
	autosave_toggle.button_pressed = SettingsService.autosave_on_end_day
	for i in difficulty_btn.item_count:
		if difficulty_btn.get_item_id(i) == SettingsService.default_difficulty:
			difficulty_btn.select(i)
			break

func _on_close() -> void:
	SettingsService.apply_to_runtime()
	SettingsService.save_to_disk()
	visible = false
