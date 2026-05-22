GODOT ?= /tmp/Godot_v4.4-stable_linux.x86_64
PROJECT_ROOT := $(shell pwd)

.PHONY: help test smoke smoke-long e2e verify-green editor-scan export-linux export-web export-all clean

help:
	@echo "Targets:"
	@echo "  make test          — run all unit tests"
	@echo "  make smoke         — 50-turn solo smoke"
	@echo "  make smoke-long    — 100-turn settled smoke"
	@echo "  make e2e           — full E2E harness (118+ assertions)"
	@echo "  make verify-green  — editor scan + tests + E2E + smokes (the green-build gate)"
	@echo "  make editor-scan   — refresh class cache, surface parse errors"
	@echo "  make export-linux  — build Linux/X11 binary into dist/linux/"
	@echo "  make export-web    — build HTML5 into dist/web/"
	@echo "  make export-all    — build all platforms"
	@echo "  make clean         — wipe dist/"

editor-scan:
	@$(GODOT) --headless --editor --quit 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" || echo "Clean scan."

test:
	@$(GODOT) --headless res://scenes/Main.tscn -- --test

smoke:
	@$(GODOT) --headless res://scenes/Main.tscn -- --smoke

smoke-long:
	@$(GODOT) --headless res://scenes/Main.tscn -- --smoke-long

e2e:
	@$(GODOT) --headless res://scenes/Main.tscn -- --e2e

verify-green:
	@echo "=== editor scan ==="
	@$(MAKE) editor-scan
	@echo "=== unit tests ==="
	@$(MAKE) test
	@echo "=== E2E ==="
	@$(MAKE) e2e
	@echo "=== short smoke ==="
	@$(MAKE) smoke
	@echo "=== long smoke ==="
	@$(MAKE) smoke-long
	@echo "=== GREEN ==="

stamp-commit:
	@# Writes the short git commit hash into res://BUILD_COMMIT so the BuildInfo
	@# autoload can read it at runtime.
	@git rev-parse --short HEAD > BUILD_COMMIT 2>/dev/null || echo "unknown" > BUILD_COMMIT

export-linux: stamp-commit
	@mkdir -p dist/linux
	@$(GODOT) --headless --export-release "Linux/X11" dist/linux/they-come-at-night.x86_64
	@cp CONTROLS.txt dist/linux/CONTROLS.txt

export-web: stamp-commit
	@mkdir -p dist/web
	@$(GODOT) --headless --export-release "Web" dist/web/index.html

export-windows: stamp-commit
	@mkdir -p dist/windows
	@$(GODOT) --headless --export-release "Windows Desktop" dist/windows/they-come-at-night.exe
	@cp CONTROLS.txt dist/windows/CONTROLS.txt

export-macos: stamp-commit
	@mkdir -p dist/macos
	@$(GODOT) --headless --export-release "macOS" dist/macos/they-come-at-night.zip
	@cp CONTROLS.txt dist/macos/CONTROLS.txt

export-all: export-linux export-windows export-macos export-web

clean:
	@rm -rf dist/
	@rm -rf .godot/imported
