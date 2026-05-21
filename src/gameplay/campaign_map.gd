class_name CampaignMap
extends RefCounted
## Generates and traverses a branching node graph for one biome run.
##
## Node graph shape: directed acyclic graph with N rows. Each row has 2-3 nodes.
## Edges go forward only (row K -> row K+1). Each non-final node has 1-2 children.
## The final node is always the boss (single node in the last row).
##
## Node types: BATTLE, MARKET, REST, EVENT, BOSS.

enum NodeType { BATTLE, MARKET, REST, EVENT, BOSS }

const ROWS_PER_RUN: int = 6  # 6 rows -> 6 battles before boss (boss is row 7)
const NODES_PER_MIDDLE_ROW_MIN: int = 2
const NODES_PER_MIDDLE_ROW_MAX: int = 3

# Type distribution weights for middle rows (NOT first row, NOT boss)
const TYPE_WEIGHTS := {
	NodeType.BATTLE: 65,
	NodeType.MARKET: 15,
	NodeType.REST: 12,
	NodeType.EVENT: 8,
}


class MapNode:
	extends RefCounted
	var id: String              # "r{row}n{idx}"
	var row: int
	var col: int                # index within row
	var node_type: int          # NodeType enum
	var composition_id: String  # for BATTLE/BOSS only
	var visited: bool = false
	var children: Array[String] = []  # ids of next-row nodes reachable from this one

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"row": row,
			"col": col,
			"node_type": node_type,
			"composition_id": composition_id,
			"visited": visited,
			"children": children,
		}


static func generate(biome_id: String, registry: Node, rng: Node) -> Dictionary:
	var biome: Dictionary = registry.get_biome(biome_id)
	if biome.is_empty():
		return {}
	var pool: Array[String] = registry.compositions_for_biome(biome_id)
	var boss_id: String = registry.boss_composition_for_biome(biome_id)
	var nodes: Dictionary = {}  # id -> MapNode
	var rows: Array = []  # Array of Array[String node ids] per row

	# Row 0: single start node (BATTLE)
	var start := _make_node(0, 0, NodeType.BATTLE, _pick_composition(pool, rng))
	nodes[start.id] = start
	rows.append([start.id])

	# Middle rows
	for r in range(1, ROWS_PER_RUN):
		var width: int = rng.roll_int(NODES_PER_MIDDLE_ROW_MIN, NODES_PER_MIDDLE_ROW_MAX)
		var this_row: Array[String] = []
		for c in width:
			var node_type: int = _pick_node_type(rng, r)
			var comp_id: String = ""
			if node_type == NodeType.BATTLE:
				comp_id = _pick_composition(pool, rng)
			var n := _make_node(r, c, node_type, comp_id)
			nodes[n.id] = n
			this_row.append(n.id)
		rows.append(this_row)

	# Final row: single BOSS node
	var boss := _make_node(ROWS_PER_RUN, 0, NodeType.BOSS, boss_id)
	nodes[boss.id] = boss
	rows.append([boss.id])

	# Wire edges: each parent in row K connects to 1-2 children in row K+1.
	# Guarantees every node in K+1 has at least one parent (reachability).
	for r in range(rows.size() - 1):
		var parents: Array = rows[r]
		var children_row: Array = rows[r + 1]
		# Each parent picks 1-2 children
		for parent_id: String in parents:
			var parent_col: int = nodes[parent_id].col
			var picks: int = 1
			if children_row.size() >= 2 and rng.roll_chance(0.55):
				picks = 2
			picks = min(picks, children_row.size())
			# Prefer children with closer column index
			var ordered: Array = children_row.duplicate()
			ordered.sort_custom(func(a, b):
				return abs(nodes[a].col - parent_col) < abs(nodes[b].col - parent_col)
			)
			for i in picks:
				var child_id: String = ordered[i]
				if not nodes[parent_id].children.has(child_id):
					nodes[parent_id].children.append(child_id)
		# Ensure every child has at least one parent — connect orphans to nearest parent
		var parent_targets: Dictionary = {}
		for parent_id: String in parents:
			for child_id in nodes[parent_id].children:
				parent_targets[child_id] = true
		for child_id: String in children_row:
			if not parent_targets.has(child_id):
				# Connect nearest parent
				var child_col: int = nodes[child_id].col
				var nearest: String = parents[0]
				var best_dist: int = 999
				for parent_id: String in parents:
					var d: int = abs(nodes[parent_id].col - child_col)
					if d < best_dist:
						best_dist = d
						nearest = parent_id
				nodes[nearest].children.append(child_id)

	return {
		"biome_id": biome_id,
		"nodes": nodes,
		"rows": rows,
		"current_node_id": "",  # set when player enters first node
		"completed_node_ids": [] as Array[String],
	}


