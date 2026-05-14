extends GutTest


func test_same_seed_produces_same_int_sequence() -> void:
	Rng.set_seed(42)
	var a := [Rng.roll_int(1, 100), Rng.roll_int(1, 100), Rng.roll_int(1, 100)]
	Rng.set_seed(42)
	var b := [Rng.roll_int(1, 100), Rng.roll_int(1, 100), Rng.roll_int(1, 100)]
	assert_eq(a, b, "Same seed -> same int sequence")


func test_same_seed_produces_same_float_sequence() -> void:
	Rng.set_seed(7)
	var a := [Rng.roll_float(), Rng.roll_float(), Rng.roll_float()]
	Rng.set_seed(7)
	var b := [Rng.roll_float(), Rng.roll_float(), Rng.roll_float()]
	assert_eq(a, b, "Same seed -> same float sequence")


func test_pick_returns_array_member() -> void:
	Rng.set_seed(1)
	var arr := ["a", "b", "c"]
	for i in 20:
		var v: String = Rng.pick(arr)
		assert_true(v in arr, "pick returns member")


func test_pick_weighted_respects_weights() -> void:
	Rng.set_seed(123)
	var counts := {"a": 0, "b": 0}
	for i in 4000:
		var v: String = Rng.pick_weighted(["a", "b"], [1, 3])
		counts[v] += 1
	# Expect ~25% a, ~75% b. Tolerance 5%.
	var ratio_b := float(counts["b"]) / 4000.0
	assert_almost_eq(ratio_b, 0.75, 0.05, "B should be ~75%")


func test_shuffle_deterministic() -> void:
	Rng.set_seed(99)
	var arr1 := [1, 2, 3, 4, 5, 6, 7, 8]
	Rng.shuffle(arr1)
	Rng.set_seed(99)
	var arr2 := [1, 2, 3, 4, 5, 6, 7, 8]
	Rng.shuffle(arr2)
	assert_eq(arr1, arr2, "Same seed -> same shuffle")


func test_roll_chance_extremes() -> void:
	Rng.set_seed(1)
	for i in 50:
		assert_false(Rng.roll_chance(0.0), "0% chance never true")
	for i in 50:
		assert_true(Rng.roll_chance(1.0), "100% chance always true")
