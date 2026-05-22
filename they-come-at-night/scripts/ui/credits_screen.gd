extends Control

# Credits + attribution. Auto-discovers license files under
# res://assets/*/licenses/ so adding a new asset pack updates this screen
# without code changes.

@onready var text_label: RichTextLabel = $Panel/Margin/V/Scroll/Text
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

const LICENSE_GLOB_DIRS := ["res://assets/audio/licenses/"]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func() -> void: visible = false)

func show_panel() -> void:
	_populate()
	visible = true

func _populate() -> void:
	var lines: Array = []
	lines.append("[b]They Come At Night[/b]")
	lines.append("%s" % BuildInfo.build_id)
	lines.append("")
	lines.append("[b]Engine[/b]")
	lines.append("Godot Engine — godotengine.org — MIT License")
	lines.append("")
	lines.append("[b]Audio[/b]")
	var any_audio: bool = false
	for dir_path in LICENSE_GLOB_DIRS:
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		while true:
			var fname: String = d.get_next()
			if fname == "":
				break
			if d.current_is_dir():
				continue
			if not fname.ends_with(".txt"):
				continue
			any_audio = true
			lines.append("")
			lines.append("[i]%s[/i]" % fname.replace(".txt", "").replace("_", " "))
			var f := FileAccess.open(dir_path + fname, FileAccess.READ)
			if f != null:
				var content: String = f.get_as_text().strip_edges()
				f.close()
				lines.append("[color=gray]%s[/color]" % content)
		d.list_dir_end()
	if not any_audio:
		lines.append("[color=gray](no third-party audio attributions present)[/color]")
	lines.append("")
	lines.append("[b]Art[/b]")
	lines.append("Procedural sprites generated at runtime by SpriteGenerator.")
	lines.append("Hand-authored sprites may replace them; see assets/sprites/licenses/ if present.")
	lines.append("")
	lines.append("[b]Project[/b]")
	lines.append("Source available on the project repository.")
	lines.append("Licensed under the project's chosen license; see LICENSE in the source tree.")
	lines.append("")
	lines.append("[b]Controls[/b]")
	if ResourceLoader.exists("res://CONTROLS.txt"):
		var f := FileAccess.open("res://CONTROLS.txt", FileAccess.READ)
		if f != null:
			lines.append("[color=gray]%s[/color]" % f.get_as_text().strip_edges())
			f.close()
	text_label.text = "\n".join(lines)
