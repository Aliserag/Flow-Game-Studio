extends Node

# DEPRECATED — Godot's --script mode does NOT resolve autoload identifiers
# (DataLoader, GameState, etc.) at compile time, which makes this script
# fail to load any test suite that references autoloads.
#
# Run tests via the Main scene launcher instead:
#
#   godot --headless res://scenes/Main.tscn -- --test
#
# That path boots the project normally (autoloads register, class cache loads)
# and the `--test` user-arg routes to MainLauncher._run_tests().
#
# This file is kept for documentation only.

func _ready() -> void:
	push_error("Do not invoke run_tests.gd directly. Use: godot --headless res://scenes/Main.tscn -- --test")
	get_tree().quit(1)
