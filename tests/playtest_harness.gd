class_name PlaytestHarness
extends RefCounted

# Runs N seeded games across the difficulty × map-size matrix, collects stats,
# and writes a balance report. Substitutes (partially) for human playtesting:
# it can't tell you if the game is FUN, but it can tell you if (e.g.) Apocalypse
# is unwinnable on Quick maps, or if Tourist is too easy on Long maps, or if
# starvation deaths dominate the defeat-cause distribution.
#
# Each simulated run plays a default policy:
#   - Establish base at starting tile on day 1
#   - Scavenge if tile unsearched, else move toward nearest unsearched tile
#   - Build cheapest available enhancement when at base with resources
#   - Rest if HP < 50%
#   - End day otherwise
# This isn't a smart AI; it's a "reasonable median player" baseline so balance
# numbers are comparable across seeds.

const TURN_BUDGET := 80     # cap runs to prevent infinite loops in pathological seeds
const SEEDS_PER_CELL := 5   # runs per (difficulty, map_size) cell

static var results: Array = []   # one Dictionary per run

static func run() -> Dictionary:
	results.clear()
	var diffs: Array = [
		GameState.Difficulty.TOURIST,
		GameState.Difficulty.STANDARD,
		GameState.Difficulty.APOCALYPSE,
	]
	var sizes: Array = [
		Vector2i(10, 10),
		Vector2i(14, 14),
		Vector2i(20, 20),
	]
	var seed_base: int = 100000
	for d in diffs:
		for sz in sizes:
			for i in SEEDS_PER_CELL:
				var seed_val: int = seed_base + i * 991 + d * 101 + sz.x * 11
				var r: Dictionary = _simulate_one(d, sz, seed_val)
				r["difficulty"] = int(d)
				r["map_size"] = "%dx%d" % [sz.x, sz.y]
				r["seed"] = seed_val
				results.append(r)
	return _summarize(results)

# ---------- per-run sim ----------

static func _simulate_one(diff: int, sz: Vector2i, seed_val: int) -> Dictionary:
	GameState.reset_run(GameState.Mode.SOLO, seed_val, diff, sz)
	GameState.grid = MapGenerator.generate(sz)
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(sz.x / 2, sz.y / 2)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid.add_entity(lead)
	# Starting kit.
	GameState.add_to_inventory("knife", 1)
	GameState.add_to_inventory("bandage", 2)
	GameState.add_to_inventory("canned_food", 3)
	GameState.add_to_inventory("water_bottle", 2)
	GameState.add_to_inventory("wood", 6)
	GameState.add_to_inventory("scrap", 6)
	InventorySystem.assign(lead.id, "knife")
	# A couple seed zombies.
	for _i in 3:
		var z := ZombieUnit.make("single")
		z.pos = GameState.grid.random_edge_position()
		GameState.grid.add_entity(z)
	TurnManager.recompute_vision(GameState.grid)

	var turns: int = 0
	while GameState.phase == GameState.Phase.PLAYING and turns < TURN_BUDGET:
		_take_turn(GameState.grid)
		TurnManager.end_turn(GameState.grid)
		turns += 1

	# Defeat-cause inference.
	var defeat_cause: String = "alive"
	if GameState.phase == GameState.Phase.GAME_OVER:
		if GameState.last_run_victory:
			defeat_cause = "victory"
		elif GameState.megahorde_unlocked and GameState.megahorde_eta <= 0 and GameState.party.is_empty():
			defeat_cause = "megahorde_wipe"
		elif GameState.party.is_empty():
			defeat_cause = "party_wipe"
		elif GameState.morale <= 0:
			defeat_cause = "morale_collapse"
		else:
			defeat_cause = "other"

	return {
		"turns": turns,
		"days_survived": GameState.day,
		"phase": int(GameState.phase),
		"morale": GameState.morale,
		"party_size_final": GameState.party.size(),
		"zombies_killed": int(GameState.stats.get("zombies_killed", 0)),
		"npcs_recruited": int(GameState.stats.get("npcs_recruited", 0)),
		"npcs_betrayed": int(GameState.stats.get("npcs_betrayed", 0)),
		"events_seen": int(GameState.stats.get("events_seen", 0)),
		"megahorde_unlocked": GameState.megahorde_unlocked,
		"defeat_cause": defeat_cause,
	}

