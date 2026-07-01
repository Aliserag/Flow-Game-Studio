class_name Survivor
extends Entity

# Player and recruited NPCs become Survivors.

var faction_id: String = "lone_wolf"     # hidden from player initially for recruits
var faction_revealed: bool = false
var betrayal_chance: float = 0.0
var injured: bool = false
var infected: bool = false               # set when bitten — turns later
var is_lead: bool = false

# Per-survivor stats (M2.1). Range 1-5.
var strength: int = 1   # melee, build assist, guard
var smarts: int = 1     # heal, event outcomes
var stealth: int = 1    # scavenge yield, escape

# Daily task assignment (M2.2). Cleared at end of each day.
var daily_task: String = ""

const FIRST_NAMES := [
	"Ash", "Wren", "Mateo", "Iris", "Jonas", "Maeve", "Theo", "Ruby",
	"Soren", "Hana", "Felix", "Nia", "Kai", "Iona", "Beck", "Vera",
	"Otis", "Lena", "Tovi", "Sage"
]
const LAST_NAMES := [
	"Cole", "Reyes", "Park", "Vega", "Holm", "Carter", "Iyer", "Nash",
	"Ortiz", "Kade", "Black", "Singh", "Frost", "Ward", "Huang", "Reed"
]

func _init() -> void:
	super()
	kind = Kind.SURVIVOR
	max_hp = 10
	hp = 10
	attack = 2
	glyph = "@"
	color = Color("#e0d6a8")

func is_player_party() -> bool:
	return true

func display_priority() -> int:
	return 100 if is_lead else 80

func describe() -> String:
	var parts: Array = [display_name]
	if faction_revealed:
		var fac: Dictionary = DataLoader.factions.get(faction_id, {})
		parts.append("(%s)" % fac.get("name", faction_id))
	parts.append("HP %d/%d" % [hp, max_hp])
	if infected:
		parts.append("[INFECTED]")
	if injured:
		parts.append("[injured]")
	return " ".join(parts)

static func make_random_recruit() -> Survivor:
	var s := Survivor.new()
	s.display_name = random_name()
	s.max_hp = RNG.randi_range_inclusive(6, 10)
	s.hp = s.max_hp
	s.attack = RNG.randi_range_inclusive(1, 3)
	# Stats roll 1-4 for recruits; lead bumps one up to 5.
	s.strength = RNG.randi_range_inclusive(1, 4)
	s.smarts = RNG.randi_range_inclusive(1, 4)
	s.stealth = RNG.randi_range_inclusive(1, 4)
	# Pick faction by weight.
	var faction_keys: Array = DataLoader.factions.keys()
	var weights: Array = []
	for k in faction_keys:
		weights.append(int(DataLoader.factions[k].get("weight", 1)))
	s.faction_id = String(RNG.weighted_pick(faction_keys, weights))
	s.betrayal_chance = float(DataLoader.factions[s.faction_id].get("betrayal_chance", 0.0))
	return s

static func make_lead() -> Survivor:
	var s := Survivor.new()
	s.display_name = random_name()
	s.is_lead = true
	s.faction_id = "lone_wolf"
	s.faction_revealed = true
	s.max_hp = 10
	s.hp = 10
	s.attack = 3
	# Lead has one elevated stat at 5; others rolled 2-4.
	s.strength = RNG.randi_range_inclusive(2, 4)
	s.smarts = RNG.randi_range_inclusive(2, 4)
	s.stealth = RNG.randi_range_inclusive(2, 4)
	var stat_picks: Array = ["strength", "smarts", "stealth"]
	var top: String = String(RNG.pick(stat_picks))
	s.set(top, 5)
	return s

static func random_name() -> String:
	return "%s %s" % [RNG.pick(FIRST_NAMES), RNG.pick(LAST_NAMES)]
