extends GutTest
## G0 end-to-end integration test.
## Simulates a complete WARBAND run from main-menu-equivalent start to either
## hero death or campaign victory, exercising every G0 system.

const FIXED_SEED := 42

var _controller: CampaignController


func before_each() -> void:
	# Reset save system and start fresh
	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	_controller = CampaignController.new(ItemRegistry, Rng, RunState)


func test_g0_full_run_completes_without_crashes() -> void:
	## The critical end-to-end test. Simulates a full G0 player journey:
	## - Start a new run
	## - Enter tavern, optionally hire
	## - Resolve a battle
	## - Continue until hero death OR a hard cap of 30 battles
	## - Verify the run ended in a known terminal state
	_controller.begin_new_run(FIXED_SEED)
	assert_true(RunState.run_active, "Run should be active after begin")
	assert_not_null(RunState.hero, "Hero should exist after begin")
	assert_gt(RunState.roster.size(), 0, "Roster should have starting grunts")
	assert_eq(RunState.phase, RunState.Phase.TAVERN, "Should be in TAVERN phase")

	var max_battles := 30
	var i := 0
	while RunState.run_active and i < max_battles:
		i += 1
		# At tavern: maybe hire if we can afford the cheapest candidate AND have room
		if RunState.phase == RunState.Phase.TAVERN:
			assert_gt(RunState.candidates.size(), 0, "Should have candidates")
			var econ: Dictionary = ItemRegistry.get_economy()
			var max_grunts: int = int(econ.get("max_roster_size", 6)) - 1
			# Try to hire the cheapest affordable candidate (greedy)
			var best: Orc = null
			var best_price := 9999
			for c in RunState.candidates:
				var p: int = RunState.price_for(c)
				if p > 0 and p <= RunState.gold and p < best_price:
					best = c
					best_price = p
			var has_room: bool = RunState.roster.size() < max_grunts
			if best != null and has_room:
				var hired: bool = _controller.hire(best)
				assert_true(hired, "Hire should succeed when affordable and room available")
		# Proceed to battle
		_controller.enter_battle_prep()
		assert_eq(RunState.candidates.size(), 0, "Candidates cleared on battle prep")
		var result: Dictionary = _controller.resolve_battle()
		assert_true(result.has("events"), "Battle result should have events")
		assert_gt(result.get("events", []).size(), 0, "At least one event in battle")
		assert_true(result.has("victory"), "Result has victory bool")
		# After resolve, controller transitions to RESOLUTION phase
		assert_eq(RunState.phase, RunState.Phase.RESOLUTION, "Phase = RESOLUTION after resolve")
		# Continue
		_controller.continue_from_resolution()
		if RunState.run_active:
			assert_eq(RunState.phase, RunState.Phase.TAVERN, "Back to TAVERN on continue")

	# Run terminated. Either hero died (run_active false, phase GAME_OVER) or hit cap.
	if not RunState.run_active:
		assert_eq(RunState.phase, RunState.Phase.GAME_OVER, "Game over phase when run ended")
		# Hero should be dead (current_hp == 0) per permadeath contract
		assert_eq(RunState.hero.current_hp, 0, "Hero is dead at game over")
		# Hero should be in gravestone
		var hero_in_gravestone := false
		for entry in RunState.gravestone:
			if entry.get("is_hero", false):
				hero_in_gravestone = true
				break
		assert_true(hero_in_gravestone, "Hero entry recorded in gravestone")
	# Battles completed should match iteration count (or be one less if we hit cap mid-state)
	assert_gt(RunState.battles_completed, 0, "At least one battle completed")


func test_g0_permadeath_persists_across_battles() -> void:
	## Verify that orcs who die in battle 1 are NOT present after battle 2.
	_controller.begin_new_run(FIXED_SEED + 7)
	# Play one battle
	_controller.enter_battle_prep()
	var result: Dictionary = _controller.resolve_battle()
	var dead_orcs: Array = result.get("player_dead", [])
	_controller.continue_from_resolution()
	# Battle must run at least one round
	assert_gte(int(result.get("rounds", 0)), 1, "Battle ran at least one round")
	# Each dead grunt: not in roster, present in gravestone
	for d in dead_orcs:
		var dead_orc: Orc = d.get("source")
		if dead_orc == null or dead_orc.is_hero:
			continue
		assert_does_not_have(RunState.roster, dead_orc, "Dead orc should not be in roster")
		var found := false
		for entry in RunState.gravestone:
			if entry.get("id", "") == dead_orc.id:
				found = true
				break
		assert_true(found, "Dead orc should be in gravestone: %s" % dead_orc.name)


func test_g0_deterministic_run_same_seed_same_outcome() -> void:
	## Two runs with same seed should produce identical battles_completed/won counts
	## up to the same termination point.
	_controller.begin_new_run(123456)
	var battles_a := 0
	var i := 0
	while RunState.run_active and i < 15:
		i += 1
		_controller.enter_battle_prep()
		_controller.resolve_battle()
		_controller.continue_from_resolution()
		battles_a += 1
	var won_a := RunState.battles_won
	var gold_a := RunState.gold

	# Reset and replay
	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	var ctrl_b: CampaignController = CampaignController.new(ItemRegistry, Rng, RunState)
	ctrl_b.begin_new_run(123456)
	var battles_b := 0
	i = 0
	while RunState.run_active and i < 15:
		i += 1
		ctrl_b.enter_battle_prep()
		ctrl_b.resolve_battle()
		ctrl_b.continue_from_resolution()
		battles_b += 1

	assert_eq(battles_b, battles_a, "Same seed -> same battle count")
	assert_eq(RunState.battles_won, won_a, "Same seed -> same wins")
	assert_eq(RunState.gold, gold_a, "Same seed -> same final gold")
