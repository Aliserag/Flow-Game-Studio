# /flow-economics-audit

Analyze the game's token economy for sustainability, sink/faucet balance, and whale attack resistance.

## When to Run

- Before launching GameToken to mainnet
- After any change to minting rates, burn mechanics, or marketplace fees
- When adding new token sinks or faucets

## Analysis Framework

### Faucet Identification
List all ways tokens enter the economy:
- GameToken.Minter.mintTokens() calls (who can call, under what conditions)
- Tournament prize distributions
- SeasonPass rewards
- Airdrop/marketing allocations

### Sink Identification
List all ways tokens leave the economy:
- Marketplace platform fees (burned vs treasury)
- SeasonPass.purchasePremium() burns
- Crafting material consumption
- Governance proposal bond (slashed on failure)

### Supply Projections
Model 12-month token supply under 3 scenarios:
1. Base case: 1000 DAU, average 5 transactions/day
2. Bull case: 10,000 DAU, average 10 transactions/day
3. Whale attack: 10 accounts minting at max rate for 30 days

### Red Flags
- Any uncapped minting function accessible without daily limit
- Sinks that pay to treasury but treasury has no burn mechanism
- Marketplace fees below 0.5% (leaves room for wash trading profitability)
- Token distribution where top 10 wallets hold >50% at launch

## Output Format

Produce a report in `docs/economics/audit-YYYY-MM-DD.md` with:
- Supply/demand balance sheet
- Scenario modeling table
- Risk rating: GREEN / YELLOW / RED per category
- Recommended parameter changes
