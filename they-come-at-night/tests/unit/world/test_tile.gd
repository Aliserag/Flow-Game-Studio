class_name TileTest
extends RefCounted

static func run_all() -> void:
	TestFramework.suite("Tile")
	_test_terrain_config_loads()
	_test_add_remove_entity()
	_test_has_hostile()
	_test_is_building()
	_test_first_entity_glyph_priority()

static func _test_terrain_config_loads() -> void:
	var t: Tile = Tile.new(Vector2i(0, 0), "house")
	var d: Dictionary = t.data()
	TestFramework.assert_dict_has(d, "name", "house tile reads name")
	TestFramework.assert_eq("House", t.display_name(), "house display_name correct")
	TestFramework.assert_true(t.is_building(), "house is_building")
	TestFramework.assert_true(t.defense_bonus() > 0, "house has defense_bonus > 0")

static func _test_add_remove_entity() -> void:
	var t: Tile = Tile.new(Vector2i(0, 0), "plains")
	var z: ZombieUnit = TestHelpers.make_zombie()
	t.add_entity(z)
	TestFramework.assert_eq(1, t.entities.size(), "tile entity added")
	t.add_entity(z)  # no-op, already present
	TestFramework.assert_eq(1, t.entities.size(), "tile add is idempotent")
	t.remove_entity(z)
	TestFramework.assert_eq(0, t.entities.size(), "tile entity removed")

static func _test_has_hostile() -> void:
	var t: Tile = Tile.new(Vector2i(0, 0), "plains")
	var lead: Survivor = TestHelpers.make_lead_at()
	t.add_entity(lead)
	TestFramework.assert_false(t.has_hostile(), "survivor not hostile")
	var z: ZombieUnit = TestHelpers.make_zombie()
	t.add_entity(z)
	TestFramework.assert_true(t.has_hostile(), "zombie present → hostile")

static func _test_is_building() -> void:
	TestFramework.assert_false(Tile.new(Vector2i(0,0), "plains").is_building(), "plains not building")
	TestFramework.assert_true(Tile.new(Vector2i(0,0), "house").is_building(), "house is building")
	TestFramework.assert_true(Tile.new(Vector2i(0,0), "supermarket").is_building(), "supermarket is building")
	TestFramework.assert_false(Tile.new(Vector2i(0,0), "forest").is_building(), "forest not building")

static func _test_first_entity_glyph_priority() -> void:
	var t: Tile = Tile.new(Vector2i(0, 0), "plains")
	var z: ZombieUnit = TestHelpers.make_zombie()
	t.add_entity(z)
	TestFramework.assert_eq("z", t.first_entity_glyph(), "zombie glyph shown alone")
	var lead: Survivor = TestHelpers.make_lead_at()
	t.add_entity(lead)
	# Lead has display_priority 100, beats zombie 31.
	TestFramework.assert_eq("@", t.first_entity_glyph(), "lead glyph wins by priority")
