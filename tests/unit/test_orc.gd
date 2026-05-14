extends GutTest


func _berserker_archetype() -> Dictionary:
	return {
		"id": "berserker",
		"name": "Berserker",
		"kind": "grunt",
		"base_stats": {"max_hp": 35, "attack": 9, "defense": 2, "speed": 6},
		"starting_traits": [],
		"default_gear": [],
	}


func test_from_archetype_copies_stats() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	assert_eq(o.max_hp, 35)
	assert_eq(o.current_hp, 35)
	assert_eq(o.attack, 9)
	assert_eq(o.defense, 2)
	assert_eq(o.speed, 6)
	assert_eq(o.archetype_id, "berserker")
	assert_false(o.is_hero)


func test_is_alive_after_damage() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	assert_true(o.is_alive())
	o.apply_damage(100)
	assert_false(o.is_alive())


func test_apply_damage_clamps_at_zero() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	var taken := o.apply_damage(50)
	assert_eq(taken, 35, "Damage clamps to current HP")
	assert_eq(o.current_hp, 0)


func test_heal_clamps_at_max() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	o.apply_damage(20)
	var healed := o.heal(50)
	assert_eq(healed, 20)
	assert_eq(o.current_hp, o.max_hp)


func test_full_heal_restores() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	o.apply_damage(33)
	o.full_heal()
	assert_eq(o.current_hp, o.max_hp)


func test_add_xp_levels_up() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	var curve := [0, 30, 70, 130]
	var gained := o.add_xp(35, curve)
	assert_eq(gained, 1)
	assert_eq(o.level, 2)


func test_effective_stats_with_gear() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	o.equipped_gear["weapon"] = "twohanded-axe-common"
	var stats: Dictionary = o.effective_stats(ItemRegistry)
	# Axe gives +4 attack, -1 defense (clamped)
	assert_eq(stats["attack"], 9 + 4)
	assert_eq(stats["defense"], max(0, 2 - 1))


func test_effective_stats_with_trait() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	o.traits.append("thick-hide")
	var stats: Dictionary = o.effective_stats(ItemRegistry)
	# Thick Hide: +2 defense, +5 max_hp
	assert_eq(stats["defense"], 2 + 2)
	assert_eq(stats["max_hp"], 35 + 5)


func test_to_dict_round_trips_fields() -> void:
	var o := Orc.from_archetype(_berserker_archetype())
	o.name = "Test Name"
	o.kills = 5
	o.scars = 2
	var d := o.to_dict()
	assert_eq(d["name"], "Test Name")
	assert_eq(d["kills"], 5)
	assert_eq(d["scars"], 2)
	assert_eq(d["archetype_id"], "berserker")
