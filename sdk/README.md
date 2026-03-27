# @studio/flow-game-sdk

TypeScript SDK wrapping all studio Flow contracts for easy integration.

## Installation

```bash
npm install @studio/flow-game-sdk
```

## Quick Start

```typescript
import { createFlowGameSDK } from "@studio/flow-game-sdk";

const sdk = createFlowGameSDK("testnet");

// Get player NFTs
const nfts = await sdk.nft.getNFTsForAccount("0x1234...");

// Check token balance
const balance = await sdk.token.getBalance("0x1234...");

// Commit/reveal VRF
const { secret, secretHex } = sdk.vrf.generateSecret();
const txId = await sdk.vrf.commit(secret, BigInt(gameId));
// ... wait 1 block ...
await sdk.vrf.reveal(secret, BigInt(gameId));
```

## Modules

| Module | Description |
|--------|-------------|
| `vrf` | Commit/reveal randomness via RandomVRF |
| `nft` | NFT minting, querying, transferring |
| `token` | GameToken balance, transfer |
| `marketplace` | List, buy, and browse NFT listings |

## Network Configuration

Update contract addresses in `sdk/src/network-config.ts` after each deploy.

## Building

```bash
cd sdk
npm install
npm run build
```
