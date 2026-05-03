class_name Grid
extends RefCounted

# 2D array of Tile objects. Owns spatial queries.

var size: Vector2i
var tiles: Array = []        # Array[Array[Tile]]
var entities: Array = []     # all live entities (player, zombies, npcs)

func _init(s: Vector2i) -> void:
	size = s
	tiles.resize(s.x)
	for x in s.x:
		var col: Array = []
		col.resize(s.y)
		tiles[x] = col

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y

func get_tile(p: Vector2i) -> Tile:
	if not in_bounds(p):
		return null
	return tiles[p.x][p.y]

func set_tile(p: Vector2i, t: Tile) -> void:
	tiles[p.x][p.y] = t

func neighbors4(p: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var np: Vector2i = p + d
		if in_bounds(np):
			out.append(np)
	return out

func neighbors8(p: Vector2i) -> Array:
	var out: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var np := Vector2i(p.x + dx, p.y + dy)
			if in_bounds(np):
				out.append(np)
	return out

func add_entity(e) -> void:
	entities.append(e)
	var t := get_tile(e.pos)
	if t != null:
		t.add_entity(e)
	EventBus.emit_signal("entity_added", e)

func remove_entity(e) -> void:
	entities.erase(e)
	var t := get_tile(e.pos)
	if t != null:
		t.remove_entity(e)
	EventBus.emit_signal("entity_removed", e)

func move_entity(e, new_pos: Vector2i) -> void:
	if not in_bounds(new_pos):
		return
	var old := e.pos
	var old_tile := get_tile(old)
	var new_tile := get_tile(new_pos)
	if old_tile != null:
		old_tile.remove_entity(e)
	e.pos = new_pos
	if new_tile != null:
		new_tile.add_entity(e)
	EventBus.emit_signal("entity_moved", e, old, new_pos)

func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func entities_in_radius(center: Vector2i, radius: int, filter_fn: Callable = Callable()) -> Array:
	var out: Array = []
	for e in entities:
		if chebyshev(center, e.pos) <= radius:
			if filter_fn.is_valid():
				if filter_fn.call(e):
					out.append(e)
			else:
				out.append(e)
	return out

func nearest_entity(center: Vector2i, filter_fn: Callable = Callable()):
	var best = null
	var best_dist := INF
	for e in entities:
		if e.pos == center:
			continue
		if filter_fn.is_valid() and not filter_fn.call(e):
			continue
		var d := chebyshev(center, e.pos)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func recompute_visibility(center: Vector2i, vision_radius: int) -> void:
	for x in size.x:
		for y in size.y:
			var t: Tile = tiles[x][y]
			if t == null:
				continue
			t.visible = chebyshev(Vector2i(x, y), center) <= vision_radius
			if t.visible:
				t.explored = true

func step_toward(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	# Greedy single-step toward target.
	var dx: int = sign(to_pos.x - from_pos.x)
	var dy: int = sign(to_pos.y - from_pos.y)
	# Prefer larger axis component.
	if abs(to_pos.x - from_pos.x) >= abs(to_pos.y - from_pos.y):
		return from_pos + Vector2i(dx, 0)
	return from_pos + Vector2i(0, dy)

func random_in_bounds() -> Vector2i:
	return Vector2i(RNG.randi_range_inclusive(0, size.x - 1), RNG.randi_range_inclusive(0, size.y - 1))

func random_edge_position() -> Vector2i:
	# Random tile on the outer ring — used to spawn things from off-map.
	var side: int = RNG.randi_range_inclusive(0, 3)
	match side:
		0: return Vector2i(RNG.randi_range_inclusive(0, size.x - 1), 0)
		1: return Vector2i(RNG.randi_range_inclusive(0, size.x - 1), size.y - 1)
		2: return Vector2i(0, RNG.randi_range_inclusive(0, size.y - 1))
		_: return Vector2i(size.x - 1, RNG.randi_range_inclusive(0, size.y - 1))
