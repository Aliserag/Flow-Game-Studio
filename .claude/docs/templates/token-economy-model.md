# Token Economy Model: [Game Name]

## Overview
[One-paragraph summary of the economy]

## Token Types

| Token | Type | Symbol | Max Supply | Decimals |
|-------|------|--------|------------|----------|
| [Name] | Fungible | [SYM] | [N or unlimited] | 8 |
| [Name] | NFT | — | [N per rarity tier] | — |

## Faucets (Token Sources)

| Mechanism | Rate | Cap | Notes |
|-----------|------|-----|-------|
| Gameplay rewards | X tokens/hour | Y/day/player | Scales with engagement |
| Staking yield | X% annually | — | |

## Sinks (Token Drains)

| Mechanism | Rate | Notes |
|-----------|------|-------|
| Marketplace fee | X% of sale | Burned, not redistributed |
| Crafting cost | X tokens | |

## Equilibrium Analysis

Daily tokens minted (all faucets): X
Daily tokens burned (all sinks): Y
Net daily change: Z (target: <= 0 in steady state)

## Scarcity Model (NFTs)

| Rarity | Supply | Drop Rate | Burn Mechanic |
|--------|--------|-----------|---------------|
| Common | Unlimited | 60% | None |
| Uncommon | 100,000 | 25% | Crafting ingredient |
| Rare | 10,000 | 12% | Upgrade fuel |
| Legendary | 1,000 | 3% | — |

## Risk Factors

- [Hyperinflation risk if...] — Mitigation: [...]
- [Deflationary spiral if...] — Mitigation: [...]
- [Regulatory: does this constitute a security?] — [Assessment]

## On-Chain Parameters

```cadence
// GameToken.cdc initial parameters
let maxSupply: UInt64 = 1_000_000_000
let dailyMintCap: UInt64 = 100_000
let marketplaceFeePercent: UInt8 = 5  // 5% burned
```
