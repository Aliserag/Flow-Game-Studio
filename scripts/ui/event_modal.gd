extends Control

# Modal for EU4-style events. Shown when EventBus emits request_event_modal.

signal choice_selected(choice_index: int)

@onready var title_label: Label = $Panel/Margin/V/Title
@onready var body_label: RichTextLabel = $Panel/Margin/V/Body
@onready var options_box: VBoxContainer = $Panel/Margin/V/Options
@onready var outcome_label: Label = $Panel/Margin/V/Outcome
@onready var continue_btn: Button = $Panel/Margin/V/ContinueBtn

var _payload: Dictionary = {}
var _resolved: bool = false

func _ready() -> void:
	visible = false
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false

func show_event(payload: Dictionary) -> void:
	_payload = payload
	_resolved = false
	title_label.text = String(payload.get("title", "?"))
	body_label.text = String(payload.get("description", ""))
	outcome_label.text = ""
	continue_btn.visible = false
	for c in options_box.get_children():
		c.queue_free()
	var options: Array = payload.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = String(opt.get("text", "..."))
		if opt.has("cost"):
			var cost_str: Array = []
			for k in opt["cost"].keys():
				cost_str.append("%dx %s" % [int(opt["cost"][k]), k])
			btn.text += "   [" + ", ".join(cost_str) + "]"
		# Disable if can't afford.
		if opt.has("cost"):
			for k in opt["cost"].keys():
				if not GameState.has_item(String(k), int(opt["cost"][k])):
					btn.disabled = true
		var idx := i
		btn.pressed.connect(func(): _on_choice(idx))
		options_box.add_child(btn)
	visible = true

func _on_choice(idx: int) -> void:
	if _resolved: return
	_resolved = true
	var result: Dictionary = EventSystem.resolve_choice(_payload, idx, GameState.grid)
	outcome_label.text = String(result.get("text", ""))
	for c in options_box.get_children():
		if c is Button:
			c.disabled = true
	continue_btn.visible = true

func _on_continue() -> void:
	visible = false
	choice_selected.emit(-1)
	EventBus.modal_closed.emit()
