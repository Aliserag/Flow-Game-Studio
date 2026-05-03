class_name BaseSystem
extends RefCounted

# Settlement: establish base, build enhancements, daily upkeep & passive yields.

static func establish(pos: Vector2i, grid: Grid) -> bool:
	if GameState.has_base:
		EventBus.log_warn("You already have a base. Abandon the old one first.")
		return false
	var t := grid.get_tile(pos)
	if t == null:
		return false
	GameState.has_base = true
	GameState.base_pos = pos
	GameState.base_terrain_id = t.terrain_id
	GameState.base_defense_bonus = t.defense_bonus()
	t.has_base = true
	EventBus.emit_signal("base_established", pos)
	if t.is_building():
		EventBus.log_good("Base established in %s. Defense +%d. Escape harder if besieged." % [t.display_name(), t.defense_bonus()])
	else:
		EventBus.log_good("Camp made on %s. Defense +%d. Easier to flee if it goes bad." % [t.display_name(), t.defense_bonus()])
	return true

static func abandon() -> void:
	GameState.has_base = false
	GameState.base_enhancements.clear()
	GameState.building_enhancement_id = ""
	GameState.building_days_left = 0
	EventBus.emit_signal("base_lost")
	EventBus.log_warn("You abandon the base.")

static func can_build(id: String) -> Dictionary:
	if not GameState.has_base:
		return {"ok": false, "reason": "No base."}
	if GameState.base_enhancements.has(id):
		return {"ok": false, "reason": "Already built."}
	if GameState.building_enhancement_id != "":
		return {"ok": false, "reason": "Already building %s." % GameState.building_enhancement_id}
	var enh: Dictionary = DataLoader.enhancements.get(id, {})
	if enh.is_empty():
		return {"ok": false, "reason": "Unknown enhancement."}
	for req in enh.get("requires", []):
		if not GameState.base_enhancements.has(req):
			return {"ok": false, "reason": "Requires %s first." % req}
	for item_id in enh.get("cost", {}).keys():
		var need: int = int(enh["cost"][item_id])
		if not GameState.has_item(item_id, need):
			return {"ok": false, "reason": "Need %d %s." % [need, item_id]}
	return {"ok": true, "reason": ""}

static func start_build(id: String) -> bool:
	var check := can_build(id)
	if not check.ok:
		EventBus.log_warn("Can't build: %s" % check.reason)
		return false
	var enh: Dictionary = DataLoader.enhancements[id]
	for item_id in enh.get("cost", {}).keys():
		GameState.remove_from_inventory(String(item_id), int(enh["cost"][item_id]))
	GameState.building_enhancement_id = id
	GameState.building_days_left = int(enh.get("build_days", 1))
	EventBus.emit_signal("enhancement_progress", id, GameState.building_days_left)
	EventBus.log_info("Construction begun: %s (%d days)" % [enh.get("name", id), GameState.building_days_left])
	return true

static func tick_day() -> void:
	if GameState.building_enhancement_id != "":
		GameState.building_days_left -= 1
		if GameState.building_days_left <= 0:
			var id := GameState.building_enhancement_id
			GameState.base_enhancements.append(id)
			GameState.building_enhancement_id = ""
			EventBus.emit_signal("enhancement_built", id)
			EventBus.log_good("Construction complete: %s" % DataLoader.enhancements.get(id, {}).get("name", id))
		else:
			EventBus.emit_signal("enhancement_progress", GameState.building_enhancement_id, GameState.building_days_left)

	# Passive yields from completed enhancements.
	for id in GameState.base_enhancements:
		var enh: Dictionary = DataLoader.enhancements.get(id, {})
		if enh.has("food_per_day"):
			GameState.add_to_inventory("canned_food", int(enh["food_per_day"]))
		if enh.has("heal_per_day"):
			# Heal each surviving party member by N up to max.
			for s in GameState.party:
				s.hp = min(s.max_hp, s.hp + int(enh["heal_per_day"]))
			EventBus.emit_signal("hud_refresh_requested")
		if enh.has("morale_bonus"):
			GameState.adjust_morale(int(enh["morale_bonus"]))
