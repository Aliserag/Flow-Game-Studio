extends GutTest


func test_generate_exposes_archetype_names_not_stats() -> void:
	var comp := ItemRegistry.get_composition("farm-raid-medium")
	var biome := ItemRegistry.get_biome("farm-village")
	var rep := ScoutReport.generate(comp, biome, ItemRegistry)
	assert_true(rep.has("members"))
	for m in rep["members"]:
		assert_true(m.has("name"), "Each member exposes name")
		assert_true(m.has("tier"), "Each member exposes tier")
		assert_false(m.has("stats"), "Stats NOT exposed (Pillar 4)")
		assert_false(m.has("max_hp"), "max_hp NOT exposed")
		assert_false(m.has("attack"), "attack NOT exposed")


func test_generate_includes_biome_modifier() -> void:
	var comp := ItemRegistry.get_composition("farm-raid-easy")
	var biome := ItemRegistry.get_biome("farm-village")
	var rep := ScoutReport.generate(comp, biome, ItemRegistry)
	assert_true(rep.has("modifier"))
	assert_true(rep["modifier"].has("name"))
	assert_true(rep["modifier"].has("description"))


func test_boss_flag_propagates() -> void:
	var comp := ItemRegistry.get_composition("iron-warden-boss")
	var biome := ItemRegistry.get_biome("farm-village")
	var rep := ScoutReport.generate(comp, biome, ItemRegistry)
	assert_true(rep.get("is_boss_fight", false), "Boss comp flagged as boss fight")