static func _take_turn(grid: Grid) -> void:
	if GameState.party.is_empty(): return
	var lead = GameState.party[0]
	var t: Tile = grid.get_tile(lead.pos)
	if t == null: return
	# Priority 1: establish base on day 1.
	if GameState.day == 1 and not GameState.has_base:
		BaseSystem.establish(lead.pos, grid)
		return
	# Priority 2: at base with resources → start cheapest available build.
	if lead.pos == GameState.base_pos and GameState.building_enhancement_id == "":
		var pick: String = _cheapest_buildable()
		if pick != "":
			BaseSystem.start_build(pick)
			return
	# Priority 3: scavenge if current tile unsearched.
	if not t.searched:
		InventorySystem.scavenge_tile(grid)
		return
	# Priority 4: rest if hurt.
	if lead.hp < lead.max_hp / 2:
		GameState.adjust_lead_hp(1)
		return
	# Priority 5: move toward an unsearched neighbor that isn't hostile.
	var best: Vector2i = lead.pos
	for n in grid.neighbors4(lead.pos):
		var nt: Tile = grid.get_tile(n)
		if nt == null or nt.has_hostile(): continue
		if not nt.searched:
			best = n; break
	if best != lead.pos:
		TurnManager.attempt_move(grid, best)
	# Else: implicit "end day" via end_turn called by caller.

static func _cheapest_buildable() -> String:
	var best: String = ""
	var best_cost: int = 99999
	for id in DataLoader.enhancements.keys():
		var check: Dictionary = BaseSystem.can_build(String(id))
		if not bool(check.get("ok", false)):
			continue
		var enh: Dictionary = DataLoader.enhancements[id]
		var cost_sum: int = 0
		for k in enh.get("cost", {}).keys():
			cost_sum += int(enh["cost"][k])
		if cost_sum < best_cost:
			best_cost = cost_sum
			best = String(id)
	return best

# ---------- summary ----------

static func _summarize(rs: Array) -> Dictionary:
	var by_cell: Dictionary = {}
	for r in rs:
		var key: String = "%d / %s" % [int(r.difficulty), r.map_size]
		if not by_cell.has(key):
			by_cell[key] = {"n": 0, "days": 0, "zombies": 0, "betrayals": 0,
				"events": 0, "victories": 0, "wipes": 0, "morale_deaths": 0}
		var c: Dictionary = by_cell[key]
		c["n"] += 1
		c["days"] += int(r.days_survived)
		c["zombies"] += int(r.zombies_killed)
		c["betrayals"] += int(r.npcs_betrayed)
		c["events"] += int(r.events_seen)
		match String(r.defeat_cause):
			"victory": c["victories"] += 1
			"party_wipe", "megahorde_wipe": c["wipes"] += 1
			"morale_collapse": c["morale_deaths"] += 1
			_: pass
	var findings: Array = []
	# Surface degenerate cells.
	for key in by_cell.keys():
		var c: Dictionary = by_cell[key]
		var n: int = c.n
		var avg_days: float = c.days / float(n)
		var wipe_rate: float = c.wipes / float(n)
		var morale_rate: float = c.morale_deaths / float(n)
		if avg_days < 5:
			findings.append("%s: median run dies in %.1f days (too brutal)" % [key, avg_days])
		if wipe_rate > 0.7:
			findings.append("%s: %.0f%% of runs end in party wipe" % [key, wipe_rate * 100])
		if morale_rate > 0.6:
			findings.append("%s: %.0f%% of runs end in morale collapse — food economy too tight" % [key, morale_rate * 100])
	return {
		"runs_total": rs.size(),
		"by_cell": by_cell,
		"findings": findings,
	}

static func print_report(summary: Dictionary) -> void:
	print("\n[playtest] === %d runs ===" % int(summary.runs_total))
	var keys: Array = summary.by_cell.keys()
	keys.sort()
	for key in keys:
		var c: Dictionary = summary.by_cell[key]
		var n: int = c.n
		print("[playtest] %s  runs=%d  avg_days=%.1f  zk=%d/run  evt=%d/run  betray=%d  wipes=%d  morale_deaths=%d  vict=%d" % [
			key, n, c.days / float(n),
			c.zombies / n, c.events / n, c.betrayals, c.wipes, c.morale_deaths, c.victories,
		])
	if (summary.findings as Array).is_empty():
		print("[playtest] No degenerate cells.")
	else:
		print("[playtest] Findings:")
		for f in summary.findings:
			print("  - " + str(f))
