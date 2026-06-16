# WARBAND Privacy Policy

**Effective date:** 2026-06-16
**Last updated:** 2026-06-16

WARBAND respects player privacy. This page explains what data the game collects, how it's used, and how to control it.

## What we collect

**By default, the game collects nothing.** All play data — your warband, gold,
fallen orcs, save progress — lives only in your browser's storage on your own
device. It is never sent anywhere.

### Optional: Anonymous Telemetry (opt-in)

If you enable telemetry in the Settings screen, the game may send the following
anonymous events to a configured endpoint:

| Event | Data |
|---|---|
| `run_started` | session id, version |
| `run_ended` | victory/defeat, battles completed/won, gold at end, gravestone count |
| `hero_died` | hero's battles fought and kill count (no name) |
| `battle_completed` | gold gained, enemies killed |

Every event also includes:
- A **hashed player id** — a one-way SHA-256 hash of a random per-install salt. This is **not** linkable back to you. We cannot recover the original.
- A **session id** — random per-launch.
- The **game version**.

## What we do NOT collect

- Your name, email, IP address, or any account info
- Orc names, gear, or specific gameplay choices
- Your save file contents
- Browser fingerprint, device id, or location
- Anything that could identify you as a person

## How to opt out

Telemetry is **opt-in**: it is OFF unless you explicitly enable it in the
Settings screen. You can disable it again at any time — the toggle takes effect
immediately and the queue is cleared.

To view what was queued before flush, look in your browser's storage at the
`telemetry_consent.json` file in the IndexedDB for this site.

## Where data is sent

The telemetry endpoint URL is configurable. In the public alpha, it is **empty
by default** — flush is a no-op. If a developer configures an endpoint, it will
appear in Settings before any data is sent.

## Save data

Save data lives in your browser's storage (IndexedDB on the web, filesystem on
desktop). The developer never receives it. Clearing your browser data deletes
your save — back up the file manually if you care to keep it.

Save files are HMAC-signed to discourage casual tampering. The signing key is in
the source code and is not a security measure — only a friction layer for
casual save editing.

## Children

WARBAND is rated for ages 13+ due to thematic content (permadeath, violence in
text and sprite). It does not knowingly collect data from children under 13.

## Changes

If we change what telemetry collects, this page will be updated and the change
will be summarised in the in-game Settings screen before the new collection
begins.

## Contact

Open a GitHub issue at the project repository for privacy questions or
concerns. See `docs/release/COMMUNITY.md` for channels.

---

*WARBAND is currently alpha software. This policy reflects current behavior; we
will update it as features evolve. Significant changes will be flagged in patch
notes.*
