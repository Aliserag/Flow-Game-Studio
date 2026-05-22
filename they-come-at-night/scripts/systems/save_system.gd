class_name SaveSystem
extends RefCounted

# Single-slot save/load to user://save.json. Serializes the full run state:
# GameState scalars, party (Survivor instances), grid (tiles + entities),
# inventory, assignments, knowledge, swarm/megahorde counters.
#
# JSON for portability and debuggability; entity references are reconstructed
# by ID on load. Save IDs are stable; Entity._next_id is bumped past the max
# observed ID so new spawns don't collide.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	# DirAccess understands `user://` directly; passing the engine-relative path
	# is portable to HTML5 / mobile exports where globalize_path returns
	# something the OS layer can't reach.
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

static func save() -> bool:
	if GameState.grid == null:
		return false
	var blob: Dictionary = {
		"version": SAVE_VERSION,
		"build_id": BuildInfo.build_id,
		"saved_at": Time.get_unix_time_from_system(),
		"state": _serialize_state(),
		"party": _serialize_party(),
		"assignments": _serialize_assignments(),
		"inventory": GameState.inventory.duplicate(true),
		"knowledge": GameState.knowledge.duplicate(),
		"grid": _serialize_grid(GameState.grid),
		"entities": _serialize_entities(GameState.grid),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: failed to open %s for write" % SAVE_PATH)
		return false
	# Godot 4.4+ — store_string returns bool. A false return means the write
	# silently failed (disk full, permission denied, etc.) and we MUST surface it.
	var wrote_ok: bool = f.store_string(JSON.stringify(blob, "  "))
	f.close()
	if not wrote_ok:
		push_error("SaveSystem: store_string failed for %s" % SAVE_PATH)
		# Best-effort cleanup so a corrupt half-save doesn't poison Continue.
		delete_save()
		return false
	return true

static func load_run() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: malformed JSON in %s" % SAVE_PATH)
		return false
	var blob: Dictionary = parsed
	if int(blob.get("version", 0)) != SAVE_VERSION:
		push_error("SaveSystem: incompatible save version (have %d, expected %d)" %
			[int(blob.get("version", 0)), SAVE_VERSION])
		return false

	# Wipe live state so we start clean. Pass the saved mode so reset doesn't
	# mis-flag listeners that branch on GameState.mode during deserialize.
	var saved_mode: int = int((blob.get("state", {}) as Dictionary).get("mode", GameState.Mode.SOLO))
	GameState.reset_run(saved_mode)
	# Apply state scalars (mode included, redundantly, for safety).
	_deserialize_state(blob.get("state", {}))
	# Inventory & knowledge.
	GameState.inventory = (blob.get("inventory", {}) as Dictionary).duplicate(true)
	GameState.knowledge = (blob.get("knowledge", []) as Array).duplicate()
	# Grid first so entities have a place to land.
	GameState.grid = _deserialize_grid(blob.get("grid", {}))
	# Party.
	var max_id_observed: int = 0
	GameState.party = _deserialize_party(blob.get("party", []), GameState.grid)
	for s in GameState.party:
		max_id_observed = max(max_id_observed, s.id)
	# Other entities.
	var others: Array = _deserialize_entities(blob.get("entities", []), GameState.grid)
	for e in others:
		max_id_observed = max(max_id_observed, e.id)
	# Bump the static Entity ID counter past the max we just restored.
	Entity._next_id = max(Entity._next_id, max_id_observed + 1)
	# Assignments — these reference survivor IDs; replay them now.
	GameState.assignments = _deserialize_assignments(blob.get("assignments", {}))
	# Refresh visibility around the new lead.
	if not GameState.party.is_empty():
		TurnManager.recompute_vision(GameState.grid)
	GameState.phase = GameState.Phase.PLAYING
	EventBus.party_changed.emit()
	EventBus.supplies_changed.emit()
	EventBus.hud_refresh_requested.emit()
	return true

# ---------- serializers ----------

static func _serialize_state() -> Dictionary:
	return {
		"mode": GameState.mode,
		"day": GameState.day,
		"morale": GameState.morale,
		"has_base": GameState.has_base,
		"base_pos": [GameState.base_pos.x, GameState.base_pos.y],
		"base_terrain_id": GameState.base_terrain_id,
		"base_defense_bonus": GameState.base_defense_bonus,
		"base_enhancements": GameState.base_enhancements.duplicate(),
		"building_enhancement_id": GameState.building_enhancement_id,
		"building_days_left": GameState.building_days_left,
		"megahorde_unlocked": GameState.megahorde_unlocked,
		"megahorde_eta": GameState.megahorde_eta,
		"_megahorde_unlock_day": GameState._megahorde_unlock_day,
		"swarm_pending": GameState.swarm_pending.duplicate(true),
		"noise_level": GameState.noise_level,
		"_betrayal_tension_bonus_turns": GameState._betrayal_tension_bonus_turns,
		"_defense_temp_bonus": GameState._defense_temp_bonus,
		"_defense_temp_turns": GameState._defense_temp_turns,
		"_preparation_bonus_pending": GameState._preparation_bonus_pending,
		"run_seed": GameState.run_seed,
		"stats": GameState.stats.duplicate(true),
	}

static func _deserialize_state(s: Dictionary) -> void:
	GameState.mode = int(s.get("mode", GameState.Mode.SOLO))
	GameState.day = int(s.get("day", 1))
	GameState.morale = int(s.get("morale", 7))
	GameState.has_base = bool(s.get("has_base", false))
	var bp: Array = s.get("base_pos", [-1, -1])
	GameState.base_pos = Vector2i(int(bp[0]), int(bp[1]))
	GameState.base_terrain_id = String(s.get("base_terrain_id", ""))
	GameState.base_defense_bonus = int(s.get("base_defense_bonus", 0))
	GameState.base_enhancements = (s.get("base_enhancements", []) as Array).duplicate()
	GameState.building_enhancement_id = String(s.get("building_enhancement_id", ""))
	GameState.building_days_left = int(s.get("building_days_left", 0))
	GameState.megahorde_unlocked = bool(s.get("megahorde_unlocked", false))
	GameState.megahorde_eta = int(s.get("megahorde_eta", -1))
	GameState._megahorde_unlock_day = int(s.get("_megahorde_unlock_day", 0))
	GameState.swarm_pending = (s.get("swarm_pending", {}) as Dictionary).duplicate(true)
	GameState.noise_level = int(s.get("noise_level", 0))
	GameState._betrayal_tension_bonus_turns = int(s.get("_betrayal_tension_bonus_turns", 0))
	GameState._defense_temp_bonus = int(s.get("_defense_temp_bonus", 0))
	GameState._defense_temp_turns = int(s.get("_defense_temp_turns", 0))
	GameState._preparation_bonus_pending = int(s.get("_preparation_bonus_pending", 0))
	GameState.run_seed = int(s.get("run_seed", 0))
	GameState.stats = (s.get("stats", {}) as Dictionary).duplicate(true)

static func _serialize_party() -> Array:
	var out: Array = []
	for s in GameState.party:
		out.append({
			"id": s.id,
			"display_name": s.display_name,
			"hp": s.hp,
			"max_hp": s.max_hp,
			"attack": s.attack,
			"faction_id": s.faction_id,
			"faction_revealed": s.faction_revealed,
			"betrayal_chance": s.betrayal_chance,
			"infected": s.infected,
			"injured": s.injured,
			"is_lead": s.is_lead,
			"pos": [s.pos.x, s.pos.y],
		})
	return out

static func _deserialize_party(arr: Array, grid: Grid) -> Array:
	var out: Array = []
	for raw in arr:
		var d: Dictionary = raw
		var s: Survivor = Survivor.new()
		# Override the auto-assigned id with the saved one for assignment lookup.
		s.id = int(d.get("id", s.id))
		s.display_name = String(d.get("display_name", "?"))
		s.hp = int(d.get("hp", 10))
		s.max_hp = int(d.get("max_hp", 10))
		s.attack = int(d.get("attack", 2))
		s.faction_id = String(d.get("faction_id", "lone_wolf"))
		s.faction_revealed = bool(d.get("faction_revealed", false))
		s.betrayal_chance = float(d.get("betrayal_chance", 0.0))
		s.infected = bool(d.get("infected", false))
		s.injured = bool(d.get("injured", false))
		s.is_lead = bool(d.get("is_lead", false))
		var p: Array = d.get("pos", [0, 0])
		s.pos = Vector2i(int(p[0]), int(p[1]))
		grid.add_entity(s)
		out.append(s)
	return out

static func _serialize_assignments() -> Dictionary:
	# JSON keys must be strings; coerce.
	var out: Dictionary = {}
	for sid in GameState.assignments.keys():
		out[str(sid)] = (GameState.assignments[sid] as Array).duplicate()
	return out

static func _deserialize_assignments(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[int(k)] = (d[k] as Array).duplicate()
	return out

static func _serialize_grid(g: Grid) -> Dictionary:
	var tiles: Array = []
	for x in g.size.x:
		for y in g.size.y:
			var t: Tile = g.get_tile(Vector2i(x, y))
			if t == null:
				continue
			tiles.append({
				"x": x, "y": y,
				"terrain_id": t.terrain_id,
				"supplies": t.supplies,
				"searched": t.searched,
				"explored": t.explored,
				"has_base": t.has_base,
			})
	return {"size": [g.size.x, g.size.y], "tiles": tiles}

static func _deserialize_grid(d: Dictionary) -> Grid:
	var sz: Array = d.get("size", [14, 14])
	var g: Grid = Grid.new(Vector2i(int(sz[0]), int(sz[1])))
	# Init with plains so all tile slots are populated.
	for x in g.size.x:
		for y in g.size.y:
			g.set_tile(Vector2i(x, y), Tile.new(Vector2i(x, y), "plains"))
	for raw in d.get("tiles", []):
		var td: Dictionary = raw
		var p := Vector2i(int(td.get("x", 0)), int(td.get("y", 0)))
		var t: Tile = Tile.new(p, String(td.get("terrain_id", "plains")))
		t.supplies = int(td.get("supplies", 0))
		t.searched = bool(td.get("searched", false))
		t.explored = bool(td.get("explored", false))
		t.has_base = bool(td.get("has_base", false))
		g.set_tile(p, t)
	return g

static func _serialize_entities(g: Grid) -> Array:
	var out: Array = []
	for e in g.entities:
		if e is Survivor:
			continue  # serialized via _serialize_party
		if e is ZombieUnit:
			out.append({
				"kind": "zombie",
				"id": e.id,
				"unit_id": e.unit_id,
				"hp": e.hp,
				"size": e.size,
				"pos": [e.pos.x, e.pos.y],
			})
		elif e is Npc:
			out.append({
				"kind": "npc",
				"id": e.id,
				"display_name": e.display_name,
				"faction_id": e.faction_id,
				"revealed": e.revealed,
				"hostile_intent": e.hostile_intent,
				"hp": e.hp,
				"pos": [e.pos.x, e.pos.y],
			})
	return out

static func _deserialize_entities(arr: Array, grid: Grid) -> Array:
	var out: Array = []
	for raw in arr:
		var d: Dictionary = raw
		match String(d.get("kind", "")):
			"zombie":
				var z: ZombieUnit = ZombieUnit.make(String(d.get("unit_id", "single")))
				z.id = int(d.get("id", z.id))
				z.hp = int(d.get("hp", z.hp))
				z.size = int(d.get("size", z.size))
				var p: Array = d.get("pos", [0, 0])
				z.pos = Vector2i(int(p[0]), int(p[1]))
				grid.add_entity(z)
				out.append(z)
			"npc":
				var n: Npc = Npc.new()
				n.id = int(d.get("id", n.id))
				n.display_name = String(d.get("display_name", n.display_name))
				n.faction_id = String(d.get("faction_id", "lone_wolf"))
				n.revealed = bool(d.get("revealed", false))
				n.hostile_intent = bool(d.get("hostile_intent", false))
				n.hp = int(d.get("hp", n.hp))
				var p2: Array = d.get("pos", [0, 0])
				n.pos = Vector2i(int(p2[0]), int(p2[1]))
				grid.add_entity(n)
				out.append(n)
	return out
