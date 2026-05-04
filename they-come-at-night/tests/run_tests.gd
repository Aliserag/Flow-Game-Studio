extends SceneTree

# Headless test runner. Invoke from project root with:
#   godot --headless --script res://tests/run_tests.gd
#
# Returns exit code 0 on all-pass, 1 on any failure (suitable for CI).

func _initialize() -> void:
	print("=== They Come At Night — Test Suite ===")
	TestFramework.reset()

	# Order matters only insofar as suites print sequentially.
	# Unit suites first.
	DataLoaderTest.run_all()
	GridTest.run_all()
	TileTest.run_all()
	CombatResolverTest.run_all()
	InventorySystemTest.run_all()
	SwarmSystemTest.run_all()
	BetrayalSystemTest.run_all()
	# Integration suites.
	SaveLoadTest.run_all()

	print(TestFramework.summary())
	quit(0 if TestFramework.ok() else 1)
