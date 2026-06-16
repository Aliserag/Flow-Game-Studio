extends Node
## Accessibility autoload. Owns colorblind mode, focus styling, and a11y settings.
## See docs/architecture/ADR-005-accessibility.md (TODO) for full design.

signal colorblind_mode_changed(mode: int)
signal high_contrast_changed(enabled: bool)

enum ColorblindMode { OFF, DEUTERANOPIA, PROTANOPIA, TRITANOPIA }

const SETTINGS_PATH := "user://accessibility_settings.json"

# Semantic colors per mode. Damage red and magic green are the main risks.
# Deuteranopia / Protanopia: red ↔ green confusion. Use yellow/blue pair.
# Tritanopia: blue ↔ yellow confusion. Use red/purple pair (rare in WARBAND).
const _COLOR_TABLE := {
	ColorblindMode.OFF: {
		"damage": Color(0.87, 0.25, 0.25, 1.0),   # high-contrast Fell Red
		"magic":  Color(0.18, 0.80, 0.44, 1.0),   # Hex Viridian
		"warning": Color(0.79, 0.66, 0.30, 1.0),  # Warband Gold
	},
	ColorblindMode.DEUTERANOPIA: {
		"damage": Color(0.95, 0.80, 0.10, 1.0),   # safety yellow
		"magic":  Color(0.20, 0.45, 0.95, 1.0),   # safety blue
		"warning": Color(1.0, 0.55, 0.0, 1.0),    # orange
	},
	ColorblindMode.PROTANOPIA: {
		"damage": Color(0.95, 0.80, 0.10, 1.0),
		"magic":  Color(0.20, 0.45, 0.95, 1.0),
		"warning": Color(1.0, 0.55, 0.0, 1.0),
	},
	ColorblindMode.TRITANOPIA: {
		"damage": Color(0.95, 0.20, 0.40, 1.0),   # pink/red
		"magic":  Color(0.70, 0.20, 0.85, 1.0),   # purple
		"warning": Color(0.95, 0.30, 0.40, 1.0),
	},
}

var colorblind_mode: int = ColorblindMode.OFF:
	set(value):
		if value == colorblind_mode:
			return
		colorblind_mode = value
		_save_settings()
		emit_signal("colorblind_mode_changed", colorblind_mode)

var high_contrast: bool = false:
	set(value):
		if value == high_contrast:
			return
		high_contrast = value
		_save_settings()
		emit_signal("high_contrast_changed", high_contrast)


func _ready() -> void:
	_load_settings()


func get_damage_color() -> Color:
	return _COLOR_TABLE[colorblind_mode]["damage"]


func get_magic_color() -> Color:
	return _COLOR_TABLE[colorblind_mode]["magic"]


func get_warning_color() -> Color:
	return _COLOR_TABLE[colorblind_mode]["warning"]


## Returns a StyleBoxFlat suitable for theme_override_styles/focus on buttons.
func get_focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)  # transparent fill — focus is the border only
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = get_warning_color()  # Warband Gold normally
	return sb


## Applies a death/damage marker prefix to text. Useful where color alone may fail.
func damage_marker() -> String:
	return "[D] " if colorblind_mode != ColorblindMode.OFF else ""


func magic_marker() -> String:
	return "[M] " if colorblind_mode != ColorblindMode.OFF else ""


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	var d := {
		"colorblind_mode": colorblind_mode,
		"high_contrast": high_contrast,
	}
	f.store_string(JSON.stringify(d))


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		colorblind_mode = int(d.get("colorblind_mode", ColorblindMode.OFF))
		high_contrast = bool(d.get("high_contrast", false))
