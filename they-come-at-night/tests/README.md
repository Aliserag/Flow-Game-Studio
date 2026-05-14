# Tests

Zero-dependency test framework. Designed to upgrade to GUT later without rewriting
test files (assertion API mirrors GUT's: `assert_eq`, `assert_true`, etc.).

## Run locally

```bash
cd they-come-at-night
# First time only (populates class cache):
godot --headless --editor --quit

# Run tests:
godot --headless res://scenes/Main.tscn -- --test

# Optional: simulate a 50-turn solo run (for CI smoke):
godot --headless res://scenes/Main.tscn -- --smoke

# Optional: longer Settled-mode run with 5 survivors:
godot --headless res://scenes/Main.tscn -- --smoke-long
```

Exit code 0 on all-pass, 1 on any failure (CI-suitable).

> **Why not `--script`?** Godot's `--script` mode runs a single GDScript file
> without booting the project, which means autoload identifiers (`DataLoader`,
> `GameState`, etc.) don't resolve at compile time. The Main-scene launcher
> approach boots the project normally and routes via `OS.get_cmdline_user_args()`.

## Add a new test suite

1. Create `tests/unit/<area>/test_<thing>.gd`:
   ```gdscript
   class_name MyThingTest
   extends RefCounted

   static func run_all() -> void:
       TestFramework.suite("MyThing")
       _test_one_thing()

   static func _test_one_thing() -> void:
       TestFramework.assert_eq(2, 1 + 1, "math")
   ```

2. Add the suite call to `scripts/ui/main_launcher.gd::_run_tests()`:
   ```gdscript
   MyThingTest.run_all()
   ```

3. Run the runner — your suite shows up in the output.

## Layout

```
tests/
├── README.md           — this file
├── run_tests.gd        — entry point (godot --headless --script)
├── test_framework.gd   — assertion library
├── regression-suite.md — bug → test mapping
├── helpers/
│   └── test_helpers.gd — common factories (make_lead_at, seed_rng, etc.)
├── unit/
│   ├── test_data_loader.gd
│   ├── world/
│   │   ├── test_grid.gd
│   │   └── test_tile.gd
│   └── systems/
│       ├── test_combat_resolver.gd
│       ├── test_inventory_system.gd
│       └── test_swarm_system.gd
├── integration/        — multi-system flows (M1+)
└── fixtures/           — saved scenes/resources (M1+)
```

## Determinism

All tests must seed RNG before any random call:

```gdscript
TestHelpers.seed_rng(12345)
```

Tests that compare exact values across random rolls must use the same seed at the
top of the test method. Don't call `RandomNumberGenerator.randomize()` in tests.

## Coverage targets

See `design/TEST_PLAN.md` for per-system targets (75% by M3, 85% by release).

## Upgrading to GUT

When ready to switch to GUT:

1. Drop GUT addon into `addons/gut/`.
2. Replace `extends RefCounted` → `extends GutTest` in test files.
3. Replace `class_name FooTest` → just keep `extends GutTest`.
4. Convert `static func run_all()` → individual `func test_*()` methods.
5. Replace `TestFramework.assert_eq` → `assert_eq` (GUT inherits these).
6. Delete `test_framework.gd` and `run_tests.gd`.
7. Update `.github/workflows/test.yml` to use GUT runner.

The test bodies themselves don't change.
