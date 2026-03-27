# /flow-monitor

Set up and query production monitoring for Flow game contracts.

## Usage

- `/flow-monitor status` — run invariant checks and report current health
- `/flow-monitor setup` — scaffold metrics exporter and alert rules for a new game
- `/flow-monitor alert-test` — verify alert rules fire correctly with synthetic data
- `/flow-monitor dashboard` — generate Grafana dashboard JSON for the game's metrics

## Monitoring Stack

```
Flow contracts -> Event indexer -> Metrics exporter -> Prometheus -> Grafana
                                                  -> Alertmanager -> PagerDuty/Slack
```

## Key Metrics to Watch

| Metric | Warning Threshold | Critical Threshold |
|--------|------------------|-------------------|
| Indexer lag | >1,000 blocks | >10,000 blocks |
| Mint rate | >100/hour | >1,000/hour |
| Daily sales | <10 | <1 |
| Whale concentration | >60% top-10 | >80% top-10 |
| Staking participation | <5% supply | <1% supply |
| Storage near capacity | >80% per account | >95% per account |

## On-Call Runbook

1. Alert fires -> check `/flow-game-state global` for contract state
2. Check indexer logs: `tools/indexer/` for errors
3. Check invariants: `flow scripts execute cadence/scripts/monitoring/check_invariants.cdc`
4. If `PAUSED` violation: read `EmergencyPause.pauseReason`, follow `/flow-incident` P0 playbook
5. Escalate to `flow-architect` agent for architectural anomalies
