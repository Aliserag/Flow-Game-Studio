extends GutTest


func test_generate_returns_non_empty_map() -> void:
	Rng.set_seed(1)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	assert_false(m.is_empty(), "Map non-empty")
	assert_true(m.has("nodes"))
	assert_true(m.has("rows"))


func test_map_has_correct_number_of_rows() -> void:
	Rng.set_seed(1)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var rows: Array = m["rows"]
	# 1 start row + (ROWS_PER_RUN - 1) middle rows + 1 boss row = ROWS_PER_RUN + 1
	assert_eq(rows.size(), CampaignMap.ROWS_PER_RUN + 1)


func test_first_row_is_single_battle_node() -> void:
	Rng.set_seed(1)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var first_row: Array = m["rows"][0]
	assert_eq(first_row.size(), 1, "Row 0 has 1 node")
	var node = m["nodes"][first_row[0]]
	assert_eq(node.node_type, CampaignMap.NodeType.BATTLE)


func test_final_row_is_single_boss_node() -> void:
	Rng.set_seed(1)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var rows: Array = m["rows"]
	var last_row: Array = rows[-1]
	assert_eq(last_row.size(), 1, "Last row has 1 node (boss)")
	var node = m["nodes"][last_row[0]]
	assert_eq(node.node_type, CampaignMap.NodeType.BOSS)


func test_all_non_terminal_nodes_have_children() -> void:
	Rng.set_seed(2)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var nodes: Dictionary = m["nodes"]
	var last_row_id: String = m["rows"][-1][0]
	for id: String in nodes:
		if id == last_row_id:
			continue
		var n = nodes[id]
		assert_gt(n.children.size(), 0, "Node %s has children" % id)


func test_all_children_are_in_next_row() -> void:
	Rng.set_seed(3)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var nodes: Dictionary = m["nodes"]
	for id: String in nodes:
		var n = nodes[id]
		for child_id in n.children:
			var child = nodes[child_id]
			assert_eq(child.row, n.row + 1, "Child %s is in row %d (parent %s in row %d)" % [child_id, child.row, id, n.row])


func test_enter_node_sets_current() -> void:
	Rng.set_seed(4)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var first_id: String = m["rows"][0][0]
	CampaignMap.enter_node(m, first_id)
	assert_eq(m["current_node_id"], first_id)


func test_available_nodes_from_start_returns_row_0() -> void:
	Rng.set_seed(5)
	var m := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	var avail: Array = CampaignMap.get_available_next_nodes(m)
	assert_eq(avail.size(), 1)


func test_deterministic_generation() -> void:
	Rng.set_seed(99)
	var a := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	Rng.set_seed(99)
	var b := CampaignMap.generate("farm-village", ItemRegistry, Rng)
	assert_eq((a["nodes"] as Dictionary).size(), (b["nodes"] as Dictionary).size())
	# Same row sizes
	for i in (a["rows"] as Array).size():
		assert_eq((a["rows"][i] as Array).size(), (b["rows"][i] as Array).size())
