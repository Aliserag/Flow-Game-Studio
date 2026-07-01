class_name MapGenerator
extends RefCounted

# Procedural map generator. Uses weighted noise + cluster seeding so settlements
# group into clusters rather than scatter uniformly.

static func generate(size: Vector2i) -> Grid:
	var g := Grid.new(size)

	# Pass 1: fill with weighted random terrain.
	var weighted_terrain: Array = []
	var weights: Array = []
	for id in DataLoader.terrain.keys():
		weighted_terrain.append(id)
		weights.append(int(DataLoader.terrain[id].get("spawn_weight", 1)))
	for x in size.x:
		for y in size.y:
			var pick = RNG.weighted_pick(weighted_terrain, weights)
			var t := Tile.new(Vector2i(x, y), pick)
			g.set_tile(Vector2i(x, y), t)

	# Pass 2: cluster buildings — seed 2-3 town centres and bias surrounding tiles
	# toward urban terrain so towns feel like towns.
	var town_count: int = RNG.randi_range_inclusive(2, 3)
	for _i in town_count:
		var centre := g.random_in_bounds()
		_seed_town(g, centre)

	# Pass 3: carve a road or two so movement has some structure.
	_carve_road(g, Vector2i(0, RNG.randi_range_inclusive(2, size.y - 3)),
		Vector2i(size.x - 1, RNG.randi_range_inclusive(2, size.y - 3)))

	# Pass 4: roll supplies per tile from terrain config.
	for x in size.x:
		for y in size.y:
			var t: Tile = g.get_tile(Vector2i(x, y))
			var d := t.data()
			t.supplies = RNG.randi_range_inclusive(int(d.get("supply_min", 0)), int(d.get("supply_max", 0)))

	return g

static func _seed_town(g: Grid, centre: Vector2i) -> void:
	var building_pool := ["house", "house", "house", "ruins", "supermarket", "gas_station"]
	if RNG.chance(0.4):
		building_pool.append("hospital")
	if RNG.chance(0.2):
		building_pool.append("military")
	if RNG.chance(0.3):
		building_pool.append("church")

	var radius := RNG.randi_range_inclusive(1, 3)
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var p := Vector2i(centre.x + dx, centre.y + dy)
			if not g.in_bounds(p):
				continue
			var dist: int = max(abs(dx), abs(dy))
			# Closer = more likely building.
			var p_building: float = 0.85 - 0.25 * dist
			if RNG.chance(p_building):
				var pick: String = String(RNG.pick(building_pool))
				g.set_tile(p, Tile.new(p, pick))

static func _carve_road(g: Grid, a: Vector2i, b: Vector2i) -> void:
	# Lazy line: walk from a to b, alternate axis, lay road tiles.
	var cur := a
	var safety := g.size.x * g.size.y
	while cur != b and safety > 0:
		safety -= 1
		var t := Tile.new(cur, "road")
		# preserve supplies on roads (small)
		g.set_tile(cur, t)
		var dx: int = sign(b.x - cur.x)
		var dy: int = sign(b.y - cur.y)
		if dx != 0 and (dy == 0 or RNG.chance(0.6)):
			cur.x += dx
		elif dy != 0:
			cur.y += dy
		else:
			break
