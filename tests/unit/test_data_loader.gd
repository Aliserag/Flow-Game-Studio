class_name DataLoaderTest
extends RefCounted

# Verifies all data JSONs load with non-empty contents and required keys.

static func run_all() -> void:
	TestFramework.suite("DataLoader")

	TestFramework.assert_true(DataLoader.terrain.size() >= 10, "terrain has at least 10 entries")
	TestFramework.assert_true(DataLoader.items.size() >= 20, "items has at least 20 entries")
	TestFramework.assert_true(DataLoader.factions.size() >= 7, "factions has at least 7 entries")
	TestFramework.assert_true(DataLoader.zombie_units.size() >= 5, "zombie_units has at least 5 entries")
	TestFramework.assert_true(DataLoader.enhancements.size() >= 10, "enhancements has at least 10 entries")
	TestFramework.assert_true(DataLoader.events.size() >= 17, "events has at least 17 entries")

	# Required keys per terrain.
	for tid in DataLoader.terrain.keys():
		var t: Dictionary = DataLoader.terrain[tid]
		TestFramework.assert_dict_has(t, "name", "terrain[%s] has name" % tid)
		TestFramework.assert_dict_has(t, "defense_bonus", "terrain[%s] has defense_bonus" % tid)
		TestFramework.assert_dict_has(t, "escape_bonus", "terrain[%s] has escape_bonus" % tid)

	# Required keys per zombie unit.
	for zid in DataLoader.zombie_units.keys():
		var z: Dictionary = DataLoader.zombie_units[zid]
		TestFramework.assert_dict_has(z, "size_min", "zombie_unit[%s] has size_min" % zid)
		TestFramework.assert_dict_has(z, "attack", "zombie_unit[%s] has attack" % zid)
		TestFramework.assert_dict_has(z, "hp", "zombie_unit[%s] has hp" % zid)

	# Megahorde must exist for win condition.
	TestFramework.assert_dict_has(DataLoader.zombie_units, "megahorde", "megahorde defined")

	# Required keys per faction.
	for fid in DataLoader.factions.keys():
		var f: Dictionary = DataLoader.factions[fid]
		TestFramework.assert_dict_has(f, "betrayal_chance", "faction[%s] has betrayal_chance" % fid)
		TestFramework.assert_dict_has(f, "intro_lines", "faction[%s] has intro_lines" % fid)

	# Cannibals exist (referenced by knowledge_warning event).
	TestFramework.assert_dict_has(DataLoader.factions, "cannibals", "cannibals faction defined")

	# Every event has at least one option.
	for eid in DataLoader.events.keys():
		var ev: Dictionary = DataLoader.events[eid]
		var opts: Array = ev.get("options", [])
		TestFramework.assert_true(opts.size() > 0, "event[%s] has at least 1 option" % eid)
		for i in opts.size():
			var opt: Dictionary = opts[i]
			var outcomes: Array = opt.get("outcomes", [])
			TestFramework.assert_true(outcomes.size() > 0, "event[%s].options[%d] has outcomes" % [eid, i])
