class_name Orc
extends RefCounted
## A single named orc. Hero or grunt.
## Persistent across battles in a campaign. Permanently destroyed on death.

const NAME_FIRST: Array[String] = [
	"Grog", "Skarra", "Brak", "Gor", "Murza", "Hak",
	"Rok", "Zug", "Mok", "Ulgrim", "Nazga", "Bolg",
	"Throk", "Vrak", "Skull", "Thresh", "Khar", "Drog",
]

const NAME_SUFFIX: Array[String] = [
	"the Cleaver", "the Slow", "Bonebreaker", "the Quick",
	"Three-Tooth", "Iron-Eye", "the Patient", "Twice-Cut",
	"Skullbearer", "the Loud", "the Quiet", "Long-Arm",
	"the Mournful", "the Hungry", "Stoneface", "the Last",
]

var id: String
var name: String
var archetype_id: String
var is_hero: bool
var level: int = 1
var xp: int = 0
var unspent_stat_points: int = 0

# Derived runtime state
var current_hp: int = 0
var max_hp: int = 0
var attack: int = 0
var defense: int = 0
var speed: int = 0

# Persistent identity
var traits: Array[String] = []
var equipped_gear: Dictionary = {}  # slot -> gear_id

# Career stats
var kills: int = 0
var battles_fought: int = 0
var scars: int = 0
var cause_of_death: String = ""
var killer_name: String = ""

# Allocation tracking (per Brawn/Cunning/Hide allocations made)
var allocated_brawn: int = 0
var allocated_cunning: int = 0
var allocated_hide: int = 0


static func from_archetype(archetype: Dictionary) -> Orc:
	## Note: caller should set .name after via Orc.roll_name() (which uses the Rng autoload).
	var o := Orc.new()
	o.archetype_id = archetype.get("id", "unknown")
	o.is_hero = archetype.get("kind", "grunt") == "hero"
	var base: Dictionary = archetype.get("base_stats", {})
	o.max_hp = base.get("max_hp", 30)
	o.current_hp = o.max_hp
	o.attack = base.get("attack", 5)
	o.defense = base.get("defense", 2)
	o.speed = base.get("speed", 4)
	var starting_traits: Array = archetype.get("starting_traits", [])
	o.traits.clear()
	for t in starting_traits:
		o.traits.append(String(t))
	o.id = "%s_%d_%d" % [o.archetype_id, Time.get_ticks_msec(), randi() % 100000]
	o.name = "%s of %s" % [archetype.get("name", "Orc"), archetype.get("id", "warband")]
	return o


static func roll_name_with(rng_node: Node) -> String:
	## Pass the Rng autoload (or anything with .pick(arr)) to roll a deterministic name.
	var first: String = rng_node.pick(NAME_FIRST)
	var suffix: String = rng_node.pick(NAME_SUFFIX)
	return "%s %s" % [first, suffix]


func is_alive() -> bool:
	return current_hp > 0


func apply_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var taken: int = min(current_hp, amount)
	current_hp -= taken
	return taken


func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var healed: int = min(max_hp - current_hp, amount)
	current_hp += healed
	return healed


func full_heal() -> void:
	current_hp = max_hp


## Compute effective stats: base + level allocations + trait modifiers + gear modifiers.
## team_attack_bonus is added externally (e.g., from a leader's team_modifiers).
func effective_stats(registry: Node, team_attack_bonus: int = 0) -> Dictionary:
	var atk := attack + allocated_brawn + team_attack_bonus
	var def := defense + allocated_hide
	var spd := speed + allocated_cunning
	var hp := max_hp
	# Trait modifiers (additive only — per ADR-002)
	for trait_id in traits:
		var t: Dictionary = registry.get_trait(trait_id)
		var mods: Dictionary = t.get("modifiers", {})
		atk += int(mods.get("attack", 0))
		def += int(mods.get("defense", 0))
		spd += int(mods.get("speed", 0))
		hp += int(mods.get("max_hp", 0))
	# Gear modifiers
	for slot in equipped_gear:
		var g: Dictionary = registry.get_gear(equipped_gear[slot])
		var gm: Dictionary = g.get("modifiers", {})
		atk += int(gm.get("attack", 0))
		def += int(gm.get("defense", 0))
		spd += int(gm.get("speed", 0))
		hp += int(gm.get("max_hp", 0))
	# Floor at 0
	return {
		"attack": max(0, atk),
		"defense": max(0, def),
		"speed": max(1, spd),
		"max_hp": max(1, hp),
	}


func add_xp(amount: int, xp_curve: Array) -> int:
	## Returns number of levels gained.
	xp += max(0, amount)
	var gained := 0
	while level < xp_curve.size() and xp >= int(xp_curve[level]):
		level += 1
		gained += 1
	return gained


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"archetype_id": archetype_id,
		"is_hero": is_hero,
		"level": level,
		"xp": xp,
		"unspent_stat_points": unspent_stat_points,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"traits": traits,
		"equipped_gear": equipped_gear,
		"kills": kills,
		"battles_fought": battles_fought,
		"scars": scars,
		"cause_of_death": cause_of_death,
		"killer_name": killer_name,
		"allocated_brawn": allocated_brawn,
		"allocated_cunning": allocated_cunning,
		"allocated_hide": allocated_hide,
	}
