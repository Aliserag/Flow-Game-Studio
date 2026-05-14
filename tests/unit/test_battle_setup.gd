extends GutTest


func test_pick_composition_returns_dict() -> void:
	Rng.set_seed(1)
	var c := BattleSetup.pick_composition(ItemRegistry, Rng, 0)
	assert_false(c.is_empty(), "Should return a composition")
	assert_true(c.has("members"))


func test_compute_rewards_non_negative_gold() -> void:
	Rng.set_seed(1)
	var c := BattleSetup.pick_composition(ItemRegistry, Rng, 0)
	var r := BattleSetup.compute_rewards(c, ItemRegistry, Rng)
	assert_gte(int(r["gold"]), 0)


func test_compute_rewards_has_drops_array() -> void:
	Rng.set_seed(1)
	var c := BattleSetup.pick_composition(ItemRegistry, Rng, 0)
	var r := BattleSetup.compute_rewards(c, ItemRegistry, Rng)
	assert_true(r.has("drops"))
	assert_true(r["drops"] is Array)
