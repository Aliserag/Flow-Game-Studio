extends Node

# Persistent settings stored in user://settings.cfg. Other systems read from
# this autoload; the Settings menu mutates it.

const CFG_PATH := "user://settings.cfg"

# --- Settings (with defaults) ---
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var muted: bool = false

var fullscreen: bool = false
var vsync: bool = true

var text_scale: float = 1.0
var reduce_motion: bool = false
var colorblind_mode: bool = false

var default_difficulty: int = GameState.Difficulty.STANDARD
var autosave_on_end_day: bool = true
var tutorial_shown: bool = false

signal settings_changed()

func _ready() -> void:
	load_from_disk()
	apply_to_runtime()

func load_from_disk() -> void:
	if not FileAccess.file_exists(CFG_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err != OK:
		push_warning("SettingsService: failed to load %s (err=%d)" % [CFG_PATH, err])
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	muted = bool(cfg.get_value("audio", "muted", muted))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	text_scale = float(cfg.get_value("accessibility", "text_scale", text_scale))
	reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", reduce_motion))
	colorblind_mode = bool(cfg.get_value("accessibility", "colorblind_mode", colorblind_mode))
	default_difficulty = int(cfg.get_value("gameplay", "default_difficulty", default_difficulty))
	autosave_on_end_day = bool(cfg.get_value("gameplay", "autosave_on_end_day", autosave_on_end_day))
	tutorial_shown = bool(cfg.get_value("gameplay", "tutorial_shown", tutorial_shown))

func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("accessibility", "text_scale", text_scale)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("accessibility", "colorblind_mode", colorblind_mode)
	cfg.set_value("gameplay", "default_difficulty", default_difficulty)
	cfg.set_value("gameplay", "autosave_on_end_day", autosave_on_end_day)
	cfg.set_value("gameplay", "tutorial_shown", tutorial_shown)
	cfg.save(CFG_PATH)
	settings_changed.emit()

func apply_to_runtime() -> void:
	# Audio.
	if AudioDirector != null:
		AudioDirector.set_master_volume(master_volume if not muted else 0.0)
		AudioDirector.set_music_volume(music_volume)
		AudioDirector.set_sfx_volume(sfx_volume)
		AudioDirector.mute_sfx(muted)
		AudioDirector.mute_music(muted)
	# Display.
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	# Vsync.
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	settings_changed.emit()
