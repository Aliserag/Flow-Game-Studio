# /flow-staking

Generate staking pool transactions and analyze staking pool health.

## Usage

- `/flow-staking stake --amount 1000` — generate stake transaction
- `/flow-staking unstake --amount 500` — generate unstake request transaction
- `/flow-staking claim` — generate reward claim transaction
- `/flow-staking status --staker 0xabc` — check pending rewards and staked balance
- `/flow-staking health` — analyze pool APY and reward distribution fairness

## Reward Model

Uses the **index accumulator** pattern (also called the "reward per token stored" model from Synthetix):
- One global `rewardIndex` variable — no iteration over all stakers
- O(1) reward calculation for any staker
- Accurate to UFix64 precision (8 decimal places)

## APY Estimation

```
APY ≈ (totalFeesLast30Days / totalStaked) * 12 * 100%
```

Run the `get_staker_info.cdc` script to fetch:
- `rewardIndex` (global)
- `rewardIndexSnapshot` (staker's last claim snapshot)
- Pending = `(rewardIndex - snapshot) * stakedAmount`

## Unstaking Delay

Default: 14,000 blocks (~14 epochs, ~3.5 days at 1000 blocks/epoch)

This prevents:
1. Flash-stake attacks: stake just before reward distribution, unstake immediately after
2. Governance manipulation: stake to vote, unstake before consequences

Configurable by governance proposal.
