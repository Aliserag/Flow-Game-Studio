---
name: flow-economy
description: "Design the token economy for a Flow game: fungible token supply model, NFT scarcity curves, marketplace fees, sink/faucet analysis, and anti-inflation safeguards. Produces an economy design document."
argument-hint: "[game-name or 'new']"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit
---

# /flow-economy

Designs the token economy for a Flow blockchain game.

**Always delegate complex design decisions to:** `web3-economy-designer` agent

## Steps

### 1. Gather requirements

Ask:
1. Does the game have a fungible token (in-game currency)?
2. What are the primary earning mechanisms?
3. What are the primary spending mechanisms?
4. What is the target inflation rate? (most sustainable: 0-2% annually)
5. Is there a fixed total supply or continuous minting?
6. What NFT types exist, and what are their scarcity targets?

### 2. Run sink/faucet analysis

For each token type:
- List all FAUCETS (ways tokens enter the economy)
- List all SINKS (ways tokens leave the economy)
- Calculate: is the economy inflationary, deflationary, or balanced?

Sustainable target: sinks >= faucets in steady state.

### 3. Produce economy design document

Write to `design/gdd/economy-[game-name].md` using the template at
`.claude/docs/templates/token-economy-model.md`.

### 4. Propose GameToken contract parameters

Show proposed values:
- `maxSupply` (or "no cap")
- Initial minting rate
- Burn mechanisms
- Marketplace royalty percentage

### 5. Flag risks

For any design that could constitute a security:
"This design includes [X] which may require regulatory review. Consult legal counsel."
