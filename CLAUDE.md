# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Blockchain**: Flow (mainnet + testnet)
- **Smart Contract Language**: Cadence 1.0
- **Client SDK**: FCL (Flow Client Library) — JavaScript/TypeScript
- **Game Engine**: [CHOOSE: Godot 4 / Unity / Unreal Engine 5] — configure with /setup-engine
- **Game Language**: [CHOOSE after engine]
- **Version Control**: Git with trunk-based development
- **Contract Testing**: Cadence Testing Framework (`flow test`)
- **Local Dev**: Flow Emulator (`flow emulator`)

> **Flow Reference Docs**: `docs/flow-reference/` — version-pinned Cadence 1.0 API snapshots.
> Always consult these before suggesting Cadence API calls; Cadence 1.0 has significant
> breaking changes from 0.x that the LLM may not know about.

> **Cadence Contracts**: `cadence/` — production-ready contract library with VRF,
> entitlements, scheduled transactions, and marketplace patterns.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

## Flow Blockchain Reference

@docs/flow-reference/VERSION.md
@.claude/docs/flow-coding-standards.md
