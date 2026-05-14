class_name TavernRecruit
extends RefCounted
## Generates a fresh pool of named candidate orcs at each tavern visit.
## Candidates are unique to this visit — passing means they're gone forever (G0: cleared on Enter Battle).

const DEFAULT_TIER: int = 1


static func roll_candidates(registry: Node, rng: Node, count: int, tier: int = DEFAULT_TIER) -> Array:
	var out: Array = []
	var grunt_ids: Array[String] = registry.grunt_archetype_ids()
	if grunt_ids.is_empty():
		return out
	var econ: Dictionary = registry.get_economy()
	var price_ranges: Dictionary = econ.get("hire_price_range_per_tier", {})
	var range_for_tier: Array = price_ranges.get(str(tier), [25, 40])
	var low: int = int(range_for_tier[0])
	var high: int = int(range_for_tier[1])
	for i in count:
		var archetype_id: String = rng.pick(grunt_ids)
		var arch: Dictionary = registry.get_archetype(archetype_id)
		var orc: Orc = Orc.from_archetype(arch)
		orc.name = Orc.roll_name_with(rng)
		# Apply default gear
		var defaults: Array = arch.get("default_gear", [])
		for gid in defaults:
			var gear: Dictionary = registry.get_gear(String(gid))
			if not gear.is_empty():
				orc.equipped_gear[gear.get("slot", "weapon")] = gid
		# Compute price — base range + small per-trait surcharge
		var base_price: int = rng.roll_int(low, high)
		var price_meta: Dictionary = {
			"price": base_price,
		}
		out.append({"orc": orc, "price": base_price, "meta": price_meta})
	return out
