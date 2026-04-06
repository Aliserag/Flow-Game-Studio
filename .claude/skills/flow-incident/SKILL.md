# /flow-incident

Incident response for Flow blockchain game contracts. Follows P0-P5 severity tiers.

## Severity Tiers

| Level | Description | Response SLA |
|-------|-------------|-------------|
| P0 | Contract exploit, funds at risk | Pause immediately, < 15 min |
| P1 | Broken core mechanic (VRF, minting) | < 1 hour |
| P2 | Event indexer down, analytics dark | < 4 hours |
| P3 | Testnet deploy failing | < 24 hours |
| P4 | Non-critical bug | Next sprint |
| P5 | Cosmetic / UX issue | Backlog |

## P0 Response Playbook

1. **Pause** — run `pause_system.cdc` with a clear reason string
2. **Assess** — read `EmergencyPause.pauseReason` and recent events via indexer
3. **Communicate** — post incident notice with: impact, affected contracts, ETA
4. **Root cause** — reproduce on emulator, identify the vulnerable code path
5. **Fix** — update contract, run full test suite, get second review
6. **Deploy fix** — testnet first, then mainnet
7. **Unpause** — run `unpause_system.cdc`
8. **Post-mortem** — write `docs/postmortems/YYYY-MM-DD-incident-title.md`

## When Invoked

Ask the user:
1. What is the severity? (P0-P5)
2. What contract/transaction is affected?
3. Is user data (assets, tokens) at risk?

Then generate:
- The appropriate pause transaction (if P0/P1)
- A template incident communication
- Debugging steps specific to the affected contract
- A post-mortem template in `docs/postmortems/`
