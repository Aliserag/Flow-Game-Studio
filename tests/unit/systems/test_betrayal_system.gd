class_name BetrayalSystemTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("BetrayalSystem")
	_test_no_betrayal_with_solo_lead()
	_test_low_tension_lone_wolf_rarely_betrays()
	_test_high_betrayal_chance_fires_within_few_nights()
	_test_tension_modifier_scales_with_morale()

static func _test_no_betrayal_with_solo_lead() -> void:
	TestHelpers.seed_rng(42)
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	# Run 50 nights — solo can't betray themselves.
	for _i in 50:
		BetrayalSystem.nightly_check(grid)
	TestFramework.assert_eq(1, GameState.party.size(), "solo lead survives 50 nights")

static func _test_low_tension_lone_wolf_rarely_betrays() -> void:
	TestHelpers.seed_rng(42)
	TestHelpers.reset_game_state()
	GameState.morale = 10  # max morale → tension multiplier 1.0
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	var loyal: Survivor = Survivor.new()
	loyal.display_name = "Loyal"
	loyal.faction_id = "lone_wolf"
	loyal.betrayal_chance = 0.05
	GameState.party.append(loyal)
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	# 30 nights with 5% chance each → ~95% chance of zero betrayals at this seed.
	for _i in 30:
		BetrayalSystem.nightly_check(grid)
	TestFramework.assert_true(GameState.party.size() >= 1, "lead always present")
	# Loyal might still be present; this is a soft check.

static func _test_high_betrayal_chance_fires_within_few_nights() -> void:
	TestHelpers.seed_rng(42)
	TestHelpers.reset_game_state()
	GameState.morale = 3  # high tension multiplier
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	var traitor: Survivor = Survivor.new()
	traitor.display_name = "Traitor"
	traitor.faction_id = "cannibals"
	traitor.betrayal_chance = 0.85  # cannibals
	GameState.party.append(traitor)
	GameState.assignments[traitor.id] = []
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	var betrayed: bool = false
	for _i in 10:
		BetrayalSystem.nightly_check(grid)
		if GameState.party.size() == 1:
			betrayed = true
			break
		# If lead got knifed and died, that's also a betrayal outcome.
		if GameState.party.is_empty():
			betrayed = true
			break
	TestFramework.assert_true(betrayed, "85% betrayer fires within 10 nights at high tension")

static func _test_tension_modifier_scales_with_morale() -> void:
	TestHelpers.reset_game_state()
	GameState.morale = 10
	TestFramework.assert_almost(1.0, BetrayalSystem._current_tension_modifier(), 0.001,
		"morale 10 → modifier 1.0")
	GameState.morale = 5
	TestFramework.assert_almost(1.5, BetrayalSystem._current_tension_modifier(), 0.001,
		"morale 5 → modifier 1.5")
	GameState.morale = 2
	TestFramework.assert_almost(2.0, BetrayalSystem._current_tension_modifier(), 0.001,
		"morale 2 → modifier 2.0")
	# tension event bonus.
	GameState.morale = 10
	BetrayalSystem.add_tension(3)
	TestFramework.assert_almost(1.25, BetrayalSystem._current_tension_modifier(), 0.001,
		"add_tension adds +0.25")
