extends Control

@onready var list: VBoxContainer = $Panel/Margin/V/Scroll/List
@onready var close_btn: Button = $Panel/Margin/V/CloseBtn

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false)

func show_panel() -> void:
	visible = true
	_populate()

func _populate() -> void:
	for c in list.get_children():
		c.queue_free()
	if GameState.knowledge.is_empty():
		var empty := Label.new()
		empty.text = "You haven't learned anything yet.\n\nKnowledge accumulates from events, encounters,\nand close calls. It changes how the world looks."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(empty)
		return
	for k in GameState.knowledge:
		var k_data: Dictionary = DataLoader.knowledge.get(String(k), {})
		var row := PanelContainer.new()
		var v := VBoxContainer.new()
		row.add_child(v)
		var title := Label.new()
		title.text = String(k_data.get("title", k))
		title.theme_type_variation = "HeaderSmall"
		v.add_child(title)
		var summary := Label.new()
		summary.text = String(k_data.get("summary", "(no detail)"))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(summary)
		list.add_child(row)
