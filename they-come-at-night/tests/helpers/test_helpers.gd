class_name TestHelpers
extends RefCounted

# Common factories and seed utilities for tests.

static func seed_rng(s: int = 12345) -> void:
	RNG.seed_run(s)

static func reset_game_state() -> void:
	GameState.reset_run(GameState.Mode.SOLO, 12345)

static func make_lead_at(pos: Vector2i = Vector2i(7, 7)) -> Survivor:
	var s: Survivor = Survivor.make_lead()
	s.pos = pos
	return s

static func make_recruit(faction_id: String = "lone_wolf") -> Survivor:
	seed_rng(12345)  # determinism
	var s: Survivor = Survivor.make_random_recruit()
	s.faction_id = faction_id
	s.betrayal_chance = float(DataLoader.factions.get(faction_id, {}).get("betrayal_chance", 0.0))
	return s

static func make_zombie(unit_id: String = "single", at: Vector2i = Vector2i(0, 0)) -> ZombieUnit:
	var z: ZombieUnit = ZombieUnit.make(unit_id)
	z.pos = at
	return z

static func make_grid(size: Vector2i = Vector2i(10, 10), terrain: String = "plains") -> Grid:
	# Deterministic uniform grid (no map generator, so layout is predictable).
	var g: Grid = Grid.new(size)
	for x in size.x:
		for y in size.y:
			g.set_tile(Vector2i(x, y), Tile.new(Vector2i(x, y), terrain))
	return g

static func setup_party_with_lead() -> Survivor:
	reset_game_state()
	var lead: Survivor = make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	return lead
