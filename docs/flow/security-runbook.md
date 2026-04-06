# Flow Game Security Runbook

## Pre-Deployment Checklist

- [ ] All contracts import EmergencyPause and call `assertNotPaused()` in state-mutating functions
- [ ] No bare `auth &T` — all capabilities use entitlement syntax `auth(E) &T`
- [ ] Minter resources stored at private storage paths, NEVER published to public
- [ ] VRF commit/reveal uses RandomBeaconHistory (not `revertibleRandom()` alone)
- [ ] `boundedRandom()` uses rejection sampling (not naive modulo)
- [ ] All admin capabilities require at least 2-of-3 multisig on mainnet
- [ ] Contract upgrade tested with existing player data on testnet before mainnet
- [ ] EmergencyPause.Admin key is on hardware wallet (Ledger) for mainnet

## Keys & Access

- Deployer key: Used only for initial deployment. Rotated after first deploy.
- Admin key: Hardware wallet. Signs pause/unpause, emergency ops only.
- Minter key: Hot wallet, limited capability. Rotated every 90 days.
- Testnet keys: In GitHub Secrets. Never reuse for mainnet.

## Contact Escalation

1. On-call dev (first responder)
2. Lead developer
3. Flow team security disclosure: security@flow.com (for protocol-level issues)

## Post-Mortem Template

Save to: `docs/postmortems/YYYY-MM-DD-title.md`

Sections: Summary, Timeline, Root Cause, Impact, Resolution, Action Items
