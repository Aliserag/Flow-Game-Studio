class_name SwarmSystem
extends RefCounted

# Frostpunk-style: warning shows N days before a swarm/horde arrives.
# Megahorde unlocks after MEGAHORDE_UNLOCK_RANGE days of survival,
# then arrives some MEGAHORDE_GRACE days later. Surviving the megahorde wins.

const SWARM_UNLOCK_DAY := 8         # earliest swarm warning
const SWARM_INTERVAL_MIN := 6
const SWARM_INTERVAL_MAX := 10
const SWARM_WARN_DAYS_MIN := 2
const SWARM_WARN_DAYS_MAX := 4

const MEGAHORDE_UNLOCK_DAY_MIN := 20
const MEGAHORDE_UNLOCK_DAY_MAX := 50
const MEGAHORDE_GRACE_MIN := 5
const MEGAHORDE_GRACE_MAX := 8

static func on_day_advanced(day: int, grid: Grid) -> void:
	# Tick swarm countdown.
	if not GameState.swarm_pending.is_empty():
		GameState.swarm_pending["eta_days"] = int(GameState.swarm_pending["eta_days"]) - 1
		var eta: int = int(GameState.swarm_pending["eta_days"])
		if eta <= 0:
			_trigger_swarm(grid, String(GameState.swarm_pending["kind"]))
			GameState.swarm_pending.clear()
		else:
			EventBus.swarm_warning.emit(eta, String(GameState.swarm_pending["kind"]))

	# Tick megahorde countdown.
	if GameState.megahorde_unlocked:
		GameState.megahorde_eta -= 1
		if GameState.megahorde_eta <= 0:
			_trigger_megahorde(grid)
		else:
			EventBus.megahorde_unlocked.emit(GameState.megahorde_eta)

	# Try to schedule next swarm.
	if day >= SWARM_UNLOCK_DAY and GameState.swarm_pending.is_empty() and not GameState.megahorde_unlocked:
		if RNG.chance(0.18 + 0.01 * day):
			_schedule_swarm()

	# Try to unlock the megahorde.
	if not GameState.megahorde_unlocked:
		var unlock_day: int = GameState._megahorde_unlock_day
		if unlock_day == 0:
			unlock_day = DifficultyConfig.megahorde_unlock_day_for_map_size(GameState.map_size)
			GameState._megahorde_unlock_day = unlock_day
		if day >= unlock_day:
			GameState.megahorde_unlocked = true
			GameState.megahorde_eta = RNG.randi_range_inclusive(MEGAHORDE_GRACE_MIN, MEGAHORDE_GRACE_MAX)
			EventBus.megahorde_unlocked.emit(GameState.megahorde_eta)
			EventBus.log_danger("MEGAHORDE detected on the horizon. ETA %d days." % GameState.megahorde_eta)

static func _schedule_swarm() -> void:
	var eta: int = RNG.randi_range_inclusive(SWARM_WARN_DAYS_MIN, SWARM_WARN_DAYS_MAX)
	# Late swarms can be hordes upgraded to swarm-tier.
	var kind: String = "swarm" if RNG.chance(0.4) else "horde"
	GameState.swarm_pending = {"kind": kind, "eta_days": eta}
	EventBus.swarm_warning.emit(eta, kind)
	EventBus.log_warn("Scouts report: a %s approaches. ETA %d days." % [kind.capitalize(), eta])

static func _trigger_swarm(grid: Grid, kind: String) -> void:
	# Spawn at edge nearest the player so the threat actually matters.
	var edge: Vector2i = _edge_near_player(grid)
	var z: ZombieUnit = ZombieUnit.make(kind)
	z.pos = edge
	grid.add_entity(z)
	EventBus.swarm_arrived.emit(kind)
	EventBus.log_danger("A %s has arrived." % z.display_name)

static func _trigger_megahorde(grid: Grid) -> void:
	var edge: Vector2i = _edge_near_player(grid)
	var mh: ZombieUnit = ZombieUnit.make("megahorde")
	mh.pos = edge
	grid.add_entity(mh)
	EventBus.megahorde_arrived.emit()
	EventBus.log_danger("THE MEGAHORDE HAS ARRIVED.")

static func _edge_near_player(grid: Grid) -> Vector2i:
	if GameState.party.is_empty():
		return grid.random_edge_position()
	var pp: Vector2i = GameState.party[0].pos
	# Pick the edge axis-distance is smallest from player.
	var candidates: Array = [
		Vector2i(pp.x, 0),
		Vector2i(pp.x, grid.size.y - 1),
		Vector2i(0, pp.y),
		Vector2i(grid.size.x - 1, pp.y)
	]
	candidates.shuffle()
	return candidates[0]
