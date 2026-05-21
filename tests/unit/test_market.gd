extends GutTest


func before_each() -> void:
	SaveSystem.clear_run()
	RunState.gold = 200
	RunState.hero = null
	RunState.roster.clear()


func test_roll_stock_returns_entries() -> void:
	Rng.set_seed(1)
	var stock := Market.roll_stock(ItemRegistry, Rng, 2)
	assert_eq(stock.size(), Market.STOCK_SIZE)
	for entry in stock:
		assert_true(entry.has("gear_id"))
		assert_true(entry.has("price"))
		assert_gt(int(entry["price"]), 0)


func test_buy_deducts_gold_and_equips_gear() -> void:
	Rng.set_seed(2)
	var arch := ItemRegistry.get_archetype("brute")
	var orc: Orc = Orc.from_archetype(arch)
	var stock := Market.roll_stock(ItemRegistry, Rng, 1)
	# Pick a weapon entry
	var weapon_entry: Dictionary = {}
	for entry: Dictionary in stock:
		if entry.get("slot", "") == "weapon":
			weapon_entry = entry
			break
	if weapon_entry.is_empty():
		# Fallback: any entry
		weapon_entry = stock[0]
	var gold_before := RunState.gold
	var price := int(weapon_entry["price"])
	var ok := Market.buy(ItemRegistry, RunState, weapon_entry, orc)
	assert_true(ok)
	assert_eq(RunState.gold, gold_before - price, "Gold deducted by price")
	assert_true(orc.equipped_gear.has(weapon_entry["slot"]))


func test_buy_fails_when_insufficient_gold() -> void:
	RunState.gold = 1
	var arch := ItemRegistry.get_archetype("brute")
	var orc: Orc = Orc.from_archetype(arch)
	var stock := Market.roll_stock(ItemRegistry, Rng, 1)
	var ok := Market.buy(ItemRegistry, RunState, stock[0], orc)
	assert_false(ok)
	assert_eq(RunState.gold, 1)


func test_sell_returns_half_price_and_unequips() -> void:
	var arch := ItemRegistry.get_archetype("brute")
	var orc: Orc = Orc.from_archetype(arch)
	orc.equipped_gear["weapon"] = "iron-sword-common"  # price 20
	var gold_before := RunState.gold
	var gained := Market.sell(RunState, ItemRegistry, orc, "weapon")
	assert_eq(gained, 10, "Half of 20")
	assert_false(orc.equipped_gear.has("weapon"))
	assert_eq(RunState.gold, gold_before + 10)


func test_sell_empty_slot_returns_zero() -> void:
	var arch := ItemRegistry.get_archetype("brute")
	var orc: Orc = Orc.from_archetype(arch)
	orc.equipped_gear.clear()
	var gained := Market.sell(RunState, ItemRegistry, orc, "weapon")
	assert_eq(gained, 0)
