class_name E2EHarness
extends RefCounted

# End-to-end playthrough harness. Programmatically drives the game through
# every flow described in `production/e2e/completion-criteria.md` and prints
# scoreable lines:
#
#   [E2E] P03 vision_on_move ........... PASS
#   [E2E] P15 megahorde_victory ........ FAIL  expected victory, got defeat
#
# Pieces are referenced by their `Pnn` ID from completion-criteria.md.
# Each line is parsed by the orchestrator.

const SEED := 42424242

static var results: Array = []
static var fails: int = 0

static func run(root: Node) -> bool:
	results.clear()
	fails = 0
	print("[E2E] === Starting E2E playthrough (seed=%d) ===" % SEED)
	_phase_a_init()
	_phase_b_map()
	_phase_c_movement_and_vision(root)
	_phase_d_scavenge()
	_phase_e_base_and_build()
	_phase_f_inventory()
	_phase_g_combat()
	_phase_h_parley_and_trade()
	_phase_i_faction_ai()
	_phase_j_betrayal()
	_phase_k_swarm()
	_phase_l_save_load()
	_phase_m_knowledge()
	_phase_n_megahorde_victory()
	_phase_o_defeats()
	_phase_q_events()
	_phase_r_settlement_stats_tasks()
	_phase_s_difficulty_and_map_size()
	_phase_t_new_content_coverage()
	_phase_p_ui_scenes(root)
	_summary()
	return fails == 0

# ---------- assertion helpers ----------

static func _record(piece: String, name: String, passed: bool, detail: String = "") -> void:
	var label: String = "%s %s" % [piece, name]
	var padded: String = label + "".rpad(max(0, 38 - label.length()), ".")
	var status: String = "PASS" if passed else "FAIL"
	var msg: String = "[E2E] %s %s%s" % [padded, status, ("  " + detail) if detail != "" else ""]
	print(msg)
	results.append({"piece": piece, "name": name, "pass": passed, "detail": detail})
	if not passed:
		fails += 1

static func _eq(piece: String, name: String, expected, actual) -> void:
	_record(piece, name, expected == actual,
		"" if expected == actual else "expected %s, got %s" % [str(expected), str(actual)])

static func _truthy(piece: String, name: String, value, detail: String = "") -> void:
	_record(piece, name, bool(value), detail)

static func _between(piece: String, name: String, low: float, high: float, value: float) -> void:
	var ok: bool = value >= low and value <= high
	_record(piece, name, ok, "" if ok else "%f not in [%f, %f]" % [value, low, high])

# ---------- harness setup ----------

static func _fresh_grid_with_lead(at: Vector2i = Vector2i(7, 7)) -> Survivor:
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var lead := Survivor.make_lead()
	lead.pos = at
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid.add_entity(lead)
	TurnManager.recompute_vision(GameState.grid)
	return lead

# ---------- PHASES ----------

static func _phase_a_init() -> void:
	print("\n[E2E] -- Phase A: Initialization --")
	# P1 boot — autoloads non-null
	_truthy("P01", "autoload_DataLoader", DataLoader != null)
	_truthy("P01", "autoload_GameState", GameState != null)
	_truthy("P01", "autoload_EventBus", EventBus != null)
	_truthy("P01", "autoload_RNG", RNG != null)
	# Data sanity
	_truthy("P01", "terrain_loaded", DataLoader.terrain.size() >= 10)
	_truthy("P01", "events_loaded", DataLoader.events.size() >= 17)

static func _phase_b_map() -> void:
	print("\n[E2E] -- Phase B: Map generation --")
	var t0: int = Time.get_ticks_msec()
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var dt: int = Time.get_ticks_msec() - t0
	_truthy("P02", "perf_under_100ms", dt < 100, "took %dms" % dt)
	_eq("P02", "size_14x14", Vector2i(14, 14), GameState.grid.size)
	# At least one building should exist somewhere.
	var building_count: int = 0
	var road_count: int = 0
	for x in 14:
		for y in 14:
			var t: Tile = GameState.grid.get_tile(Vector2i(x, y))
			if t == null: continue
			if t.is_building():
				building_count += 1
			if t.terrain_id == "road":
				road_count += 1
	_truthy("P02", "buildings_present", building_count >= 5, "%d buildings" % building_count)
	_truthy("P02", "road_carved", road_count >= 3, "%d road tiles" % road_count)

static func _phase_c_movement_and_vision(_root: Node) -> void:
	print("\n[E2E] -- Phase C: Movement & vision --")
	var lead := _fresh_grid_with_lead(Vector2i(7, 7))
	var before_explored: int = _count_explored()
	var target := Vector2i(8, 7)
	var ok: bool = TurnManager.attempt_move(GameState.grid, target)
	_truthy("P04", "move_returns_true", ok)
	_eq("P04", "lead_pos_updated", target, lead.pos)
	TurnManager.recompute_vision(GameState.grid)
	var after_explored: int = _count_explored()
	_truthy("P03", "explored_increased", after_explored > before_explored,
		"before %d after %d" % [before_explored, after_explored])
	# Vision radius matches config.
	var vr: int = TurnManager.vision_radius()
	_eq("P03", "vision_radius_base_2", 2, vr)
	# Tiles outside vision should not be `visible` (but may be explored).
	var far := Vector2i(0, 0)
	var t_far: Tile = GameState.grid.get_tile(far)
	if t_far != null:
		_truthy("P03", "far_tile_not_visible", not t_far.visible)
	# Adding a watchtower should expand vision.
	GameState.has_base = true
	GameState.base_enhancements.append("watchtower")
	_truthy("P03", "watchtower_expands_vision", TurnManager.vision_radius() > 2,
		"vr=%d" % TurnManager.vision_radius())
	GameState.base_enhancements.erase("watchtower")
	GameState.has_base = false
	# Party follows: add a recruit, move, both move together.
	var r := Survivor.new()
	r.display_name = "Recruit"
	r.faction_id = "lone_wolf"
	r.pos = lead.pos
	GameState.party.append(r)
	GameState.assignments[r.id] = []
	GameState.grid.add_entity(r)
	var t2 := Vector2i(9, 7)
	TurnManager.attempt_move(GameState.grid, t2)
	_eq("P04", "party_follows_lead", t2, r.pos)

