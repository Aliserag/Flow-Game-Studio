class_name CombatResolverTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("CombatResolver")
	_test_party_attack_no_items()
	_test_party_attack_with_weapon()
	_test_party_attack_with_armory()
	_test_party_defense_no_armor()
	_test_party_defense_with_armor_and_walls()
	_test_resolve_kills_weak_zombie()
	_test_megahorde_kill_triggers_victory()
	_test_lead_promoted_when_lead_dies()

static func _test_party_attack_no_items() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	var attack: int = CombatResolver.party_attack_power()
	TestFramework.assert_eq(lead.attack, attack, "attack equals lead.attack with no items")

static func _test_party_attack_with_weapon() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = ["machete"]   # attack 5
	var attack: int = CombatResolver.party_attack_power()
	TestFramework.assert_eq(lead.attack + 5, attack, "machete adds +5 attack")

static func _test_party_attack_with_armory() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = ["knife"]  # attack 2
	GameState.base_enhancements.append("armory")
	var attack: int = CombatResolver.party_attack_power()
	# best weapon (2) + armory bonus (2)
	TestFramework.assert_eq(lead.attack + 2 + 2, attack, "armory bonus applied")

static func _test_party_defense_no_armor() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	TestFramework.assert_eq(0, CombatResolver.party_defense(), "no defense without armor or base")

static func _test_party_defense_with_armor_and_walls() -> void:
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = ["vest"]  # defense 3
	GameState.has_base = true
	GameState.base_defense_bonus = 2
	GameState.base_enhancements.append("barricade")  # defense 2
	TestFramework.assert_eq(3 + 2 + 2, CombatResolver.party_defense(), "armor + base + barricade stack")

static func _test_resolve_kills_weak_zombie() -> void:
	TestHelpers.seed_rng()
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	lead.attack = 20  # overpowered
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	grid.add_entity(lead)
	var z: ZombieUnit = TestHelpers.make_zombie("single", lead.pos)
	grid.add_entity(z)
	var result: Dictionary = CombatResolver.resolve_attack(z, grid)
	TestFramework.assert_true(bool(result.zombie_killed), "weak zombie killed by overpowered lead")

static func _test_megahorde_kill_triggers_victory() -> void:
	TestHelpers.seed_rng()
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	lead.attack = 9999  # one-shot
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	grid.add_entity(lead)
	var mh: ZombieUnit = TestHelpers.make_zombie("megahorde", lead.pos)
	grid.add_entity(mh)
	CombatResolver.resolve_attack(mh, grid)
	TestFramework.assert_eq(GameState.Phase.GAME_OVER, GameState.phase, "megahorde death triggers GAME_OVER phase")

static func _test_lead_promoted_when_lead_dies() -> void:
	TestHelpers.seed_rng()
	TestHelpers.reset_game_state()
	var lead: Survivor = TestHelpers.make_lead_at()
	lead.hp = 1
	var second: Survivor = TestHelpers.make_recruit()
	second.is_lead = false
	GameState.party.append(lead)
	GameState.party.append(second)
	GameState.assignments[lead.id] = []
	GameState.assignments[second.id] = []
	var grid: Grid = TestHelpers.make_grid()
	GameState.grid = grid
	grid.add_entity(lead)
	grid.add_entity(second)
	# Force-remove the lead via the helper (simulates combat death).
	CombatResolver._remove_party_member(lead, grid)
	TestFramework.assert_eq(1, GameState.party.size(), "second survivor remains")
	TestFramework.assert_true(GameState.party[0].is_lead, "second survivor promoted to lead")
