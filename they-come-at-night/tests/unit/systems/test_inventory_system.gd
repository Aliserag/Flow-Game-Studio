class_name InventorySystemTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("InventorySystem")
	_test_assign_deducts_from_stash()
	_test_unassign_returns_to_stash()
	_test_use_consumable_heals()
	_test_scavenge_marks_searched()
	_test_scavenge_already_searched()

static func _test_assign_deducts_from_stash() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.add_to_inventory("knife", 1)
	var ok: bool = InventorySystem.assign(lead.id, "knife")
	TestFramework.assert_true(ok, "assign returns true when item present")
	TestFramework.assert_eq(0, int(GameState.inventory.get("knife", 0)), "stash decremented")
	TestFramework.assert_eq(1, GameState.assignments[lead.id].size(), "item appears in assignments")

static func _test_unassign_returns_to_stash() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = ["knife"]
	var ok: bool = InventorySystem.unassign(lead.id, "knife")
	TestFramework.assert_true(ok, "unassign returns true")
	TestFramework.assert_eq(1, int(GameState.inventory.get("knife", 0)), "stash incremented")
	TestFramework.assert_eq(0, GameState.assignments[lead.id].size(), "item removed from assignments")

static func _test_use_consumable_heals() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	lead.hp = 5
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.add_to_inventory("bandage", 1)
	var r: Dictionary = InventorySystem.use_consumable(lead.id, "bandage")
	TestFramework.assert_true(bool(r.ok), "use_consumable returns ok")
	TestFramework.assert_eq(8, lead.hp, "bandage heals 3 (5 → 8)")
	TestFramework.assert_eq(0, int(GameState.inventory.get("bandage", 0)), "bandage consumed")

static func _test_scavenge_marks_searched() -> void:
	TestHelpers.seed_rng()
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(2, 2))
	GameState.party.append(lead)
	var grid: Grid = TestHelpers.make_grid(Vector2i(5, 5), "supermarket")
	GameState.grid = grid
	grid.add_entity(lead)
	var t: Tile = grid.get_tile(lead.pos)
	t.supplies = 3
	var r: Dictionary = InventorySystem.scavenge_tile(grid)
	TestFramework.assert_true(bool(r.ok), "scavenge ok on first call")
	TestFramework.assert_true(t.searched, "tile marked searched")

static func _test_scavenge_already_searched() -> void:
	TestHelpers.seed_rng()
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(2, 2))
	GameState.party.append(lead)
	var grid: Grid = TestHelpers.make_grid(Vector2i(5, 5), "plains")
	GameState.grid = grid
	grid.add_entity(lead)
	grid.get_tile(lead.pos).searched = true
	var r: Dictionary = InventorySystem.scavenge_tile(grid)
	TestFramework.assert_false(bool(r.ok), "scavenge fails when already searched")
