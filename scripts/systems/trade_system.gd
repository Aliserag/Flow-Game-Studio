class_name TradeSystem
extends RefCounted

# NPC trade. Each NPC has a procedurally-generated stock weighted by faction,
# and a price modifier based on faction alignment.
#
# Items have an implicit value derived from category + rarity:
#   common = 1, uncommon = 2, rare = 4
#   weapon/armor double; consumable/food = 1; material/ammo = 0.5x
# Modifier:
#   doctors / militia: 1.0  (fair)
#   lone_wolf / scavengers: 1.2 (savvy)
#   raiders / cannibals: 1.6 (extort)
#   cultists: 0.9 (don't care for material wealth)

const FACTION_MARKUP := {
	"doctors": 1.0,
	"militia": 1.0,
	"lone_wolf": 1.2,
	"scavengers": 1.2,
	"raiders": 1.6,
	"cannibals": 1.6,
	"cultists": 0.9,
}

static func generate_stock(npc: Npc) -> Dictionary:
	# Returns {item_id: count}. Stock varies by faction.
	var faction: String = npc.faction_id
	var stock: Dictionary = {}
	# 3-6 items.
	var n: int = RNG.randi_range_inclusive(3, 6)
	var pool: Array = _faction_pool(faction)
	if pool.is_empty():
		return stock
	for _i in n:
		var item_id: String = String(RNG.pick(pool))
		stock[item_id] = int(stock.get(item_id, 0)) + 1
	return stock

static func _faction_pool(faction: String) -> Array:
	# Filtered list of item IDs by faction taste.
	var allowed_categories: Array = ["food", "consumable", "material", "ammo", "weapon", "armor"]
	match faction:
		"doctors": allowed_categories = ["consumable", "food", "ammo"]
		"militia": allowed_categories = ["weapon", "ammo", "armor", "food"]
		"raiders": allowed_categories = ["weapon", "ammo", "consumable"]
		"scavengers": allowed_categories = ["material", "weapon", "ammo", "food", "consumable"]
		"cultists": allowed_categories = ["consumable", "material"]
		"cannibals": allowed_categories = ["food", "weapon", "consumable"]
	var out: Array = []
	for item_id in DataLoader.items.keys():
		var item: Dictionary = DataLoader.items[item_id]
		if item.get("category", "") in allowed_categories:
			out.append(item_id)
	return out

static func base_value(item_id: String) -> int:
	var item: Dictionary = DataLoader.items.get(item_id, {})
	var rarity: String = String(item.get("rarity", "common"))
	var v: int = 1
	match rarity:
		"common": v = 1
		"uncommon": v = 2
		"rare": v = 4
	var category: String = String(item.get("category", ""))
	if category == "weapon" or category == "armor":
		v *= 2
	elif category == "material" or category == "ammo":
		# Half value, but at least 1.
		v = max(1, v / 2 if v > 1 else 1)
	return v

static func sell_price(item_id: String, npc: Npc) -> int:
	# Price the NPC charges you for this item.
	var v: int = base_value(item_id)
	var markup: float = float(FACTION_MARKUP.get(npc.faction_id, 1.2))
	return max(1, int(ceil(v * markup)))

static func buy_price(item_id: String, npc: Npc) -> int:
	# Price the NPC pays you for this item (always less than sell to make trades meaningful).
	var v: int = base_value(item_id)
	var markup: float = float(FACTION_MARKUP.get(npc.faction_id, 1.2))
	# Buy is at base value / markup.
	return max(1, int(floor(v / markup)))

# Currency proxy: scrap. Players trade scrap for goods or sell goods for scrap.
const CURRENCY := "scrap"

static func can_buy(item_id: String, npc: Npc) -> bool:
	return GameState.has_item(CURRENCY, sell_price(item_id, npc))

static func can_sell(item_id: String) -> bool:
	return GameState.has_item(item_id, 1)

static func execute_buy(item_id: String, npc: Npc, npc_stock: Dictionary) -> bool:
	if int(npc_stock.get(item_id, 0)) <= 0:
		return false
	var price: int = sell_price(item_id, npc)
	if not GameState.has_item(CURRENCY, price):
		return false
	GameState.remove_from_inventory(CURRENCY, price)
	GameState.add_to_inventory(item_id, 1)
	npc_stock[item_id] = int(npc_stock[item_id]) - 1
	if npc_stock[item_id] <= 0:
		npc_stock.erase(item_id)
	return true

static func execute_sell(item_id: String, npc: Npc, npc_stock: Dictionary) -> bool:
	if not GameState.has_item(item_id, 1):
		return false
	var price: int = buy_price(item_id, npc)
	GameState.remove_from_inventory(item_id, 1)
	GameState.add_to_inventory(CURRENCY, price)
	npc_stock[item_id] = int(npc_stock.get(item_id, 0)) + 1
	return true
