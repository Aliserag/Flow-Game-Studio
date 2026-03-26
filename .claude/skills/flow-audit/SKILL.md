---
name: flow-audit
description: "Security audit of Cadence smart contracts. Checks for common vulnerabilities: unauthorized access, capability leaks, randomness bias, integer overflow, and missing event emissions."
argument-hint: "[contract-file or 'all']"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

# /flow-audit

Security audit for Cadence contracts. Always run before testnet/mainnet deployment.

**Read first:** `docs/flow-reference/entitlements-reference.md`

## Audit Checklist

### Access Control
- [ ] All public-facing functions reviewed — any unintentionally public?
- [ ] Admin/Minter resources: stored only in deployer account, never on public paths
- [ ] Capabilities issued with minimum required entitlements
- [ ] No `access(all)` on state-mutating functions without entitlements

### Resource Safety
- [ ] Every `create Resource()` has a destroy path
- [ ] No force-unwrap `!` on optional capabilities
- [ ] Resources not in intermediate states after panics
- [ ] `ownedNFTs` dictionary uses `<-` correctly

### Randomness
- [ ] `revertibleRandom()` only for low-stakes outcomes
- [ ] High-stakes randomness uses RandomVRF commit/reveal
- [ ] Minimum 1 block between commit and reveal enforced
- [ ] Reveal hash uses both beacon value AND player secret

### Integer Safety
- [ ] Division by zero protected
- [ ] UInt256 <-> UInt64 conversions bounded correctly

### Event Emissions
- [ ] All state-changing operations emit events
- [ ] Events include enough data for off-chain indexing

### Cadence 1.0 Compliance
- [ ] No `pub`/`priv` keywords
- [ ] All entitlements defined before use
- [ ] Import syntax: `import "ContractName"`

## Output Format

PASS / WARN / BLOCK per category.
BLOCK = must fix before deployment.
For each issue: file, line, severity, description, fix.
