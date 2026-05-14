extends GutTest


func _make_orc(arch_id: String, name: String = "TestOrc") -> Orc:
	var arch: Dictionary = ItemRegistry.get_archetype(arch_id)
	var o: Orc = Orc.from_archetype(arch)
	o.name = name
	return o


func _trivial_composition() -> Dictionary:
	return {
		"id": "trivial",
		"name": "Trivial Test",
		"tier": 1,
		"members": [{"enemy_id": "bandit-thug", "count": 1}],
	}


func _easy_composition() -> Dictionary:
	return {
		"id": "easy",
		"name": "Easy Test",
		"tier": 1,
		"members": [{"enemy_id": "bandit-thug", "count": 2}],
	}


func test_same_seed_same_result() -> void:
	var orc_a := _make_orc("brute", "A")
	Rng.set_seed(555)
	var result_a := CombatResolver.resolve([orc_a], _easy_composition(), ItemRegistry, Rng)
	var orc_b := _make_orc("brute", "A")
	Rng.set_seed(555)
	var result_b := CombatResolver.resolve([orc_b], _easy_composition(), ItemRegistry, Rng)
	assert_eq(result_a["victory"], result_b["victory"])
	assert_eq(result_a["rounds"], result_b["rounds"])
	assert_eq(result_a["events"].size(), result_b["events"].size())


func test_battle_has_start_and_end_events() -> void:
	Rng.set_seed(1)
	var result := CombatResolver.resolve([_make_orc("brute")], _trivial_composition(), ItemRegistry, Rng)
	var events: Array = result["events"]
	assert_eq(events[0]["kind"], CombatResolver.EV_BATTLE_START)
	assert_eq(events[-1]["kind"], CombatResolver.EV_BATTLE_END)


func test_battle_contains_attacks() -> void:
	Rng.set_seed(1)
	var result := CombatResolver.resolve([_make_orc("brute")], _trivial_composition(), ItemRegistry, Rng)
	var attack_count := 0
	for ev in result["events"]:
		if ev["kind"] == CombatResolver.EV_ATTACK:
			attack_count += 1
	assert_gt(attack_count, 0, "Should have at least one attack")


func test_brute_beats_single_thug() -> void:
	# Brute has 60hp, 5 attack, 6 defense vs Thug 25hp 5 attack 2 defense.
	# Brute should win consistently across many seeds.
	for seed_val in [1, 2, 3, 4, 5]:
		Rng.set_seed(seed_val)
		var result := CombatResolver.resolve([_make_orc("brute")], _trivial_composition(), ItemRegistry, Rng)
		assert_true(result["victory"], "Brute should beat single thug (seed=%d)" % seed_val)


func test_lone_archer_can_lose_to_pack() -> void:
	# Archer is squishy. Against multiple enemies, sometimes loses.
	# Just check the simulation terminates with a known boolean.
	Rng.set_seed(7)
	var hard_comp := {
		"id": "hard",
		"name": "Hard",
		"tier": 2,
		"members": [
			{"enemy_id": "bandit-thug", "count": 2},
			{"enemy_id": "bandit-captain", "count": 1},
		],
	}
	var result := CombatResolver.resolve([_make_orc("archer")], hard_comp, ItemRegistry, Rng)
	assert_true(typeof(result["victory"]) == TYPE_BOOL, "Has victory boolean")
	assert_lt(result["rounds"], CombatResolver.MAX_ROUNDS, "Battle terminates")
