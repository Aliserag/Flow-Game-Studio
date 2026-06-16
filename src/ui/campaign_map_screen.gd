class_name CampaignMapScreen
extends Control
## Renders the campaign map node graph. Shows current position, available next nodes,
## and lets the player click a node to enter it.

@onready var _gold_label: Label = $HUDBar/GoldLabel
@onready var _biome_label: Label = $HUDBar/BiomeLabel
@onready var _battles_label: Label = $HUDBar/BattlesLabel
@onready var _nodes_container: Control = $MapArea/NodesContainer
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	AudioBus.play_music("map")
	RunState.gold_changed.connect(_on_gold_changed)
	RunState.map_changed.connect(_refresh_map)
	RunState.phase_changed.connect(_on_phase_changed)
	_back_button.pressed.connect(_on_memorial_pressed)
	_refresh_hud()
	_refresh_map()


func _on_gold_changed(_g: int) -> void:
	_refresh_hud()


func _on_phase_changed(_p: int) -> void:
	# If we move off the MAP phase, route the user
	if RunState.phase == RunState.Phase.SCOUT:
		get_tree().change_scene_to_file("res://src/ui/ScoutScreen.tscn")
	elif RunState.phase == RunState.Phase.MARKET:
		get_tree().change_scene_to_file("res://src/ui/MarketScreen.tscn")
	elif RunState.phase == RunState.Phase.VICTORY:
		get_tree().change_scene_to_file("res://src/ui/VictoryScreen.tscn")
	elif RunState.phase == RunState.Phase.GAME_OVER:
		get_tree().change_scene_to_file("res://src/ui/GameOverScreen.tscn")


func _refresh_hud() -> void:
	_gold_label.text = "Gold: %d" % RunState.gold
	_battles_label.text = "Battles: %d" % RunState.battles_completed
	var biome: Dictionary = ItemRegistry.get_biome(RunState.current_biome_id)
	_biome_label.text = String(biome.get("name", "Unknown Biome"))


func _refresh_map() -> void:
	# Clear existing node buttons
	for child in _nodes_container.get_children():
		child.queue_free()
	var map: Dictionary = RunState.campaign_map
	if map.is_empty():
		return
	var rows: Array = map.get("rows", [])
	var nodes: Dictionary = map.get("nodes", {})
	var current_id: String = String(map.get("current_node_id", ""))
	var available_ids: Array[String] = []
	for n in CampaignHolder.controller.get_available_map_nodes():
		available_ids.append(n.id)
	var area_size: Vector2 = _nodes_container.size
	if area_size.x < 100:
		area_size = Vector2(440, 180)
	var row_count: int = rows.size()
	for r in row_count:
		var row: Array = rows[r]
		var row_y: float = (float(r) / max(1, row_count - 1)) * (area_size.y - 32) + 8
		for c in row.size():
			var node = nodes[row[c]]
			var col_x: float = (float(c + 1) / float(row.size() + 1)) * area_size.x
			var btn := Button.new()
			btn.text = _label_for(node)
			btn.size = Vector2(56, 22)
			btn.position = Vector2(col_x - 28, row_y)
			btn.disabled = not (node.id in available_ids)
			if node.id == current_id:
				btn.modulate = Color(1.0, 0.85, 0.3)  # warband gold
			elif node.visited:
				btn.modulate = Color(0.4, 0.4, 0.4)
			btn.pressed.connect(_on_node_pressed.bind(node.id))
			_nodes_container.add_child(btn)


func _label_for(node) -> String:
	match node.node_type:
		CampaignMap.NodeType.BATTLE: return "Battle"
		CampaignMap.NodeType.MARKET: return "Market"
		CampaignMap.NodeType.REST: return "Rest"
		CampaignMap.NodeType.EVENT: return "Event"
		CampaignMap.NodeType.BOSS: return "BOSS"
		_: return "?"


func _on_node_pressed(node_id: String) -> void:
	CampaignHolder.controller.enter_map_node(node_id)


func _on_memorial_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/MemorialScreen.tscn")
