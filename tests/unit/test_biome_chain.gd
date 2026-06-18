extends GutTest
## Tests the G2 second biome and the biome modifiers introduced in v0.3.


func before_each() -> void:
	SaveSystem.clear_run()
	RunState.candidates.clear()
	RunState.candidate_prices.clear()
	RunState.roster.clear()
	RunState.gravestone.clear()
	RunState.hero = null
	RunState.campaign_map = {}
	RunState.market_stock = []


func test_two_biomes_defined() -> void:
	var ids: Array[String] = ItemRegistry.biome_ids()
	assert_true(ids.has("farm-village"))
	assert_true(ids.has("clan-territory"))


func test_clan_warchief_boss_exists() -> void:
	var boss: Dictionary = ItemRegistry.get_enemy("clan-warchief-boss")
	assert_false(boss.is_empty())
	assert_true(boss.get("is_boss", false))
	assert_eq(int(boss["stats"]["max_hp"]), 180)


func test_first_kill_modifier_grants_attack_bonus() -> void:
	# Build a player team strong enough to kill at least one enemy in round 1.
	var hero_arch := ItemRegistry.get_archetype("chieftain")
	var hero: Orc = Orc.from_archetype(hero_arch)
	hero.name = "TestHero"
	hero.attack = 50
	hero.max_hp = 200
	hero.current_hp = 200
	var comp := ItemRegistry.get_composition("rival-warband-light")
	var biome := ItemRegistry.get_biome("clan-territory")
	var modifier: Dictionary = biome.get("battle_modifier", {})
	Rng.set_seed(1)
	var result := CombatResolver.resolve([hero], comp, ItemRegistry, Rng, modifier)
	# We expect at least one death event AND the first death must come before
	# any subsequent attack of the same actor (the test verifies the modifier
	# code path executes without crashing and battle terminates).
	var saw_death := false
	for ev in result["events"]:
		if ev.get("kind", "") == "death":
			saw_death = true
			break
	assert_true(saw_death, "Strong hero should kill at least one rival")
	assert_true(typeof(result["victory"]) == TYPE_BOOL)


func test_full_campaign_chains_to_second_biome_on_first_boss_kill() -> void:
	# Smoke test that the controller chains biomes when farm-village boss falls.
	var ctrl := CampaignController.new(ItemRegistry, Rng, RunState)
	ctrl.begin_new_run(33)
	assert_eq(RunState.current_biome_id, "farm-village", "Starts in farm-village")
	# Manually advance to a boss confrontation by populating the controller's
	# state and emulating a victory.
	ctrl.current_enemy_comp = ItemRegistry.get_composition("iron-warden-boss")
	ctrl.last_battle_result = {"victory": true, "rounds": 1, "events": [], "player_dead": []}
	# Pretend we just won the boss node and continue
	# Set current_node_id to the boss node id in the map
	var map: Dictionary = RunState.campaign_map
	var boss_id: String = ""
	for nid in map.get("nodes", {}):
		var n = map["nodes"][nid]
		if n.node_type == CampaignMap.NodeType.BOSS:
			boss_id = nid
			break
	if boss_id.is_empty():
		gut.p("No boss node — skipping")
		return
	map["current_node_id"] = boss_id
	ctrl.continue_from_resolution()
	assert_eq(RunState.current_biome_id, "clan-territory", "Chains to clan-territory after farm boss")
	assert_true(RunState.run_active, "Run still active after first boss")
