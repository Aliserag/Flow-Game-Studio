extends Node

# Top-level game state container. Holds the run, mode, and high-level status.

enum Mode { SOLO, SETTLED }
enum Phase { MENU, PLAYING, EVENT, GAME_OVER }
enum Difficulty { TOURIST, STANDARD, APOCALYPSE, PERMADEATH }

var difficulty: int = Difficulty.STANDARD

const MAX_HP := 10
const MAX_MORALE := 10

var mode: int = Mode.SOLO
var phase: int = Phase.MENU

var day: int = 1
var turns_today: int = 0
var TURNS_PER_DAY := 1   # one decision per day in solo mode; settled has multiple

# Player party — first entry is the lead survivor.
var party: Array = []
var inventory: Dictionary = {}  # item_id -> count (shared stash; per-character via assignments)
var assignments: Dictionary = {}  # survivor_id -> [item_id, ...] equipped/carried personally

# World references — set by Game scene.
var grid = null
var map_size: Vector2i = Vector2i(14, 14)

# Base/settlement data
var has_base: bool = false
var base_pos: Vector2i = Vector2i(-1, -1)
var base_terrain_id: String = ""
var base_defense_bonus: int = 0
var base_enhancements: Array = []  # built enhancement ids
var building_enhancement_id: String = ""
var building_days_left: int = 0
var morale: int = 7

# Threat / megahorde
var megahorde_unlocked: bool = false
var megahorde_eta: int = -1   # days until arrival once unlocked
var _megahorde_unlock_day: int = 0  # rolled once per run
var swarm_pending: Dictionary = {}  # {kind: String, eta_days: int} or empty
var noise_level: int = 0  # transient: spikes after gunfire, decays

# Tension / betrayal modifiers
var _betrayal_tension_bonus_turns: int = 0
# Temporary defense bonus (turns remaining + magnitude)
var _defense_temp_bonus: int = 0
var _defense_temp_turns: int = 0
# One-shot preparation bonus consumed at next swarm/megahorde combat
var _preparation_bonus_pending: int = 0

# Run-meta
var run_seed: int = 0
var knowledge: Array = []  # learned facts (cannibal_warning, immunity_exists, etc.)
var stats: Dictionary = {
	"zombies_killed": 0,
	"npcs_recruited": 0,
	"npcs_betrayed": 0,
	"days_survived": 0,
	"events_seen": 0
}

func reset_run(new_mode: int, seed_value: int = 0, difficulty_value: int = Difficulty.STANDARD,
		map_size_value: Vector2i = Vector2i(14, 14)) -> void:
	mode = new_mode
	phase = Phase.PLAYING
	difficulty = difficulty_value
	map_size = map_size_value
	day = 1
	turns_today = 0
	party.clear()
	inventory.clear()
	assignments.clear()
	grid = null
	has_base = false
	base_pos = Vector2i(-1, -1)
	base_terrain_id = ""
	base_defense_bonus = 0
	base_enhancements.clear()
	building_enhancement_id = ""
	building_days_left = 0
	morale = 7
	megahorde_unlocked = false
	megahorde_eta = -1
	_megahorde_unlock_day = 0
	swarm_pending.clear()
	noise_level = 0
	_betrayal_tension_bonus_turns = 0
	_defense_temp_bonus = 0
	_defense_temp_turns = 0
	_preparation_bonus_pending = 0
	knowledge.clear()
	stats = {
		"zombies_killed": 0,
		"npcs_recruited": 0,
		"npcs_betrayed": 0,
		"days_survived": 0,
		"events_seen": 0
	}
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	RNG.seed_run(run_seed)

func add_to_inventory(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	inventory[item_id] = inventory.get(item_id, 0) + count
	EventBus.supplies_changed.emit()

func remove_from_inventory(item_id: String, count: int = 1) -> bool:
	var have: int = int(inventory.get(item_id, 0))
	if have < count:
		return false
	inventory[item_id] = have - count
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	EventBus.supplies_changed.emit()
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= count

func adjust_morale(delta: int) -> void:
	morale = clamp(morale + delta, 0, MAX_MORALE)
	if morale <= 0:
		EventBus.log_danger("Morale collapses. Your group falls apart.")
		end_run(false, "Your survivors lost hope and scattered.")
	EventBus.hud_refresh_requested.emit()

func adjust_lead_hp(delta: int) -> void:
	if party.is_empty():
		return
	var lead = party[0]
	lead.hp = clamp(lead.hp + delta, 0, MAX_HP)
	if lead.hp <= 0:
		EventBus.log_danger("%s is dead." % lead.display_name)
		end_run(false, "Your lead survivor died.")
	EventBus.hud_refresh_requested.emit()

func end_run(victory: bool, summary: String) -> void:
	phase = Phase.GAME_OVER
	stats["days_survived"] = day
	EventBus.game_over.emit(victory, summary)
