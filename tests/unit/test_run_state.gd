extends GutTest


func before_each() -> void:
	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	RunState.gold = 0
	RunState.battles_completed = 0
	RunState.battles_won = 0


func test_start_new_run_creates_hero_and_roster() -> void:
	RunState.start_new_run(11)
	assert_not_null(RunState.hero, "Hero should exist")
	assert_gt(RunState.roster.size(), 0, "Roster should be non-empty")
	assert_gt(RunState.gold, 0, "Should have starting gold")
	assert_eq(RunState.phase, RunState.Phase.TAVERN)
	assert_true(RunState.run_active)


func test_same_seed_same_starting_roster_archetypes() -> void:
	RunState.start_new_run(99)
	var arch_a: Array = RunState.roster.map(func(o): return o.archetype_id)
	# Reset
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	RunState.start_new_run(99)
	var arch_b: Array = RunState.roster.map(func(o): return o.archetype_id)
	assert_eq(arch_a, arch_b, "Same seed -> same starting roster archetypes")


func test_spend_gold_cannot_go_negative() -> void:
	RunState.gold = 10
	var ok := RunState.spend_gold(50)
	assert_false(ok, "Cannot overspend")
	assert_eq(RunState.gold, 10, "Gold unchanged on failed spend")


func test_can_afford_basic() -> void:
	RunState.gold = 50
	assert_true(RunState.can_afford(25))
	assert_true(RunState.can_afford(50))
	assert_false(RunState.can_afford(51))


func test_hire_candidate_fails_if_not_in_candidates() -> void:
	RunState.start_new_run(1)
	var arch: Dictionary = ItemRegistry.get_archetype("berserker")
	var fake_orc: Orc = Orc.from_archetype(arch)
	# Not in candidates
	assert_false(RunState.hire_candidate(fake_orc))


func test_hire_candidate_succeeds_when_in_candidates() -> void:
	RunState.start_new_run(1)
	var arch: Dictionary = ItemRegistry.get_archetype("berserker")
	var o: Orc = Orc.from_archetype(arch)
	RunState.set_candidates([o] as Array[Orc], [10] as Array[int])
	var ok := RunState.hire_candidate(o)
	assert_true(ok)
	assert_true(o in RunState.roster)
	assert_false(o in RunState.candidates)


func test_record_orc_death_grunt_removes_from_roster() -> void:
	RunState.start_new_run(1)
	var victim: Orc = RunState.roster[0]
	RunState.record_orc_death(victim, "test killer")
	assert_false(victim in RunState.roster, "Dead grunt off roster")
	assert_eq(RunState.gravestone.size(), 1)
	assert_true(RunState.run_active, "Run continues after grunt death")


func test_record_orc_death_of_hero_ends_run() -> void:
	RunState.start_new_run(1)
	var hero: Orc = RunState.hero
	RunState.record_orc_death(hero, "the dragon")
	assert_false(RunState.run_active)
	assert_eq(RunState.phase, RunState.Phase.GAME_OVER)
	assert_eq(RunState.gravestone.size(), 1)


func test_award_xp_distributes_to_living() -> void:
	RunState.start_new_run(1)
	# Kill one orc
	var dead: Orc = RunState.roster[0]
	RunState.record_orc_death(dead, "test")
	# Award XP to remaining
	RunState.award_xp_to_warband(50)
	for o in RunState.get_all_living_orcs():
		assert_gt(o.xp, 0, "%s should have XP" % o.name)


func test_full_heal_warband_restores_all() -> void:
	RunState.start_new_run(1)
	RunState.hero.apply_damage(10)
	for o in RunState.roster:
		o.apply_damage(5)
	RunState.full_heal_warband()
	assert_eq(RunState.hero.current_hp, RunState.hero.max_hp)
	for o in RunState.roster:
		assert_eq(o.current_hp, o.max_hp)
