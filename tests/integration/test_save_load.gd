class_name SaveLoadTest
extends RefCounted

# Round-trip save/load. Uses a small synthetic grid (no MapGenerator dependency
# for determinism). Verifies state, party, inventory, knowledge, grid, and
# entity references survive serialization.

static func run_all() -> void:
	TestFramework.suite("SaveLoad")
	_test_round_trip_basic()
	_test_round_trip_with_party_and_zombies()
	_test_load_with_no_save()

static func _test_round_trip_basic() -> void:
	# Setup
	TestHelpers.seed_rng(99)
	TestHelpers.reset_game_state()
	GameState.day = 7
	GameState.morale = 5
	GameState.add_to_inventory("knife", 2)
	GameState.add_to_inventory("bandage", 3)
	GameState.knowledge.append("cannibal_warning")
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(3, 3))
	GameState.party.append(lead)
	GameState.assignments[lead.id] = ["knife"]
	var grid: Grid = TestHelpers.make_grid(Vector2i(8, 8), "house")
	GameState.grid = grid
	grid.add_entity(lead)
	# Save.
	SaveSystem.save()
	TestFramework.assert_true(SaveSystem.has_save(), "save file exists after save()")
	# Mutate state.
	GameState.day = 999
	GameState.morale = 0
	# Load.
	var ok: bool = SaveSystem.load_run()
	TestFramework.assert_true(ok, "load returns true")
	TestFramework.assert_eq(7, GameState.day, "day restored")
	TestFramework.assert_eq(5, GameState.morale, "morale restored")
	TestFramework.assert_eq(2, int(GameState.inventory.get("knife", 0)), "knife count restored")
	TestFramework.assert_eq(3, int(GameState.inventory.get("bandage", 0)), "bandage count restored")
	TestFramework.assert_true(GameState.knowledge.has("cannibal_warning"), "knowledge restored")
	# Cleanup.
	SaveSystem.delete_save()

static func _test_round_trip_with_party_and_zombies() -> void:
	TestHelpers.seed_rng(99)
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at(Vector2i(2, 2))
	var recruit: Survivor = Survivor.new()
	recruit.display_name = "Recruit"
	recruit.faction_id = "doctors"
	recruit.faction_revealed = true
	recruit.pos = Vector2i(2, 3)
	GameState.party.append(lead)
	GameState.party.append(recruit)
	GameState.assignments[lead.id] = []
	GameState.assignments[recruit.id] = ["medkit"]
	var grid: Grid = TestHelpers.make_grid(Vector2i(8, 8))
	GameState.grid = grid
	grid.add_entity(lead)
	grid.add_entity(recruit)
	var z: ZombieUnit = TestHelpers.make_zombie("group", Vector2i(5, 5))
	grid.add_entity(z)
	SaveSystem.save()
	# Load.
	SaveSystem.load_run()
	TestFramework.assert_eq(2, GameState.party.size(), "party size 2 restored")
	TestFramework.assert_eq("Recruit", GameState.party[1].display_name, "recruit name restored")
	TestFramework.assert_eq("doctors", GameState.party[1].faction_id, "recruit faction restored")
	TestFramework.assert_true(GameState.party[1].faction_revealed, "faction_revealed restored")
	# Verify a zombie still on the grid.
	var z_count: int = 0
	for e in GameState.grid.entities:
		if e is ZombieUnit:
			z_count += 1
	TestFramework.assert_eq(1, z_count, "zombie restored to grid")
	# Verify assignment lookup by ID still works.
	var rec_assigned: Array = GameState.assignments.get(GameState.party[1].id, [])
	TestFramework.assert_array_size(rec_assigned, 1, "recruit assignment restored by ID")
	SaveSystem.delete_save()

static func _test_load_with_no_save() -> void:
	if SaveSystem.has_save():
		SaveSystem.delete_save()
	var ok: bool = SaveSystem.load_run()
	TestFramework.assert_false(ok, "load returns false when no save exists")
