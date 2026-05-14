extends GutTest


func test_roll_candidates_returns_count() -> void:
	Rng.set_seed(1)
	var c := TavernRecruit.roll_candidates(ItemRegistry, Rng, 3)
	assert_eq(c.size(), 3)


func test_candidates_have_orc_and_price() -> void:
	Rng.set_seed(2)
	var c := TavernRecruit.roll_candidates(ItemRegistry, Rng, 3)
	for entry: Dictionary in c:
		assert_true(entry.has("orc"))
		assert_true(entry.has("price"))
		assert_gt(int(entry["price"]), 0, "Price > 0")
		assert_true(entry["orc"] is Orc, "Orc instance")


func test_candidate_price_in_tier_range() -> void:
	Rng.set_seed(3)
	var econ: Dictionary = ItemRegistry.get_economy()
	var rng_range: Array = econ["hire_price_range_per_tier"]["1"]
	var c := TavernRecruit.roll_candidates(ItemRegistry, Rng, 5, 1)
	for entry: Dictionary in c:
		var p: int = int(entry["price"])
		assert_gte(p, int(rng_range[0]), "Price >= range low")
		assert_lte(p, int(rng_range[1]), "Price <= range high")


func test_deterministic_candidates_same_seed() -> void:
	Rng.set_seed(77)
	var a := TavernRecruit.roll_candidates(ItemRegistry, Rng, 3)
	Rng.set_seed(77)
	var b := TavernRecruit.roll_candidates(ItemRegistry, Rng, 3)
	for i in 3:
		assert_eq(
			(a[i]["orc"] as Orc).archetype_id,
			(b[i]["orc"] as Orc).archetype_id,
			"Same archetype at position %d" % i
		)
		assert_eq(int(a[i]["price"]), int(b[i]["price"]), "Same price at position %d" % i)
