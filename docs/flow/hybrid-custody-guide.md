# HybridCustody: Wallet-less Game Onboarding

## The Problem It Solves

Most blockchain games require a wallet before playing.
This creates a massive drop-off funnel:
  "Download game" -> "Install wallet" -> "Buy FLOW" -> "Finally play"

Flow's HybridCustody collapses this to:
  "Download game" -> "Play immediately" -> (assets accumulate) -> "Claim wallet anytime"

## How It Works

1. **Game server creates a child account** (a normal Flow account, keys held by game server)
2. **Player plays** — NFT mints, token rewards all go into the child account
3. **Player creates wallet** (Blocto, Flow Reference Wallet, etc.) — whenever they want
4. **Player links wallet** — `link_to_parent.cdc` transaction signed by BOTH child and parent
5. **Child publishes capabilities to parent** — player's wallet can now see and withdraw assets
6. **Player claims assets** — optionally moves assets from child to their own account

## Important Security Notes

- The game server controls the child account keys — treat these like financial keys
- Store child account private keys in a HSM or secrets manager (never in source code)
- Rate-limit child account creation to prevent abuse
- Child accounts should only hold game assets, never FLOW for fees (use sponsorship instead)

## Verified Contract Addresses

Always verify at: https://developers.flow.com/tools/toolchains/flow-cli/accounts/hybrid-custody
- HybridCustody testnet: check Flow docs for current address
- CapabilityFactory testnet: check Flow docs for current address
- CapabilityFilter testnet: check Flow docs for current address