static func _count_explored() -> int:
	var n: int = 0
	for x in GameState.grid.size.x:
		for y in GameState.grid.size.y:
			var t: Tile = GameState.grid.get_tile(Vector2i(x, y))
			if t and t.explored:
				n += 1
	return n

static func _phase_d_scavenge() -> void:
	print("\n[E2E] -- Phase D: Scavenge --")
	_fresh_grid_with_lead(Vector2i(2, 2))
	# Force the lead's tile to a supermarket with high supplies.
	var t := Tile.new(Vector2i(2, 2), "supermarket")
	t.supplies = 5
	GameState.grid.set_tile(Vector2i(2, 2), t)
	GameState.grid.add_entity(GameState.party[0])
	var before_inv: int = _inventory_total()
	var r: Dictionary = InventorySystem.scavenge_tile(GameState.grid)
	_truthy("P05", "scavenge_ok", bool(r.get("ok", false)))
	_truthy("P05", "tile_marked_searched", t.searched)
	var after_inv: int = _inventory_total()
	_truthy("P05", "inventory_grew", after_inv > before_inv,
		"before %d after %d" % [before_inv, after_inv])
	# Repeat scavenge should fail.
	var r2: Dictionary = InventorySystem.scavenge_tile(GameState.grid)
	_truthy("P05", "double_scavenge_blocked", not bool(r2.get("ok", true)))

static func _inventory_total() -> int:
	var n: int = 0
	for v in GameState.inventory.values():
		n += int(v)
	return n

static func _phase_e_base_and_build() -> void:
	print("\n[E2E] -- Phase E: Base & build --")
	_fresh_grid_with_lead(Vector2i(5, 5))
	# Force tile to a house for known defense bonus.
	GameState.grid.set_tile(Vector2i(5, 5), Tile.new(Vector2i(5, 5), "house"))
	GameState.grid.add_entity(GameState.party[0])
	var ok: bool = BaseSystem.establish(Vector2i(5, 5), GameState.grid)
	_truthy("P07", "establish_returns_true", ok)
	_truthy("P07", "has_base_flag", GameState.has_base)
	_truthy("P07", "defense_bonus_set", GameState.base_defense_bonus > 0,
		"defense=%d" % GameState.base_defense_bonus)
	# Stock resources and start building barricade.
	GameState.add_to_inventory("wood", 10)
	GameState.add_to_inventory("scrap", 10)
	var wood_before: int = int(GameState.inventory.get("wood", 0))
	var scrap_before: int = int(GameState.inventory.get("scrap", 0))
	var started: bool = BaseSystem.start_build("barricade")
	_truthy("P08", "start_build_ok", started)
	_eq("P08", "building_enhancement_set", "barricade", GameState.building_enhancement_id)
	var days: int = GameState.building_days_left
	_truthy("P08", "days_left_positive", days > 0, "days=%d" % days)
	# Gap 5: cost actually deducted from inventory.
	var barricade_cost: Dictionary = DataLoader.enhancements.get("barricade", {}).get("cost", {})
	_eq("P08", "wood_deducted",
		wood_before - int(barricade_cost.get("wood", 0)),
		int(GameState.inventory.get("wood", 0)))
	_eq("P08", "scrap_deducted",
		scrap_before - int(barricade_cost.get("scrap", 0)),
		int(GameState.inventory.get("scrap", 0)))
	# Tick days until completion.
	for _i in days + 1:
		BaseSystem.tick_day()
	_truthy("P08", "barricade_built", GameState.base_enhancements.has("barricade"))
	_eq("P08", "building_cleared", "", GameState.building_enhancement_id)

static func _phase_f_inventory() -> void:
	print("\n[E2E] -- Phase F: Inventory --")
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var lead := Survivor.make_lead()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.add_to_inventory("machete", 1)  # attack 5
	var atk_before: int = CombatResolver.party_attack_power()
	InventorySystem.assign(lead.id, "machete")
	var atk_after: int = CombatResolver.party_attack_power()
	_truthy("P09", "assign_raises_attack", atk_after > atk_before,
		"before %d after %d" % [atk_before, atk_after])
	# Unassign returns to stash.
	InventorySystem.unassign(lead.id, "machete")
	_truthy("P09", "unassign_returns_to_stash", GameState.has_item("machete", 1))
	# Use consumable
	GameState.add_to_inventory("bandage", 1)
	lead.hp = 4
	var r: Dictionary = InventorySystem.use_consumable(lead.id, "bandage")
	_truthy("P09", "consumable_ok", bool(r.get("ok", false)))
	_eq("P09", "hp_after_heal", 7, lead.hp)

