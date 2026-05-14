extends Node

# Top-level launcher. Detects CLI args:
#   --test       run the test suite and quit (CI mode)
#   --smoke      boot a solo run, simulate 50 turns, exit with summary (CI smoke)
#   (none)       show the main menu
#
# CLI usage:
#   godot --headless res://scenes/Main.tscn -- --test
#   godot --headless res://scenes/Main.tscn -- --smoke

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			_run_tests()
			return
		if arg == "--smoke":
			_run_smoke()
			return
		if arg == "--smoke-long":
			_run_smoke_long()
			return
		if arg == "--gameview-boot":
			_boot_gameview()
			return
		if arg == "--e2e":
			_run_e2e()
			return
	# Default: keep the MainMenu child visible (already instanced in scene).

func _run_tests() -> void:
	# Hide the MainMenu so it doesn't render during tests.
	for c in get_children():
		c.visible = false

	print("=== They Come At Night — Test Suite ===")
	TestFramework.reset()

	DataLoaderTest.run_all()
	GridTest.run_all()
	TileTest.run_all()
	CombatResolverTest.run_all()
	InventorySystemTest.run_all()
	SwarmSystemTest.run_all()
	BetrayalSystemTest.run_all()
	SaveLoadTest.run_all()

	print(TestFramework.summary())
	get_tree().quit(0 if TestFramework.ok() else 1)

func _run_smoke() -> void:
	for c in get_children():
		c.visible = false
	print("=== Smoke run: Solo, 50 turns ===")
	GameState.reset_run(GameState.Mode.SOLO, 4242)
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(GameState.map_size.x / 2, GameState.map_size.y / 2)
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid.add_entity(lead)
	GameState.add_to_inventory("knife", 1)
	GameState.add_to_inventory("canned_food", 50)  # so hunger doesn't end the run prematurely
	GameState.add_to_inventory("water_bottle", 50)
	# Drop a few zombies on the edges.
	for _i in 4:
		var z: ZombieUnit = ZombieUnit.make("single")
		z.pos = GameState.grid.random_edge_position()
		GameState.grid.add_entity(z)
	TurnManager.recompute_vision(GameState.grid)
	var turns_simulated: int = 0
	var max_turns: int = 50
	for i in max_turns:
		if GameState.phase != GameState.Phase.PLAYING:
			break
		TurnManager.end_turn(GameState.grid)
		turns_simulated += 1
	print("Turns simulated: %d / %d" % [turns_simulated, max_turns])
	print("Final state: day=%d party=%d morale=%d phase=%d" %
		[GameState.day, GameState.party.size(), GameState.morale, GameState.phase])
	print("Stats: %s" % str(GameState.stats))
	print("Knowledge: %s" % str(GameState.knowledge))
	# Exit 0 if no crashes — we don't enforce a particular outcome.
	get_tree().quit(0)

func _boot_gameview() -> void:
	# Smoke-boot the GameView scene to surface any UI-init errors.
	for c in get_children():
		c.visible = false
	print("=== GameView boot test ===")
	GameState.reset_run(GameState.Mode.SOLO, 12321)
	var gv := preload("res://scenes/GameView.tscn").instantiate()
	add_child(gv)
	await get_tree().process_frame
	await get_tree().process_frame
	print("GameView _ready completed successfully.")
	print("Children: %d  Party: %d  Grid size: %s" % [
		gv.get_child_count(),
		GameState.party.size(),
		str(GameState.grid.size if GameState.grid else "nil")
	])
	get_tree().quit(0)

func _run_e2e() -> void:
	for c in get_children():
		c.visible = false
	var ok: bool = E2EHarness.run(self)
	# Give a frame so any queued frees complete before quit.
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)

func _run_smoke_long() -> void:
	for c in get_children():
		c.visible = false
	print("=== Long smoke run: Settled, beefy party, 100 turns ===")
	GameState.reset_run(GameState.Mode.SETTLED, 7777)
	GameState.grid = MapGenerator.generate(GameState.map_size)
	var lead := Survivor.make_lead()
	lead.pos = Vector2i(GameState.map_size.x / 2, GameState.map_size.y / 2)
	lead.max_hp = 50
	lead.hp = 50
	lead.attack = 20
	GameState.party.append(lead)
	GameState.assignments[lead.id] = []
	GameState.grid.add_entity(lead)
	# Beef up: extra recruits exercising betrayal AI.
	for fac in ["doctors", "raiders", "cannibals", "scavengers"]:
		var s := Survivor.make_random_recruit()
		s.faction_id = fac
		s.betrayal_chance = float(DataLoader.factions[fac].get("betrayal_chance", 0.0))
		s.pos = lead.pos
		s.max_hp = 50
		s.hp = 50
		GameState.party.append(s)
		GameState.assignments[s.id] = []
		GameState.grid.add_entity(s)
	GameState.add_to_inventory("canned_food", 200)
	GameState.add_to_inventory("water_bottle", 200)
	GameState.add_to_inventory("scrap", 100)
	GameState.add_to_inventory("wood", 100)
	# Establish base where lead stands.
	BaseSystem.establish(lead.pos, GameState.grid)
	# Sprinkle a few zombies and NPCs.
	for _i in 6:
		var z: ZombieUnit = ZombieUnit.make("single")
		z.pos = GameState.grid.random_edge_position()
		GameState.grid.add_entity(z)
	for _i in 3:
		var n: Npc = Npc.spawn_random()
		n.pos = GameState.grid.random_edge_position()
		GameState.grid.add_entity(n)
	TurnManager.recompute_vision(GameState.grid)
	var turns_simulated: int = 0
	var max_turns: int = 100
	for i in max_turns:
		if GameState.phase != GameState.Phase.PLAYING:
			break
		TurnManager.end_turn(GameState.grid)
		turns_simulated += 1
	print("Turns simulated: %d / %d" % [turns_simulated, max_turns])
	print("Final state: day=%d party=%d morale=%d phase=%d" %
		[GameState.day, GameState.party.size(), GameState.morale, GameState.phase])
	print("Megahorde unlocked=%s eta=%d" % [str(GameState.megahorde_unlocked), GameState.megahorde_eta])
	print("Swarm pending: %s" % str(GameState.swarm_pending))
	print("Stats: %s" % str(GameState.stats))
	print("Knowledge: %s" % str(GameState.knowledge))
	get_tree().quit(0)
