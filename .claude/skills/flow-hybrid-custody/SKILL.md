# /flow-hybrid-custody

Design and implement wallet-less onboarding using Flow's HybridCustody standard.

## Usage

- `/flow-hybrid-custody setup` — generate child account provisioning server code
- `/flow-hybrid-custody link-wallet` — generate the account linking transaction pair
- `/flow-hybrid-custody claim-assets` — generate transaction to move assets from child to parent
- `/flow-hybrid-custody audit` — review existing hybrid custody setup for security issues

## The Three-Phase Player Journey

### Phase 1: No Wallet (New Player)
- Game server creates child account (server holds keys)
- All mints and rewards go to child account address
- Player sees their assets in-game — no blockchain awareness needed
- Game pays all transaction fees (Phase 37 sponsorship)

### Phase 2: Wallet Connected (Engaged Player)
- Player installs Blocto, Flow Reference Wallet, or any Flow wallet
- Player signs `link_to_parent.cdc` from both their wallet AND the game
- Child account publishes asset capabilities to parent
- Player can now see their game assets in their wallet app

### Phase 3: Full Custody (Power User)
- Player optionally claims full ownership of the child account
- Game revokes its own keys from the child account
- Player now fully self-custodies — game has no access

## ALWAYS Verify Contract Addresses

HybridCustody contract addresses change across Flow versions.
Before generating any HybridCustody code, fetch current addresses:

```
WebFetch: https://developers.flow.com/tools/toolchains/flow-cli/accounts/hybrid-custody
```

Never hardcode HybridCustody addresses — always read from Flow docs or `flow.json` aliases.

## Security Requirements

- Child account private keys -> HSM or cloud secrets manager
- Rotate child account keys if server is compromised
- Set a `CapabilityFilter` on the child account to restrict what the parent can withdraw
  (e.g., parent can claim GameNFT but NOT the child account's FLOW balance)
- Rate-limit child account creation: max 10/minute/IP