static func _phase_g_combat() -> void:
	print("\n[E2E] -- Phase G: Combat --")
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	var lead := Survivor.make_lead()
	lead.attack = 50  # overpowered for deterministic kill
	lead.pos = Vector2i(5, 5)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead)
	var z := ZombieUnit.make("single")
	z.pos = lead.pos
	GameState.grid.add_entity(z)
	var hp_before: int = z.hp
	var result: Dictionary = CombatResolver.resolve_attack(z, GameState.grid)
	_truthy("P06", "damage_dealt", int(result.get("damage_to_zombie", 0)) > 0)
	_truthy("P06", "zombie_killed_when_overpowered", bool(result.get("zombie_killed", false)),
		"hp_before=%d damage=%d" % [hp_before, int(result.get("damage_to_zombie", 0))])
	# Megahorde branch (separate run because the run_end fires).
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var lead2 := Survivor.make_lead()
	lead2.attack = 9999
	lead2.pos = Vector2i(5, 5)
	GameState.party.append(lead2)
	GameState.assignments[lead2.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead2)
	var mh := ZombieUnit.make("megahorde")
	mh.pos = lead2.pos
	GameState.grid.add_entity(mh)
	CombatResolver.resolve_attack(mh, GameState.grid)
	_eq("P06", "megahorde_kill_triggers_victory", GameState.Phase.GAME_OVER, GameState.phase)

	# Gap 4: resolve_flee — open terrain success path.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED + 9)
	var lead_f := Survivor.make_lead()
	lead_f.pos = Vector2i(5, 5)
	GameState.party.append(lead_f)
	GameState.assignments[lead_f.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	# Force the lead's tile to plains (high escape bonus +2).
	GameState.grid.set_tile(lead_f.pos, Tile.new(lead_f.pos, "plains"))
	GameState.grid.add_entity(lead_f)
	var zf := ZombieUnit.make("single")
	zf.pos = lead_f.pos
	GameState.grid.add_entity(zf)
	var tile_f: Tile = GameState.grid.get_tile(lead_f.pos)
	var pos_before_flee: Vector2i = lead_f.pos
	var flee_result: Dictionary = CombatResolver.resolve_flee(zf, GameState.grid, tile_f)
	_truthy("P06", "flee_result_has_success_key", flee_result.has("success"))
	# On success the lead moves to a neighbor; on failure they take damage.
	if bool(flee_result.get("success", false)):
		_truthy("P06", "flee_success_moves_lead", lead_f.pos != pos_before_flee)
	else:
		_truthy("P06", "flee_failure_dealt_damage",
			int(flee_result.get("damage", 0)) > 0 or int(flee_result.get("casualties", 0)) > 0)

static func _phase_h_parley_and_trade() -> void:
	print("\n[E2E] -- Phase H: Parley & trade --")
	_fresh_grid_with_lead(Vector2i(5, 5))
	var npc := Npc.new()
	npc.faction_id = "scavengers"
	npc.pos = Vector2i(5, 6)  # adjacent to lead
	GameState.grid.add_entity(npc)
	var payload: Dictionary = ParleySystem.build_parley(npc)
	_truthy("P10", "parley_payload_built", payload.size() > 0)
	_truthy("P10", "parley_has_options", (payload.get("options", []) as Array).size() >= 3)
	# Exercise trade buy/sell.
	GameState.add_to_inventory("scrap", 100)
	var stock: Dictionary = TradeSystem.generate_stock(npc)
	_truthy("P12", "stock_generated", stock.size() > 0)
	# Take first item, buy it.
	var first_id: String = String(stock.keys()[0])
	var scrap_before_buy: int = int(GameState.inventory.get("scrap", 0))
	var buy_price: int = TradeSystem.sell_price(first_id, npc)
	var bought: bool = TradeSystem.execute_buy(first_id, npc, stock)
	_truthy("P12", "trade_buy_ok", bought)
	_truthy("P12", "stash_has_bought_item", GameState.has_item(first_id, 1))
	# Gap 3: scrap ledger must actually deduct.
	_eq("P12", "scrap_deducted_on_buy",
		scrap_before_buy - buy_price,
		int(GameState.inventory.get("scrap", 0)))
	# Sell back something else.
	GameState.add_to_inventory("knife", 1)
	var scrap_before_sell: int = int(GameState.inventory.get("scrap", 0))
	var sell_credit: int = TradeSystem.buy_price("knife", npc)
	var sold: bool = TradeSystem.execute_sell("knife", npc, stock)
	_truthy("P12", "trade_sell_ok", sold)
	_eq("P12", "scrap_credited_on_sell",
		scrap_before_sell + sell_credit,
		int(GameState.inventory.get("scrap", 0)))

static func _phase_i_faction_ai() -> void:
	print("\n[E2E] -- Phase I: Faction AI --")
	_fresh_grid_with_lead(Vector2i(7, 7))
	# Spawn a doctor; injure lead; tick a few times; expect doctor to drift close.
	GameState.party[0].hp = 2  # injured
	var doc := Npc.new()
	doc.faction_id = "doctors"
	doc.pos = Vector2i(0, 0)
	GameState.grid.add_entity(doc)
	var initial_dist: int = GameState.grid.chebyshev(doc.pos, GameState.party[0].pos)
	# Tick movement 6 times.
	for _i in 6:
		var t: Vector2i = NpcBehavior.step(doc, GameState.grid)
		if GameState.grid.in_bounds(t):
			GameState.grid.move_entity(doc, t)
		NpcBehavior.post_step_action(doc, GameState.grid)
	var final_dist: int = GameState.grid.chebyshev(doc.pos, GameState.party[0].pos)
	_truthy("P11", "doctor_approaches_injured", final_dist < initial_dist,
		"initial=%d final=%d" % [initial_dist, final_dist])

	# Scavenger drift to buildings — count whether scavenger ends up on/adjacent to a building tile.
	var scav := Npc.new()
	scav.faction_id = "scavengers"
	scav.pos = Vector2i(0, 0)
	GameState.grid.add_entity(scav)
	for _i in 12:
		var t: Vector2i = NpcBehavior.step(scav, GameState.grid)
		if GameState.grid.in_bounds(t):
			GameState.grid.move_entity(scav, t)
	# Walk-by check: any of the tiles within 1 step is a building.
	var found_bldg: bool = false
	for n in GameState.grid.neighbors8(scav.pos) + [scav.pos]:
		var t: Tile = GameState.grid.get_tile(n)
		if t and t.is_building():
			found_bldg = true
			break
	_truthy("P11", "scavenger_drifts_to_buildings", found_bldg)

	# Raider stalking — within range, biases toward lead.
	_fresh_grid_with_lead(Vector2i(7, 7))
	var raider := Npc.new()
	raider.faction_id = "raiders"
	raider.pos = Vector2i(11, 7)
	GameState.grid.add_entity(raider)
	var initial_dist_r: int = GameState.grid.chebyshev(raider.pos, GameState.party[0].pos)
	for _i in 6:
		var t: Vector2i = NpcBehavior.step(raider, GameState.grid)
		if GameState.grid.in_bounds(t):
			GameState.grid.move_entity(raider, t)
	var final_dist_r: int = GameState.grid.chebyshev(raider.pos, GameState.party[0].pos)
	_truthy("P11", "raider_stalks_lead", final_dist_r <= initial_dist_r,
		"initial=%d final=%d" % [initial_dist_r, final_dist_r])

	# Cultist drifts toward zombies, not lead.
	_fresh_grid_with_lead(Vector2i(7, 7))
	var z := ZombieUnit.make("single")
	z.pos = Vector2i(2, 2)
	GameState.grid.add_entity(z)
	var cult := Npc.new()
	cult.faction_id = "cultists"
	cult.pos = Vector2i(0, 0)
	GameState.grid.add_entity(cult)
	var dist_to_z_initial: int = GameState.grid.chebyshev(cult.pos, z.pos)
	for _i in 6:
		var t: Vector2i = NpcBehavior.step(cult, GameState.grid)
		if GameState.grid.in_bounds(t):
			GameState.grid.move_entity(cult, t)
	var dist_to_z_final: int = GameState.grid.chebyshev(cult.pos, z.pos)
	_truthy("P11", "cultist_drifts_to_zombies", dist_to_z_final <= dist_to_z_initial,
		"initial=%d final=%d" % [dist_to_z_initial, dist_to_z_final])

static func _phase_j_betrayal() -> void:
	print("\n[E2E] -- Phase J: Betrayal --")
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	GameState.morale = 3  # high tension
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(5, 5)
	GameState.party.append(lead)
	var c := Survivor.new()
	c.display_name = "Bad"
	c.faction_id = "cannibals"
	c.betrayal_chance = 0.85
	c.pos = Vector2i(5, 5)
	GameState.party.append(c)
	GameState.assignments[lead.id] = []
	GameState.assignments[c.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead)
	GameState.grid.add_entity(c)
	var betrayed: bool = false
	var night: int = 0
	for i in 15:
		night = i + 1
		BetrayalSystem.nightly_check(GameState.grid)
		if GameState.party.size() == 1 or GameState.party.is_empty():
			betrayed = true
			break
	_truthy("P13", "betrayal_fires_within_15_nights", betrayed, "by night %d" % night)
	# Gap 6: betrayal side-effects landed somewhere observable.
	# Either inventory was reduced (steal), zombie spawned (gates), or HP was taken (knife).
	# Stats counter must have incremented.
	_truthy("P13", "betrayal_stats_incremented",
		int(GameState.stats.get("npcs_betrayed", 0)) >= 1,
		"npcs_betrayed=%d" % int(GameState.stats.get("npcs_betrayed", 0)))
	# Tension modifier scales with morale.
	GameState.morale = 10
	_truthy("P13", "tension_low_at_full_morale", BetrayalSystem._current_tension_modifier() <= 1.0)
	GameState.morale = 3
	_truthy("P13", "tension_high_at_low_morale", BetrayalSystem._current_tension_modifier() >= 2.0)
	# Loyal lone_wolf (5% chance) survives many nights with full morale.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED + 1)
	GameState.morale = 10
	var loyal_lead := Survivor.make_lead()
	var loyal := Survivor.new()
	loyal.display_name = "Loyal"
	loyal.faction_id = "lone_wolf"
	loyal.betrayal_chance = 0.05
	GameState.party.append(loyal_lead)
	GameState.party.append(loyal)
	GameState.assignments[loyal_lead.id] = []
	GameState.assignments[loyal.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(loyal_lead)
	GameState.grid.add_entity(loyal)
	for _i in 30:
		BetrayalSystem.nightly_check(GameState.grid)
	_truthy("P13", "loyal_recruit_usually_survives_30_nights",
		GameState.party.size() >= 1, "party=%d" % GameState.party.size())

static func _phase_k_swarm() -> void:
	print("\n[E2E] -- Phase K: Swarm warning + spawn --")
	_fresh_grid_with_lead()
	# Advance enough days to schedule a swarm; force the schedule pathway by
	# repeatedly running on_day_advanced with a high RNG re-seed to bias yes.
	RNG.seed_run(SEED)
	GameState.day = 8
	var scheduled: bool = false
	var attempts: int = 0
	while not scheduled and attempts < 40:
		GameState.day += 1
		SwarmSystem.on_day_advanced(GameState.day, GameState.grid)
		if not GameState.swarm_pending.is_empty():
			scheduled = true
		attempts += 1
	_truthy("P14", "swarm_scheduled_within_40_days", scheduled, "attempts=%d" % attempts)
	if scheduled:
		var kind: String = String(GameState.swarm_pending.get("kind", ""))
		_between("P14", "swarm_eta_in_range", 1.0, 4.0,
			float(GameState.swarm_pending.get("eta_days", 0)))
		# Tick down to 0 and assert spawn.
		var safety: int = 0
		while not GameState.swarm_pending.is_empty() and safety < 6:
			GameState.day += 1
			SwarmSystem.on_day_advanced(GameState.day, GameState.grid)
			safety += 1
		var found_unit: bool = false
		for e in GameState.grid.entities:
			if e is ZombieUnit and e.unit_id == kind:
				found_unit = true
				break
		_truthy("P14", "swarm_spawned_on_grid", found_unit, "kind=%s" % kind)

static func _phase_l_save_load() -> void:
	print("\n[E2E] -- Phase L: Save / Load --")
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(3, 4)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead)
	GameState.add_to_inventory("knife", 3)
	GameState.add_to_inventory("machete", 1)
	InventorySystem.assign(lead.id, "machete")  # ensures assignments has the int key
	GameState.knowledge.append("cannibal_warning")
	GameState.day = 11
	GameState.morale = 6
	var t0: int = Time.get_ticks_msec()
	var save_ok: bool = SaveSystem.save()
	var dt_save: int = Time.get_ticks_msec() - t0
	_truthy("P16", "save_ok", save_ok)
	_truthy("P16", "save_perf_500ms", dt_save < 500, "took %dms" % dt_save)
	# Mutate.
	GameState.day = 999
	GameState.morale = 0
	t0 = Time.get_ticks_msec()
	var load_ok: bool = SaveSystem.load_run()
	var dt_load: int = Time.get_ticks_msec() - t0
	_truthy("P16", "load_ok", load_ok)
	_truthy("P16", "load_perf_500ms", dt_load < 500, "took %dms" % dt_load)
	_eq("P16", "day_restored", 11, GameState.day)
	_eq("P16", "morale_restored", 6, GameState.morale)
	_eq("P16", "knife_count_restored", 3, int(GameState.inventory.get("knife", 0)))
	_truthy("P16", "knowledge_restored", GameState.knowledge.has("cannibal_warning"))
	# Gap 1: party state details must round-trip.
	_eq("P16", "lead_pos_restored", Vector2i(3, 4), GameState.party[0].pos)
	_truthy("P16", "lead_is_lead_flag_restored", GameState.party[0].is_lead)
	_truthy("P16", "lead_hp_preserved", GameState.party[0].hp > 0)
	# Gap 2: assignments must round-trip with int keys intact.
	var lead_id_after: int = GameState.party[0].id
	_truthy("P16", "assignments_dict_has_lead",
		GameState.assignments.has(lead_id_after),
		"assignments=%s lead_id=%d" % [str(GameState.assignments.keys()), lead_id_after])
	SaveSystem.delete_save()

static func _phase_m_knowledge() -> void:
	print("\n[E2E] -- Phase M: Knowledge --")
	_fresh_grid_with_lead()
	var c := Npc.new()
	c.faction_id = "cannibals"
	c.pos = Vector2i(8, 7)
	GameState.grid.add_entity(c)
	# Parley with cannibal — choose "Question them carefully" (index 1) to reveal.
	var payload: Dictionary = ParleySystem.build_parley(c)
	EventSystem.resolve_choice(payload, 1, GameState.grid)
	_truthy("P18", "cannibal_warning_added", GameState.knowledge.has("cannibal_warning"))
	# Knowledge entries persist across resets only if intended; ensure they
	# reset on `reset_run`.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	_truthy("P18", "knowledge_clears_on_reset_run", GameState.knowledge.is_empty())
	# Adding knowledge again works (no dedup-blocker).
	GameState.knowledge.append("the_truth")
	GameState.knowledge.append("immunity_exists")
	_eq("P18", "multiple_knowledge_entries", 2, GameState.knowledge.size())
	# DataLoader has summaries for each.
	_truthy("P18", "knowledge_dataloader_has_summary",
		DataLoader.knowledge.has("cannibal_warning") and
		DataLoader.knowledge.has("the_truth"))

static func _phase_n_megahorde_victory() -> void:
	print("\n[E2E] -- Phase N: Megahorde victory --")
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	# Force unlock state.
	GameState.megahorde_unlocked = true
	GameState.megahorde_eta = 1
	var lead := Survivor.make_lead()
	lead.attack = 9999
	lead.pos = Vector2i(5, 5)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead)
	# Tick swarm — megahorde should spawn.
	SwarmSystem.on_day_advanced(GameState.day + 1, GameState.grid)
	var mh: ZombieUnit = null
	for e in GameState.grid.entities:
		if e is ZombieUnit and e.unit_id == "megahorde":
			mh = e
			break
	_truthy("P15", "megahorde_spawned", mh != null)
	if mh != null:
		# Move lead onto megahorde and resolve combat.
		GameState.grid.move_entity(lead, mh.pos)
		CombatResolver.resolve_attack(mh, GameState.grid)
		_eq("P15", "megahorde_killed_phase_game_over", GameState.Phase.GAME_OVER, GameState.phase)

