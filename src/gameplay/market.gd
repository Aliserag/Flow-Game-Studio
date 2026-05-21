class_name Market
extends RefCounted
## Generates rotating stock for the market node.
## Sells gear at sticker price. Buys back player gear at 50%.


const STOCK_SIZE: int = 4


static func roll_stock(registry: Node, rng: Node, tier: int = 1) -> Array:
	## Returns an Array of dicts: [{"gear_id": str, "price": int}, ...]
	var ids: Array[String] = registry.gear_ids()
	var pool: Array[String] = []
	for gid in ids:
		var g: Dictionary = registry.get_gear(gid)
		var t: String = String(g.get("tier", "common"))
		if tier == 1 and t == "common":
			pool.append(gid)
		elif tier == 2 and t in ["common", "uncommon"]:
			pool.append(gid)
		elif tier >= 3 and t in ["common", "uncommon", "rare"]:
			pool.append(gid)
	if pool.is_empty():
		pool = ids.duplicate()
	rng.shuffle(pool)
	var picked: Array = []
	for i in min(STOCK_SIZE, pool.size()):
		var gid: String = pool[i]
		var g: Dictionary = registry.get_gear(gid)
		picked.append({
			"gear_id": gid,
			"name": g.get("name", gid),
			"price": int(g.get("price", 10)),
			"slot": g.get("slot", "weapon"),
			"tier": g.get("tier", "common"),
		})
	return picked


static func buy(registry: Node, run_state: Node, stock_entry: Dictionary, target_orc) -> bool:
	## Buy a gear piece and equip it to target_orc, replacing whatever's in that slot.
	var price: int = int(stock_entry.get("price", 0))
	if not run_state.can_afford(price):
		return false
	var gid: String = String(stock_entry.get("gear_id", ""))
	var gear: Dictionary = registry.get_gear(gid)
	if gear.is_empty():
		return false
	if not run_state.spend_gold(price):
		return false
	var slot: String = String(gear.get("slot", "weapon"))
	target_orc.equipped_gear[slot] = gid
	return true


static func sell(run_state: Node, registry: Node, orc, slot: String) -> int:
	## Sell whatever orc has in slot at 50% of base price.
	if not orc.equipped_gear.has(slot):
		return 0
	var gid: String = String(orc.equipped_gear[slot])
	var g: Dictionary = registry.get_gear(gid)
	var sell_price: int = int(g.get("price", 0)) / 2
	orc.equipped_gear.erase(slot)
	run_state.add_gold(sell_price)
	return sell_price
