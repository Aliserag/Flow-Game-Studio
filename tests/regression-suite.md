# Regression Suite

Tests added because of a fixed bug. Each entry references the bug file, the
fix commit, and the test file that proves the bug stays fixed.

> Rule from `coding-standards.md`: every fixed bug at Sev 1 or Sev 2 must add a
> regression test before the bug is closed.

| Bug ID | Title | Sev | Fix commit | Regression test |
|---|---|---|---|---|
| BUG-001 | `_lose_supplies` mutates Dictionary during iteration → crash | 2 | M0 audit | `tests/unit/systems/test_event_system.gd::test_lose_supplies_safe_iteration` (TODO) |
| BUG-002 | Combat used `randi()` instead of seeded RNG → non-deterministic tests | 3 | M0 audit | covered by combat resolver test suite |
| BUG-003 | Lead death left party leaderless | 2 | M0 audit | `test_combat_resolver.gd::test_lead_promoted_when_lead_dies` |

When adding a new entry, link both the bug file and the test file with relative
paths from the project root.
