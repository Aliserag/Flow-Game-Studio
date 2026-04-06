# Token Classification Guide

**THIS IS NOT LEGAL ADVICE. Consult a licensed attorney before launching any token.**

## The Howey Test (US)

A token is likely a security if all four prongs are met:
1. Investment of money
2. In a common enterprise
3. With expectation of profit
4. From the efforts of others

## GameToken Risk Analysis

| Factor | Our Token | Risk Level |
|--------|-----------|------------|
| Purchasable with real money | Depends on sale mechanism | HIGH if yes |
| Secondary market trading enabled | Yes (Marketplace contract) | MEDIUM |
| Profit expectation in marketing | Avoid price claims | HIGH if claimed |
| Utility in game | Yes (consumable, entry fees) | REDUCES risk |
| Hard supply cap | Yes (GameToken.maxSupply) | REDUCES risk |

## Safer Structures

1. **Non-transferable credits**: Use a separate non-transferable credit system for gameplay; reserve GameToken for cosmetics only
2. **No sale at launch**: Distribute only through gameplay; never sell directly for fiat
3. **No price claims**: Marketing must never suggest token will increase in value
4. **Geographic restrictions**: Block or restrict US, UK, and other high-scrutiny jurisdictions from token purchases if in doubt

## Jurisdictions With Clear Guidance

- Switzerland (FINMA): Utility tokens well-defined
- Singapore (MAS): Payment token / utility / security distinction exists
- EU (MiCA): Effective 2024, covers utility and asset-referenced tokens
- USA: Most restrictive — treat as security unless clearly consumable utility

## Before Launch: Required Steps

- [ ] Obtain legal opinion letter from crypto-specialized attorney
- [ ] File with FinCEN as Money Services Business if conducting token sales
- [ ] Register with state money transmitter regulators as required
- [ ] Implement KYC/AML if token is sold for fiat (not required for pure gameplay earning)
