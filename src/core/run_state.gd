extends Node
## Single source of truth for the active campaign.
## All state mutations go through this. Read-only access elsewhere.

signal gold_changed(new_gold: int)
signal roster_changed()
signal hero_changed()
signal phase_changed(new_phase: int)
signal orc_died(orc_dict: Dictionary, killer_name: String)
signal candidates_changed()
signal run_started()
signal run_ended(victory: bool)
signal battle_won(rewards: Dictionary)
signal battle_lost()
signal xp_awarded(orc_id: String, amount: int, levels_gained: int)

enum Phase { TITLE, TAVERN, MAP, SCOUT, BATTLE_PREP, BATTLE, RESOLUTION, MARKET, MEMORIAL, GAME_OVER, VICTORY }

signal map_changed()
signal market_stock_changed()

var phase: int = Phase.TITLE
var run_seed: int = 0
var run_active: bool = false

var hero: Orc = null
var roster: Array[Orc] = []         # Living grunts only (excludes hero)
var gravestone: Array[Dictionary] = []  # Dicts of fallen orcs (snapshot at death)
var candidates: Array[Orc] = []     # Currently rolled tavern candidates
var candidate_prices: Dictionary = {}  # orc.id -> int

# G1: campaign map state
var current_biome_id: String = ""
var campaign_map: Dictionary = {}   # Dict from CampaignMap.generate()
var market_stock: Array = []        # Array of stock entries

var gold: int = 0
var battles_completed: int = 0
var battles_won: int = 0

var _economy: Dictionary = {}


func _ready() -> void:
	# Will be populated when run starts; ItemRegistry loads first via autoload order.
	pass


func start_new_run(seed_value: int = -1) -> void:
	# Reset everything
	hero = null
	roster.clear()
	gravestone.clear()
	candidates.clear()
	candidate_prices.clear()
	current_biome_id = ""
	campaign_map = {}
	market_stock = []
	battles_completed = 0
	battles_won = 0
	run_active = true
	# Seed
	if seed_value < 0:
		run_seed = Time.get_unix_time_from_system()
	else:
		run_seed = seed_value
	Rng.set_seed(run_seed)
	# Load economy
	_economy = ItemRegistry.get_economy()
	gold = int(_economy.get("starting_gold", 60))
	# Spawn hero
	var hero_ids: Array[String] = ItemRegistry.hero_archetype_ids()
	if hero_ids.is_empty():
		Console.error("No hero archetype defined", "run_state")
		return
	var hero_arch: Dictionary = ItemRegistry.get_archetype(hero_ids[0])
	hero = Orc.from_archetype(hero_arch)
	hero.name = Orc.roll_name_with(Rng)
	_apply_default_gear(hero, hero_arch)
	# Spawn starting roster (free, no gold cost)
	var starting_size: int = int(_economy.get("starting_roster_size", 2))
	var grunt_ids: Array[String] = ItemRegistry.grunt_archetype_ids()
	for i in starting_size:
		if grunt_ids.is_empty():
			break
		var pick: String = Rng.pick(grunt_ids)
		var arch: Dictionary = ItemRegistry.get_archetype(pick)
		var g: Orc = Orc.from_archetype(arch)
		g.name = Orc.roll_name_with(Rng)
		_apply_default_gear(g, arch)
		roster.append(g)
	Console.info("Run started. Seed=%d, hero=%s, roster=%d" % [run_seed, hero.name, roster.size()], "run_state")
	set_phase(Phase.TAVERN)
	emit_signal("run_started")
	emit_signal("hero_changed")
	emit_signal("roster_changed")
	emit_signal("gold_changed", gold)


func end_run(victory: bool) -> void:
	run_active = false
	set_phase(Phase.GAME_OVER)
	Console.info("Run ended. Victory=%s" % [str(victory)], "run_state")
	emit_signal("run_ended", victory)


func set_phase(p: int) -> void:
	if phase == p:
		return
	phase = p
	emit_signal("phase_changed", p)


func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	emit_signal("gold_changed", gold)


func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true


