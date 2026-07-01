class_name SwarmSystemTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("SwarmSystem")
	_test_no_warning_before_unlock_day()
	_test_megahorde_unlocks_in_range()
	_test_megahorde_eta_in_range()
	_test_countdown_decrements()
	_test_megahorde_spawns_at_eta_zero()

static func _test_no_warning_before_unlock_day() -> void:
	TestHelpers.seed_rng(99)
	TestHelpers.reset_game_state()
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	# Day 5 is below SWARM_UNLOCK_DAY (8).
	GameState.day = 5
	for _i in 5:
		SwarmSystem.on_day_advanced(GameState.day, grid)
	TestFramework.assert_true(GameState.swarm_pending.is_empty(), "no swarm scheduled before day 8")

static func _test_megahorde_unlocks_in_range() -> void:
	TestHelpers.seed_rng(7)
	TestHelpers.reset_game_state()
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	# Spin days forward until unlock fires.
	var safety: int = 0
	while not GameState.megahorde_unlocked and safety < 100:
		GameState.day += 1
		SwarmSystem.on_day_advanced(GameState.day, grid)
		safety += 1
	TestFramework.assert_true(GameState.megahorde_unlocked, "megahorde unlocks within 100 days")
	TestFramework.assert_in_range(20.0, 50.0, float(GameState._megahorde_unlock_day),
		"unlock day in [20, 50]")

static func _test_megahorde_eta_in_range() -> void:
	TestHelpers.seed_rng(7)
	TestHelpers.reset_game_state()
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	var safety: int = 0
	while not GameState.megahorde_unlocked and safety < 100:
		GameState.day += 1
		SwarmSystem.on_day_advanced(GameState.day, grid)
		safety += 1
	TestFramework.assert_in_range(5.0, 8.0, float(GameState.megahorde_eta),
		"megahorde eta in [5, 8] at unlock")

static func _test_countdown_decrements() -> void:
	TestHelpers.seed_rng(7)
	TestHelpers.reset_game_state()
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	# Hand-set unlock state so we don't depend on RNG for this assertion.
	GameState.megahorde_unlocked = true
	GameState.megahorde_eta = 5
	GameState.day = 21
	SwarmSystem.on_day_advanced(22, grid)
	TestFramework.assert_eq(4, GameState.megahorde_eta, "eta decrements once per call")

static func _test_megahorde_spawns_at_eta_zero() -> void:
	TestHelpers.seed_rng(7)
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	grid.add_entity(lead)
	GameState.megahorde_unlocked = true
	GameState.megahorde_eta = 1
	SwarmSystem.on_day_advanced(GameState.day + 1, grid)
	# Megahorde spawned somewhere on the grid.
	var found_megahorde: bool = false
	for e in grid.entities:
		if e is ZombieUnit and e.unit_id == "megahorde":
			found_megahorde = true
			break
	TestFramework.assert_true(found_megahorde, "megahorde unit spawned on grid")
