---
name: flow-review
description: "Code review a Cadence contract for quality, standards compliance, upgrade safety, and gas efficiency. Produces a structured review report."
argument-hint: "[contract-file-path]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# /flow-review

Code review for Cadence smart contracts.

**Read first:** `.claude/docs/flow-coding-standards.md`

## Review Categories

### 1. Standards Compliance
- Correct `access(all/self/account/contract)` usage
- No `pub`/`priv` keywords
- Entitlements defined before use
- Events emitted for all state changes

### 2. Resource Safety
- No resource loss paths
- `@` prefix on all resource types
- `<-` used for all resource moves
- `destroy` called on all temporary resources

### 3. Upgrade Safety
- No removed fields
- No changed field types
- New fields are optional with defaults
- No removed entitlements

### 4. Gas / Storage Efficiency
- Loops bounded (no unbounded iteration over large arrays)
- Storage used efficiently (structs vs. resources)
- Events preferred over logs for off-chain queries

### 5. Test Coverage
- Corresponding test file exists
- Tests cover: happy path, edge cases, access control violations

## Output Format

```
## Code Review: [ContractName]

### Summary
[2-3 sentence overall assessment]

### Issues

| Severity | Line | Issue | Fix |
|----------|------|-------|-----|
| BLOCK    | 47   | Force-unwrap on capability | Use ?? panic(...) |
| WARN     | 83   | No event emitted for burn | Add Burned event |
| NOTE     | 12   | Consider entitlement mapping | See entitlements guide |

### Approved for: [emulator / testnet / mainnet]
```
