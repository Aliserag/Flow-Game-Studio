class_name Npc
extends Entity

# A roaming stranger encountered on the map. Faction is HIDDEN until interacted with.

var faction_id: String = "lone_wolf"
var revealed: bool = false
var hostile_intent: bool = false   # for raiders/cannibals; only known after parley

func _init() -> void:
	super()
	kind = Kind.NPC
	max_hp = 6
	hp = 6
	attack = 2
	glyph = "?"
	color = Color("#c0a878")
	display_name = Survivor.random_name()

func is_hostile() -> bool:
	# Hidden hostility — looks neutral on the map until parley.
	return false

func display_priority() -> int:
	return 60

func describe() -> String:
	if revealed:
		return "%s — %s" % [display_name, DataLoader.factions.get(faction_id, {}).get("name", faction_id)]
	return "%s (stranger)" % display_name

static func spawn_random() -> Npc:
	var n := Npc.new()
	var faction_keys: Array = DataLoader.factions.keys()
	var weights: Array = []
	for k in faction_keys:
		weights.append(int(DataLoader.factions[k].get("weight", 1)))
	n.faction_id = String(RNG.weighted_pick(faction_keys, weights))
	n.hostile_intent = String(DataLoader.factions[n.faction_id].get("alignment", "neutral")) == "hostile"
	return n

func choose_move(grid: Grid) -> Vector2i:
	# Faction-aware movement strategy lives in NpcBehavior.
	return NpcBehavior.step(self, grid)