static func get_available_next_nodes(map: Dictionary) -> Array:
	## Returns Array of MapNode that the player can move to next.
	## If current_node_id is empty, returns row-0 nodes.
	var nodes: Dictionary = map.get("nodes", {})
	var rows: Array = map.get("rows", [])
	var current_id: String = String(map.get("current_node_id", ""))
	if current_id.is_empty():
		var out: Array = []
		if not rows.is_empty():
			for id: String in rows[0]:
				out.append(nodes[id])
		return out
	var current: MapNode = nodes.get(current_id)
	if current == null:
		return []
	var out: Array = []
	for child_id in current.children:
		out.append(nodes[child_id])
	return out


static func enter_node(map: Dictionary, node_id: String) -> void:
	var nodes: Dictionary = map.get("nodes", {})
	if not nodes.has(node_id):
		return
	map["current_node_id"] = node_id


static func complete_current(map: Dictionary) -> void:
	var current: String = String(map.get("current_node_id", ""))
	if current.is_empty():
		return
	var nodes: Dictionary = map.get("nodes", {})
	if nodes.has(current):
		(nodes[current] as MapNode).visited = true
	var done: Array = map.get("completed_node_ids", [])
	if not done.has(current):
		done.append(current)
	map["completed_node_ids"] = done


static func is_boss_node(map: Dictionary, node_id: String) -> bool:
	var nodes: Dictionary = map.get("nodes", {})
	if not nodes.has(node_id):
		return false
	return (nodes[node_id] as MapNode).node_type == NodeType.BOSS


static func is_run_complete(map: Dictionary) -> bool:
	## Run is complete when the BOSS node has been visited.
	var nodes: Dictionary = map.get("nodes", {})
	for id in nodes:
		var n: MapNode = nodes[id]
		if n.node_type == NodeType.BOSS and n.visited:
			return true
	return false


static func node_type_name(t: int) -> String:
	match t:
		NodeType.BATTLE: return "Battle"
		NodeType.MARKET: return "Market"
		NodeType.REST: return "Rest"
		NodeType.EVENT: return "Event"
		NodeType.BOSS: return "Boss"
		_: return "?"


static func _make_node(row: int, col: int, type: int, comp_id: String) -> MapNode:
	var n := MapNode.new()
	n.id = "r%dn%d" % [row, col]
	n.row = row
	n.col = col
	n.node_type = type
	n.composition_id = comp_id
	return n


static func _pick_composition(pool: Array[String], rng: Node) -> String:
	if pool.is_empty():
		return ""
	return rng.pick(pool)


static func _pick_node_type(rng: Node, row_idx: int) -> int:
	# Force at least one MARKET appearance somewhere in middle rows by biasing
	# the rule: row 3 has elevated MARKET chance.
	var weights := TYPE_WEIGHTS.duplicate()
	if row_idx == 3:
		weights[NodeType.MARKET] = 35
		weights[NodeType.BATTLE] = 45
	var types: Array = []
	var ws: Array = []
	for t in weights:
		types.append(t)
		ws.append(weights[t])
	return int(rng.pick_weighted(types, ws))