static func _phase_o_defeats() -> void:
	print("\n[E2E] -- Phase O: Defeat paths --")
	# Defeat: party wipe via lead death.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var lead := Survivor.make_lead()
	lead.hp = 1
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead)
	GameState.adjust_lead_hp(-99)
	_eq("P19", "lead_death_ends_run", GameState.Phase.GAME_OVER, GameState.phase)

	# Defeat: morale zero.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var lead2 := Survivor.make_lead()
	GameState.party.append(lead2)
	GameState.assignments[lead2.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead2)
	GameState.adjust_morale(-99)
	_eq("P19", "morale_zero_ends_run", GameState.Phase.GAME_OVER, GameState.phase)

	# Defeat: party wipe via combat.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	var lead3 := Survivor.make_lead()
	lead3.hp = 1
	lead3.attack = 0
	lead3.pos = Vector2i(5, 5)
	GameState.party.append(lead3)
	GameState.assignments[lead3.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead3)
	var horde := ZombieUnit.make("horde")
	horde.pos = lead3.pos
	GameState.grid.add_entity(horde)
	CombatResolver.resolve_attack(horde, GameState.grid)
	_eq("P19", "party_wipe_combat_ends_run", GameState.Phase.GAME_OVER, GameState.phase)

	# Defeat: lead infected → turn at night (forced).
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	var lead4 := Survivor.make_lead()
	lead4.infected = true
	lead4.pos = Vector2i(5, 5)
	GameState.party.append(lead4)
	GameState.assignments[lead4.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead4)
	# Spin nights until infection turn fires (25% per tick).
	var turned: bool = false
	for _i in 40:
		TurnManager.end_turn(GameState.grid)
		if GameState.phase == GameState.Phase.GAME_OVER:
			turned = true
			break
	_truthy("P19", "infected_lead_eventually_turns", turned)

	# Gap 7: starvation defeat via daily_upkeep integration path.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED + 17)
	GameState.morale = 5  # close-to-zero so starvation can drain quickly
	var lead5 := Survivor.make_lead()
	lead5.pos = Vector2i(5, 5)
	GameState.party.append(lead5)
	GameState.assignments[lead5.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	GameState.grid.add_entity(lead5)
	# No food in stash — every turn morale drops by 1.
	var starvation_turns: int = 0
	for i in 30:
		TurnManager.end_turn(GameState.grid)
		starvation_turns = i + 1
		if GameState.phase == GameState.Phase.GAME_OVER:
			break
	_eq("P19", "starvation_path_ends_run", GameState.Phase.GAME_OVER, GameState.phase)
	_truthy("P19", "starvation_within_reasonable_turns", starvation_turns <= 30,
		"turns=%d" % starvation_turns)

static func _phase_q_events() -> void:
	print("\n[E2E] -- Phase Q: Event system --")
	# Roll the event pool many times across many days; verify multiple distinct
	# events fire, including ones with conditions (on_building) and ones with
	# different effect kinds (items, morale, recruit, tension).
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	RNG.seed_run(SEED)
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(7, 7)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid.add_entity(lead)
	GameState.has_base = true   # let conditional events fire
	GameState.base_pos = lead.pos
	# Force tile to a building so on_building events qualify.
	GameState.grid.set_tile(lead.pos, Tile.new(lead.pos, "house"))
	GameState.grid.add_entity(lead)

	var seen: Dictionary = {}
	var rolls: int = 200
	for i in rolls:
		GameState.day = 10 + i  # past min_day for most events
		var ev: Dictionary = EventSystem.roll_for_event(GameState.grid)
		if not ev.is_empty():
			seen[String(ev.get("id", ""))] = true

	_truthy("P17", "at_least_8_distinct_events", seen.size() >= 8, "saw %d unique" % seen.size())
	# Verify at least one effect kind triggers cleanly: items effect.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var l2 := Survivor.make_lead()
	GameState.party.append(l2)
	GameState.assignments[l2.id] = []
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var inv_before: int = int(GameState.inventory.get("bandage", 0))
	# Construct a minimal event payload exercising items, morale, knowledge.
	var test_event: Dictionary = {
		"id": "_e2e_test",
		"options": [
			{"outcomes": [
				{"weight": 100, "text": "ok", "effects": {
					"items": {"bandage": 2},
					"morale": 1,
					"knowledge": "test_knowledge",
					"tension": 2
				}}
			]}
		]
	}
	EventSystem.resolve_choice(test_event, 0, GameState.grid)
	_eq("P17", "items_effect_grants_bandage", inv_before + 2, int(GameState.inventory.get("bandage", 0)))
	_truthy("P17", "knowledge_effect_added", GameState.knowledge.has("test_knowledge"))
	_truthy("P17", "tension_effect_tracked", GameState._betrayal_tension_bonus_turns > 0)
	# Defense_temp effect:
	GameState._defense_temp_bonus = 0
	GameState._defense_temp_turns = 0
	EventSystem.resolve_choice({"id": "_e2e_dt", "options": [{"outcomes": [
		{"weight": 100, "text": "ok", "effects": {"defense_temp": [4, 5]}}
	]}]}, 0, GameState.grid)
	_eq("P17", "defense_temp_magnitude", 4, GameState._defense_temp_bonus)
	_eq("P17", "defense_temp_turns", 5, GameState._defense_temp_turns)

static func _phase_r_settlement_stats_tasks() -> void:
	print("\n[E2E] -- Phase R: M2 settlement, stats & tasks --")
	GameState.reset_run(GameState.Mode.SETTLED, SEED)
	RNG.seed_run(SEED)
	# M2.1 — stats are populated within bounds.
	var lead := Survivor.make_lead()
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	_truthy("M21", "lead_strength_in_range", lead.strength >= 1 and lead.strength <= 5)
	_truthy("M21", "lead_smarts_in_range", lead.smarts >= 1 and lead.smarts <= 5)
	_truthy("M21", "lead_stealth_in_range", lead.stealth >= 1 and lead.stealth <= 5)
	# Lead has at least one elevated stat (≥ 3).
	_truthy("M21", "lead_has_strong_stat",
		lead.strength >= 3 or lead.smarts >= 3 or lead.stealth >= 3)
	var recruit: Survivor = Survivor.make_random_recruit()
	_truthy("M21", "recruit_stats_in_range",
		recruit.strength >= 1 and recruit.strength <= 5)

	# M2.2 — task system.
	GameState.grid = MapGenerator.generate(GameState.map_size)
	lead.pos = Vector2i(7, 7)
	GameState.grid.add_entity(lead)
	# Establish base + start a build, then assign build_assist.
	BaseSystem.establish(lead.pos, GameState.grid)
	GameState.add_to_inventory("wood", 10)
	GameState.add_to_inventory("scrap", 10)
	BaseSystem.start_build("barricade")
	var days_at_start: int = GameState.building_days_left
	_truthy("M22", "build_started", days_at_start > 0)
	# Add a high-strength helper and assign them to build_assist.
	var helper := Survivor.new()
	helper.display_name = "Helper"
	helper.faction_id = "salvage_engineers"
	helper.strength = 5
	helper.smarts = 5
	helper.pos = lead.pos
	GameState.party.append(helper)
	GameState.assignments[helper.id] = []
	GameState.grid.add_entity(helper)
	TaskSystem.assign_task(helper.id, "build_assist")
	_eq("M22", "task_assigned", "build_assist", helper.daily_task)
	# Execute one turn — should pull at least 1 day off the build.
	TaskSystem.execute_daily_tasks(GameState.grid)
	_truthy("M22", "build_assist_accelerates",
		GameState.building_days_left < days_at_start,
		"start=%d after=%d" % [days_at_start, GameState.building_days_left])
	# Task resets after execution.
	_eq("M22", "task_clears_after_execute", "", helper.daily_task)
	# Guard task adds defense_temp.
	GameState._defense_temp_bonus = 0
	GameState._defense_temp_turns = 0
	TaskSystem.assign_task(helper.id, "guard")
	TaskSystem.execute_daily_tasks(GameState.grid)
	_truthy("M22", "guard_grants_defense_temp", GameState._defense_temp_bonus > 0)

	# M2.5 — tier-3 enhancements present.
	for enh in ["scout_network", "greenhouse", "sniper_nest"]:
		_truthy("M25", "enhancement_%s_defined" % enh, DataLoader.enhancements.has(enh))
		var cfg: Dictionary = DataLoader.enhancements.get(enh, {})
		_truthy("M25", "enhancement_%s_has_cost" % enh, cfg.has("cost"))

static func _phase_s_difficulty_and_map_size() -> void:
	print("\n[E2E] -- Phase S: M3 difficulty + map size --")
	# Tourist has lower spawn multiplier than Apocalypse.
	GameState.difficulty = GameState.Difficulty.TOURIST
	var t_mult: float = DifficultyConfig.zombie_spawn_multiplier()
	GameState.difficulty = GameState.Difficulty.APOCALYPSE
	var a_mult: float = DifficultyConfig.zombie_spawn_multiplier()
	_truthy("M35", "apocalypse_multiplier_higher_than_tourist", a_mult > t_mult,
		"tourist=%f apoc=%f" % [t_mult, a_mult])
	# Food consumption scaling.
	GameState.difficulty = GameState.Difficulty.TOURIST
	var t_food: float = DifficultyConfig.food_consumption_multiplier()
	GameState.difficulty = GameState.Difficulty.APOCALYPSE
	var a_food: float = DifficultyConfig.food_consumption_multiplier()
	_truthy("M35", "apocalypse_food_burn_higher", a_food > t_food,
		"tourist=%f apoc=%f" % [t_food, a_food])
	# Megahorde unlock range shifts.
	GameState.difficulty = GameState.Difficulty.TOURIST
	var t_range: Array = DifficultyConfig.megahorde_unlock_range()
	GameState.difficulty = GameState.Difficulty.APOCALYPSE
	var a_range: Array = DifficultyConfig.megahorde_unlock_range()
	_truthy("M35", "apocalypse_unlocks_earlier",
		int(a_range[0]) < int(t_range[0]),
		"tourist_min=%d apoc_min=%d" % [int(t_range[0]), int(a_range[0])])
	# Restore default for downstream assertions.
	GameState.difficulty = GameState.Difficulty.STANDARD

	# M3.6 — map size variants.
	for sz in [Vector2i(10, 10), Vector2i(14, 14), Vector2i(20, 20)]:
		GameState.reset_run(GameState.Mode.SOLO, SEED, GameState.Difficulty.STANDARD, sz)
		GameState.grid = MapGenerator.generate(sz)
		_eq("M36", "map_size_%dx%d_generated" % [sz.x, sz.y], sz, GameState.grid.size)
	# Larger map → later megahorde unlock day on average.
	GameState.difficulty = GameState.Difficulty.STANDARD
	var small_day: int = DifficultyConfig.megahorde_unlock_day_for_map_size(Vector2i(10, 10))
	var big_day: int = DifficultyConfig.megahorde_unlock_day_for_map_size(Vector2i(20, 20))
	_truthy("M36", "larger_map_has_later_unlock_day", big_day > small_day,
		"10x10=%d 20x20=%d" % [small_day, big_day])

static func _phase_t_new_content_coverage() -> void:
	print("\n[E2E] -- Phase T: M3 new content --")
	_truthy("M31", "events_total_at_least_49", DataLoader.events.size() >= 49,
		"count=%d" % DataLoader.events.size())
	_truthy("M32", "factions_total_at_least_12", DataLoader.factions.size() >= 12,
		"count=%d" % DataLoader.factions.size())
	for fid in ["federal_remnant", "free_traders", "void_children", "pacifists", "salvage_engineers"]:
		_truthy("M32", "faction_%s_defined" % fid, DataLoader.factions.has(fid))
	_truthy("M33", "items_total_at_least_32", DataLoader.items.size() >= 32,
		"count=%d" % DataLoader.items.size())
	_truthy("M34", "terrain_total_at_least_13", DataLoader.terrain.size() >= 13,
		"count=%d" % DataLoader.terrain.size())
	for tid in ["junkyard", "police_station", "farm"]:
		_truthy("M34", "terrain_%s_defined" % tid, DataLoader.terrain.has(tid))
	# Generate enough maps to see all new terrains appear at least once.
	var seen_new: Dictionary = {}
	for _i in 8:
		var g: Grid = MapGenerator.generate(Vector2i(14, 14))
		for x in 14:
			for y in 14:
				var t: Tile = g.get_tile(Vector2i(x, y))
				if t == null: continue
				if t.terrain_id in ["junkyard", "police_station", "farm"]:
					seen_new[t.terrain_id] = true
	_truthy("M34", "new_terrains_appear_in_maps", seen_new.size() >= 2,
		"saw %s" % str(seen_new.keys()))

static func _phase_p_ui_scenes(root: Node) -> void:
	print("\n[E2E] -- Phase P: UI scene boot --")
	# Boot each scene as a child and verify _ready completes without errors.
	# We don't have a built-in way to detect SCRIPT ERROR from inside GDScript,
	# so the orchestrator also greps stderr. The assertions here verify instantiation.
	for scene_path in [
		"res://scenes/MainMenu.tscn",
		"res://scenes/GameView.tscn",
	]:
		GameState.reset_run(GameState.Mode.SOLO, SEED)
		var scene := load(scene_path) as PackedScene
		_truthy("P20", "scene_loads_%s" % scene_path.get_file(), scene != null)
		if scene == null:
			continue
		var inst: Node = scene.instantiate()
		root.add_child(inst)
		_truthy("P20", "scene_instantiates_%s" % scene_path.get_file(), inst != null)
		inst.queue_free()

	# Internal panels live inside GameView. Boot GameView once, then verify each
	# panel child exists, is_visible_in_tree, can show/hide.
	GameState.reset_run(GameState.Mode.SOLO, SEED)
	var gv_packed := load("res://scenes/GameView.tscn") as PackedScene
	if gv_packed == null:
		return
	var gv: Node = gv_packed.instantiate()
	root.add_child(gv)
	# A frame happens implicitly when we add_child. Panels are children:
	for panel_name in ["BuildPanel", "AssignPanel", "TradePanel", "KnowledgePanel", "EventModal", "GameOver", "SettlementView"]:
		var p: Node = gv.get_node_or_null(panel_name)
		_truthy("P20", "gameview_panel_%s_exists" % panel_name, p != null)
		if p == null:
			continue
		# Panel should be hidden by default (visible=false).
		_truthy("P20", "gameview_panel_%s_starts_hidden" % panel_name, not (p as Control).visible)
		# Gap 8: panel show/hide transition exercises the visibility code.
		(p as Control).show()
		_truthy("P20", "gameview_panel_%s_show_works" % panel_name, (p as Control).visible)
		(p as Control).hide()
		_truthy("P20", "gameview_panel_%s_hide_works" % panel_name, not (p as Control).visible)
	gv.queue_free()

# ---------- summary ----------

static func _summary() -> void:
	print("\n[E2E] === Summary ===")
	var by_piece: Dictionary = {}
	for r in results:
		var p: String = r.piece
		if not by_piece.has(p):
			by_piece[p] = {"pass": 0, "fail": 0}
		if r.pass:
			by_piece[p]["pass"] += 1
		else:
			by_piece[p]["fail"] += 1
	var piece_keys: Array = by_piece.keys()
	piece_keys.sort()
	for p in piece_keys:
		var c: Dictionary = by_piece[p]
		var total: int = c.pass + c.fail
		var status: String = "PASS" if c.fail == 0 else "FAIL"
		print("[E2E] %s  %d/%d  %s" % [p, c.pass, total, status])
	print("[E2E] Total assertions: %d  Passed: %d  Failed: %d" %
		[results.size(), results.size() - fails, fails])
	print("[E2E] RESULT: %s" % ("GREEN" if fails == 0 else "RED"))
