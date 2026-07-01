class_name InventorySystem
extends RefCounted

# Per-character item assignments. Items live in shared GameState.inventory;
# assignments declare which characters carry which items for stat bonuses.

static func assign(survivor_id: int, item_id: String) -> bool:
	if not GameState.has_item(item_id, 1):
		return false
	if not GameState.assignments.has(survivor_id):
		GameState.assignments[survivor_id] = []
	GameState.assignments[survivor_id].append(item_id)
	GameState.remove_from_inventory(item_id, 1)
	EventBus.party_changed.emit()
	return true

static func unassign(survivor_id: int, item_id: String) -> bool:
	if not GameState.assignments.has(survivor_id):
		return false
	var lst: Array = GameState.assignments[survivor_id]
	if not lst.has(item_id):
		return false
	lst.erase(item_id)
	GameState.add_to_inventory(item_id, 1)
	EventBus.party_changed.emit()
	return true

static func use_consumable(survivor_id: int, item_id: String) -> Dictionary:
	if not GameState.has_item(item_id, 1):
		return {"ok": false, "msg": "None left."}
	var item: Dictionary = DataLoader.items.get(item_id, {})
	if item.get("category", "") != "consumable" and item.get("category", "") != "food":
		return {"ok": false, "msg": "Not consumable."}
	GameState.remove_from_inventory(item_id, 1)
	var target = null
	for s in GameState.party:
		if s.id == survivor_id:
			target = s
			break
	if target == null:
		return {"ok": false, "msg": "No such survivor."}
	var msg := ""
	if item.has("heal"):
		var amt: int = int(item["heal"])
		target.hp = min(target.max_hp, target.hp + amt)
		msg = "%s heals %d HP." % [target.display_name, amt]
	if item.get("cure_infection", false) and target.has_method("set"):
		if target.infected:
			target.infected = false
			msg = "%s — infection cured." % target.display_name
	if item.has("nutrition"):
		GameState.adjust_morale(1)
		msg = "%s eats %s." % [target.display_name, item.get("name", item_id)]
	EventBus.hud_refresh_requested.emit()
	return {"ok": true, "msg": msg}

static func scavenge_tile(grid: Grid) -> Dictionary:
	if GameState.party.is_empty(): return {"ok": false, "msg": "No party."}
	var lead = GameState.party[0]
	var t: Tile = grid.get_tile(lead.pos)
	if t == null: return {"ok": false, "msg": "No tile."}
	if t.searched:
		return {"ok": false, "msg": "Already searched here."}
	t.searched = true
	var found: Dictionary = {}
	var rolls: int = max(1, t.supplies)
	for _i in rolls:
		var item_id: String = _roll_loot(t.terrain_id)
		if item_id == "":
			continue
		found[item_id] = int(found.get(item_id, 0)) + 1
		GameState.add_to_inventory(item_id, 1)
	# Scavenging makes noise.
	GameState.noise_level = max(GameState.noise_level, 1)
	return {"ok": true, "msg": _format_loot(found), "found": found}

static func _roll_loot(terrain_id: String) -> String:
	# Choose category bias by terrain.
	var category_weights: Dictionary = {
		"food": 30, "consumable": 15, "weapon": 10, "armor": 8,
		"ammo": 12, "material": 25
	}
	if terrain_id == "supermarket":
		category_weights = {"food": 60, "consumable": 10, "material": 15, "ammo": 5, "weapon": 5, "armor": 5}
	elif terrain_id == "hospital":
		category_weights = {"consumable": 60, "food": 15, "material": 15, "weapon": 5, "ammo": 5}
	elif terrain_id == "military":
		category_weights = {"weapon": 35, "ammo": 35, "armor": 15, "consumable": 10, "material": 5}
	elif terrain_id == "gas_station":
		category_weights = {"food": 35, "material": 30, "consumable": 10, "weapon": 10, "ammo": 15}
	elif terrain_id == "ruins" or terrain_id == "house":
		category_weights = {"material": 35, "food": 25, "weapon": 15, "consumable": 15, "armor": 10}
	elif terrain_id == "forest" or terrain_id == "plains":
		category_weights = {"material": 50, "food": 30, "consumable": 15, "weapon": 5}
	elif terrain_id == "church":
		category_weights = {"consumable": 30, "food": 30, "material": 25, "weapon": 15}
	elif terrain_id == "junkyard":
		category_weights = {"material": 70, "weapon": 15, "ammo": 5, "armor": 10}
	elif terrain_id == "police_station":
		category_weights = {"weapon": 30, "ammo": 35, "armor": 20, "consumable": 10, "material": 5}
	elif terrain_id == "farm":
		category_weights = {"food": 60, "material": 25, "consumable": 10, "weapon": 5}

	var category: String = String(RNG.weighted_pick_dict(category_weights))
	# Pick an item of that category, weighted by rarity.
	var pool: Array = []
	var weights: Array = []
	for item_id in DataLoader.items.keys():
		var item: Dictionary = DataLoader.items[item_id]
		if item.get("category", "") != category:
			continue
		var rarity: String = String(item.get("rarity", "common"))
		var w: int = 30
		match rarity:
			"common": w = 50
			"uncommon": w = 20
			"rare": w = 5
		pool.append(item_id)
		weights.append(w)
	if pool.is_empty():
		return ""
	return String(RNG.weighted_pick(pool, weights))

static func _format_loot(found: Dictionary) -> String:
	if found.is_empty():
		return "Nothing useful."
	var bits: Array = []
	for item_id in found.keys():
		var n: int = int(found[item_id])
		var name: String = String(DataLoader.items.get(item_id, {}).get("name", item_id))
		bits.append("%dx %s" % [n, name])
	return "Found: " + ", ".join(bits)
