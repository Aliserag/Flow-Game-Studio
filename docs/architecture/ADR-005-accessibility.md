# ADR-005 — Accessibility as a First-Class Subsystem

**Status:** Accepted
**Date:** 2026-06-16

## Context

The art bible §12 mandates WCAG 2.1 AA minimum. The concept doc names accessibility as a G3 gate. Without a dedicated subsystem, accessibility features accrete ad-hoc per screen and drift — a known indie failure mode.

The two highest-risk concerns specific to WARBAND:
1. **Color semantic collisions**: Fell Red (death/HP) and Hex Viridian (magic) fail deuteranopia/protanopia without mitigation.
2. **Keyboard-only play**: HTML5 deployments must work for users without a mouse.

## Decision

A single `Accessibility` autoload owns:
- Colorblind mode (OFF / DEUTERANOPIA / PROTANOPIA / TRITANOPIA) with per-mode color tables for damage / magic / warning
- High-contrast toggle
- A `get_focus_style()` helper returning a uniform 2px gold focus border
- Text markers `damage_marker()` / `magic_marker()` for redundant cues when colorblind mode is active

All UI screens read semantic colors via `Accessibility.get_damage_color()` etc. rather than hardcoding `Color(...)`. The autoload persists settings to `user://accessibility_settings.json`.

## Consequences

**Positive:**
- One place to change semantic colors. Adding tritanopia support is data-only.
- New screens inherit accessible focus styling by reading `Accessibility.get_focus_style()`.
- Text markers ensure information is never solely color-coded.

**Negative:**
- Slight indirection cost — each UI render reads from the autoload instead of using a constant. Negligible at our screen counts.
- Settings UI must surface the toggles or the feature is invisible. The Settings screen (G2) wires this up.

## Validation

- All damage-colored text confirmed to pass 4.5:1 contrast in all four modes (manual contrast audit at `production/qa/accessibility-audit.md`).
- Screen-reader behavior (Godot 4.5+ AccessKit) deferred to G3 — needs hardware/OS-specific test pass.
