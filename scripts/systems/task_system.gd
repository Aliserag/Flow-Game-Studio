class_name TaskSystem
extends RefCounted

# Daily task assignments for party members. Tasks fire each turn before AI tick.
# Outcomes scale with the relevant stat (strength/smarts/stealth).
#
# Tasks (IDs map to Survivor.daily_task):
#   - "guard"        — defensive bonus this day; strength-scaled
#   - "scavenge"     — chance to add 1 item to stash; stealth-scaled
#   - "heal"         — heal another party member by 1-2 hp; smarts-scaled
#   - "build_assist" — accelerate active build by 1 day; strength + smarts
#   - "forage"       — chance to add food; smarts-scaled
#   - ""             — no task assigned (default)

const TASK_IDS: Array = ["guard", "scavenge", "heal", "build_assist", "forage"]

static func task_label(task_id: String) -> String:
	match task_id:
		"guard": return "Guard"
		"scavenge": return "Scavenge"
		"heal": return "Heal"
		"build_assist": return "Build assist"
		"forage": return "Forage"
		_: return "Idle"

static func assign_task(survivor_id: int, task_id: String) -> bool:
	if task_id != "" and not TASK_IDS.has(task_id):
		return false
	for s in GameState.party:
		if s.id == survivor_id:
			s.daily_task = task_id
			EventBus.party_changed.emit()
			return true
	return false

static func execute_daily_tasks(grid: Grid) -> void:
	# Snapshot to avoid mutation during iteration.
	for s in GameState.party.duplicate():
		if not (s is Survivor):
			continue
		if s.daily_task == "":
			continue
		match s.daily_task:
			"guard":
				_do_guard(s)
			"scavenge":
				_do_scavenge(s, grid)
			"heal":
				_do_heal(s)
			"build_assist":
				_do_build_assist(s)
			"forage":
				_do_forage(s)
	# Reset task assignments after they fire (must re-assign daily).
	for s in GameState.party:
		s.daily_task = ""

static func _do_guard(s: Survivor) -> void:
	# Guard provides a temporary defense buff for the next combat (this day).
	GameState._defense_temp_bonus = max(GameState._defense_temp_bonus, s.strength)
	GameState._defense_temp_turns = max(GameState._defense_temp_turns, 1)

static func _do_scavenge(s: Survivor, grid: Grid) -> void:
	# Chance to find a small item near the base/lead. Higher stealth → higher chance.
	var chance: float = 0.2 + 0.1 * s.stealth
	if not RNG.chance(chance):
		return
	var item: String = String(RNG.pick(["scrap", "wood", "bandage", "canned_food"]))
	GameState.add_to_inventory(item, 1)
	EventBus.log_info("%s scavenged a %s." % [s.display_name, item])

static func _do_heal(s: Survivor) -> void:
	# Heal a random injured ally (not self) by 1-2 hp, scaled by smarts.
	var injured: Array = []
	for other in GameState.party:
		if other == s: continue
		if other.hp < other.max_hp:
			injured.append(other)
	if injured.is_empty():
		return
	var target = RNG.pick(injured)
	var amount: int = clampi(1 + int(s.smarts / 3.0), 1, 3)
	target.hp = min(target.max_hp, target.hp + amount)
	EventBus.log_good("%s tends to %s (+%d HP)." % [s.display_name, target.display_name, amount])
	EventBus.hud_refresh_requested.emit()

static func _do_build_assist(s: Survivor) -> void:
	# Accelerate active build by 1 day; high strength+smarts may shave another day.
	if GameState.building_enhancement_id == "":
		return
	GameState.building_days_left = max(0, GameState.building_days_left - 1)
	if s.strength + s.smarts >= 8 and RNG.chance(0.5):
		GameState.building_days_left = max(0, GameState.building_days_left - 1)
		EventBus.log_good("%s pushes the build forward another day." % s.display_name)
	else:
		EventBus.log_info("%s assists with construction." % s.display_name)

static func _do_forage(s: Survivor) -> void:
	# Chance to add canned_food + water_bottle.
	var chance: float = 0.3 + 0.1 * s.smarts
	if not RNG.chance(chance):
		return
	GameState.add_to_inventory("canned_food", 1)
	if RNG.chance(0.5):
		GameState.add_to_inventory("water_bottle", 1)
	EventBus.log_info("%s forages for food." % s.display_name)
