extends GutTest
## G1 end-to-end integration test (covers G0 paths via the new map-driven loop).
## Simulates a complete WARBAND campaign:
##   Tavern -> Map -> [Battle | Market | Rest | Event] -> ... -> Boss -> Victory or Hero Death.

const FIXED_SEED := 42

var _controller: CampaignController


func before_each() -> void:
	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	RunState.campaign_map = {}
	RunState.market_stock = []
	_controller = CampaignController.new(ItemRegistry, Rng, RunState)


func _drive_until_terminal(controller: CampaignController, max_iters: int = 100) -> void:
	## Drives the controller through the full G1 flow until VICTORY or hero death.
	## Pure greedy: at tavern, hire the cheapest affordable if room. At map, pick first node.
	## At market, buy nothing. At rest/event, auto-completes via enter_map_node().
	var iters := 0
	while RunState.run_active and iters < max_iters:
		iters += 1
		match RunState.phase:
			RunState.Phase.TAVERN:
				_hire_if_affordable(controller)
				controller.leave_tavern_for_map()
			RunState.Phase.MAP:
				var available: Array = controller.get_available_map_nodes()
				if available.is_empty():
					# Map exhausted without victory — shouldn't happen
					return
				controller.enter_map_node(available[0].id)
			RunState.Phase.SCOUT:
				controller.commit_to_battle()
				controller.resolve_battle()
			RunState.Phase.BATTLE_PREP:
				controller.resolve_battle()
			RunState.Phase.RESOLUTION:
				controller.continue_from_resolution()
			RunState.Phase.MARKET:
				controller.leave_market()
			RunState.Phase.VICTORY, RunState.Phase.GAME_OVER:
				return
			_:
				return


func _hire_if_affordable(controller: CampaignController) -> void:
	var econ: Dictionary = ItemRegistry.get_economy()
	var max_grunts: int = int(econ.get("max_roster_size", 6)) - 1
	if RunState.roster.size() >= max_grunts:
		return
	var best: Orc = null
	var best_price := 9999
	for c: Orc in RunState.candidates:
		var p: int = RunState.price_for(c)
		if p > 0 and p <= RunState.gold and p < best_price:
			best = c
			best_price = p
	if best != null:
		var hired: bool = controller.hire(best)
		assert_true(hired, "Hire should succeed when affordable and room available")


func test_g1_full_run_reaches_terminal_state() -> void:
	## Critical end-to-end test: campaign reaches Victory or Game Over.
	_controller.begin_new_run(FIXED_SEED)
	assert_true(RunState.run_active, "Run active after begin")
	assert_not_null(RunState.hero, "Hero spawned")
	assert_gt(RunState.roster.size(), 0, "Starting roster non-empty")
	assert_eq(RunState.phase, RunState.Phase.TAVERN, "Starts in TAVERN")
	assert_false(RunState.current_biome_id.is_empty(), "Biome assigned")

	_drive_until_terminal(_controller)

	assert_true(
		RunState.phase == RunState.Phase.VICTORY or RunState.phase == RunState.Phase.GAME_OVER,
		"Should reach VICTORY or GAME_OVER (got phase=%d)" % RunState.phase
	)
	assert_false(RunState.run_active, "Run not active after terminal")
	assert_gt(RunState.battles_completed, 0, "At least one battle completed")


func test_g1_permadeath_persists_across_battles() -> void:
	## Dead orcs are removed from roster and recorded in gravestone permanently.
	_controller.begin_new_run(FIXED_SEED + 7)
	_controller.leave_tavern_for_map()
	# Enter first map node
	var first_nodes: Array = _controller.get_available_map_nodes()
	# Pick the first battle node we find
	var picked: bool = false
	for n in first_nodes:
		if n.node_type == CampaignMap.NodeType.BATTLE:
			_controller.enter_map_node(n.id)
			picked = true
			break
	if not picked:
		# All initial-row nodes might be non-battle; just pick first
		_controller.enter_map_node(first_nodes[0].id)
	# If we landed on SCOUT, commit to battle
	if RunState.phase == RunState.Phase.SCOUT:
		_controller.commit_to_battle()
	var result: Dictionary = _controller.resolve_battle()
	var dead_orcs: Array = result.get("player_dead", [])
	_controller.continue_from_resolution()
	assert_gte(int(result.get("rounds", 0)), 1, "Battle ran at least one round")
	for d in dead_orcs:
		var dead_orc: Orc = d.get("source")
		if dead_orc == null or dead_orc.is_hero:
			continue
		assert_does_not_have(RunState.roster, dead_orc, "Dead orc off roster")
		var found := false
		for entry in RunState.gravestone:
			if entry.get("id", "") == dead_orc.id:
				found = true
				break
		assert_true(found, "Dead orc in gravestone: %s" % dead_orc.name)


func test_g1_deterministic_run_same_seed_same_outcome() -> void:
	## Two runs with same seed produce identical terminal state.
	_controller.begin_new_run(123456)
	_drive_until_terminal(_controller, 30)
	var battles_a := RunState.battles_completed
	var won_a := RunState.battles_won
	var gold_a := RunState.gold
	var phase_a := RunState.phase

	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	RunState.campaign_map = {}
	RunState.market_stock = []
	var ctrl_b: CampaignController = CampaignController.new(ItemRegistry, Rng, RunState)
	ctrl_b.begin_new_run(123456)
	_drive_until_terminal(ctrl_b, 30)

	assert_eq(RunState.battles_completed, battles_a, "Same battle count")
	assert_eq(RunState.battles_won, won_a, "Same wins")
	assert_eq(RunState.gold, gold_a, "Same final gold")
	assert_eq(RunState.phase, phase_a, "Same terminal phase")


func test_g1_boss_phase_change_event_emitted_in_boss_fight() -> void:
	## Verify the boss phase-change mechanic works by constructing a direct
	## CombatResolver call against the boss composition with a strong player.
	var hero_arch := ItemRegistry.get_archetype("chieftain")
	var hero: Orc = Orc.from_archetype(hero_arch)
	hero.name = "Test Hero"
	# Make the hero overpowered so we can chew through boss HP fast
	hero.attack = 30
	hero.defense = 10
	hero.max_hp = 200
	hero.current_hp = 200
	var brute_arch := ItemRegistry.get_archetype("brute")
	var brute: Orc = Orc.from_archetype(brute_arch)
	brute.attack = 25
	brute.max_hp = 150
	brute.current_hp = 150
	var boss_comp := ItemRegistry.get_composition("iron-warden-boss")
	Rng.set_seed(1)
	var result := CombatResolver.resolve([hero, brute], boss_comp, ItemRegistry, Rng, {})
	var saw_phase_change := false
	for ev in result["events"]:
		if ev.get("kind", "") == CombatResolver.EV_PHASE_CHANGE:
			saw_phase_change = true
			break
	assert_true(saw_phase_change, "Boss should trigger phase change when HP drops below threshold")
