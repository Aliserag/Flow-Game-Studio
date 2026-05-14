extends GutTest


func before_each() -> void:
	SaveSystem.clear_run()


func test_save_and_load_round_trip() -> void:
	var snapshot := {"gold": 100, "battles": 3}
	SaveSystem.save_run(snapshot)
	var loaded := SaveSystem.load_run()
	assert_eq(loaded["gold"], 100)
	assert_eq(loaded["battles"], 3)


func test_has_save_after_save() -> void:
	assert_false(SaveSystem.has_save())
	SaveSystem.save_run({"x": 1})
	assert_true(SaveSystem.has_save())


func test_clear_run_empties() -> void:
	SaveSystem.save_run({"x": 1})
	SaveSystem.clear_run()
	assert_false(SaveSystem.has_save())


func test_record_hero_death_increments() -> void:
	var meta_before: Dictionary = SaveSystem.get_meta_progression()
	var before: int = int(meta_before.get("hero_deaths", 0))
	SaveSystem.record_hero_death({"name": "Test Hero", "battles_fought": 5, "kills": 3, "killer_name": "dragon"})
	var meta_after: Dictionary = SaveSystem.get_meta_progression()
	assert_eq(int(meta_after["hero_deaths"]), before + 1)
	# Hero added to legends since battles_fought >= 1
	assert_gt((meta_after["legends"] as Array).size(), 0)