func can_afford(amount: int) -> bool:
	return gold >= max(0, amount)


func set_candidates(orcs: Array[Orc], prices: Array[int]) -> void:
	candidates = orcs
	candidate_prices.clear()
	for i in orcs.size():
		var p: int = prices[i] if i < prices.size() else 0
		candidate_prices[orcs[i].id] = p
	emit_signal("candidates_changed")


func clear_candidates() -> void:
	candidates.clear()
	candidate_prices.clear()
	emit_signal("candidates_changed")


func price_for(orc: Orc) -> int:
	return int(candidate_prices.get(orc.id, -1))


func hire_candidate(candidate: Orc) -> bool:
	if not candidates.has(candidate):
		Console.warn("Tried to hire non-candidate orc", "run_state")
		return false
	if roster.size() >= int(_economy.get("max_roster_size", 6)) - 1:
		# -1 reserves a slot for the hero in the max_roster_size count
		Console.info("Roster full; cannot hire %s" % candidate.name, "run_state")
		return false
	var price: int = int(candidate_prices.get(candidate.id, -1))
	if price < 0:
		Console.warn("No price for candidate %s" % candidate.name, "run_state")
		return false
	if not spend_gold(price):
		return false
	candidates.erase(candidate)
	candidate_prices.erase(candidate.id)
	roster.append(candidate)
	Console.info("Hired %s for %d gold" % [candidate.name, price], "run_state")
	emit_signal("candidates_changed")
	emit_signal("roster_changed")
	return true


func record_orc_death(orc: Orc, killer_name: String) -> void:
	orc.cause_of_death = "battle"
	orc.killer_name = killer_name
	gravestone.append(orc.to_dict())
	if orc == hero:
		Console.info("HERO DIED: %s. Run ending." % orc.name, "run_state")
		emit_signal("orc_died", orc.to_dict(), killer_name)
		end_run(false)
		return
	roster.erase(orc)
	Console.info("Grunt died: %s (by %s)" % [orc.name, killer_name], "run_state")
	emit_signal("orc_died", orc.to_dict(), killer_name)
	emit_signal("roster_changed")


func award_xp_to_warband(amount: int, kill_giver: Orc = null) -> void:
	var curve: Array = _economy.get("xp_to_level", [])
	for orc in get_all_living_orcs():
		var awarded := amount
		if kill_giver != null and orc == kill_giver:
			awarded += int(_economy.get("xp_per_kill", 5))
		var levels: int = orc.add_xp(awarded, curve)
		if levels > 0:
			orc.unspent_stat_points += levels * int(_economy.get("stat_points_per_level", 2))
		emit_signal("xp_awarded", orc.id, awarded, levels)


func get_all_living_orcs() -> Array[Orc]:
	var all: Array[Orc] = []
	if hero != null and hero.is_alive():
		all.append(hero)
	for o in roster:
		if o.is_alive():
			all.append(o)
	return all


func full_heal_warband() -> void:
	if hero != null:
		hero.full_heal()
	for o in roster:
		o.full_heal()


func roster_count() -> int:
	## Count includes hero.
	return roster.size() + (1 if hero != null else 0)


func gravestone_count() -> int:
	return gravestone.size()


func economy() -> Dictionary:
	return _economy


func _apply_default_gear(orc: Orc, archetype: Dictionary) -> void:
	var defaults: Array = archetype.get("default_gear", [])
	for gid in defaults:
		var gear: Dictionary = ItemRegistry.get_gear(String(gid))
		if gear.is_empty():
			continue
		orc.equipped_gear[gear.get("slot", "weapon")] = gid


func to_snapshot() -> Dictionary:
	## Used by SaveSystem to persist state.
	var roster_arr: Array = []
	for o in roster:
		roster_arr.append(o.to_dict())
	return {
		"phase": phase,
		"run_seed": run_seed,
		"run_active": run_active,
		"hero": hero.to_dict() if hero != null else {},
		"roster": roster_arr,
		"gravestone": gravestone.duplicate(true),
		"gold": gold,
		"battles_completed": battles_completed,
		"battles_won": battles_won,
	}
