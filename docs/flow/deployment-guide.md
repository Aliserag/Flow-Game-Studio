# Flow Deployment Guide

How to take an example game from the local emulator to Flow testnet (and eventually mainnet).

---

## 1. Create a Testnet Account

Flow testnet accounts are free and created through the **Flow Faucet**.

1. Go to **https://faucet.flow.com/fund-account**
2. Click **Create Account**
3. The faucet generates a key pair in your browser and creates an account on testnet
4. **Save your private key immediately** — it is shown only once
5. Copy the account address (e.g. `0x1234abcd5678ef90`)

> The faucet also gives you **1000 test FLOW tokens** automatically. You can return to
> request more at any time — testnet FLOW has no real value.

---

## 2. Store Your Key Securely

Never commit testnet (or mainnet) keys. The `.gitignore` already excludes `*.pkey` files:

```bash
# Create the key file (paste your private key from the faucet)
echo "YOUR_PRIVATE_KEY_HEX" > .flow-testnet.pkey
chmod 600 .flow-testnet.pkey
```

---

## 3. Update `flow.json`

In the example's `flow.json`, find the `testnet-account` entry and update it:

```json
"accounts": {
  "emulator-account": {
    "address": "f8d6e0586b0a20c7",
    "key": {
      "type": "hex",
      "privateKey": "2eae2f31cb5b756151fa11d82949763b73e28b92f8cc26c97d5bf4620e60d8b6"
    }
  },
  "testnet-account": {
    "address": "YOUR_TESTNET_ADDRESS",
    "key": {
      "type": "file",
      "location": ".flow-testnet.pkey"
    }
  }
}
```

Replace `YOUR_TESTNET_ADDRESS` with the address from the faucet (without the `0x` prefix).

---

## 4. Deploy Contracts to Testnet

```bash
# From the example's root directory (where flow.json lives):
flow project deploy --network testnet
```

On success, the CLI prints each contract name and its deployed address. Record these — you'll need them for the FCL config:

```
CoinFlip -> 0xYOUR_ADDRESS (txhash...)
```

---

## 5. Update the FCL Config

Each example has an `fcl-config.ts` (or `fcl-config.js`) in `client/src/`. Change the
`accessNode.api` and `discovery.wallet` from emulator endpoints to testnet:

```typescript
// client/src/fcl-config.ts
import * as fcl from "@onflow/fcl"

fcl.config({
  "app.detail.title": "My Flow Game",
  "app.detail.icon": "https://yourapp.com/icon.png",

  // ── Testnet ────────────────────────────────────────────────
  "flow.network":        "testnet",
  "accessNode.api":      "https://rest-testnet.onflow.org",
  "discovery.wallet":    "https://fcl-discovery.onflow.org/testnet/authn",

  // Contract address from step 4
  "0xCoinFlip":          "YOUR_TESTNET_ADDRESS",
})
```

> **Emulator config** (for local dev — keep this commented in for easy switching):
> ```typescript
> "flow.network":     "local",
> "accessNode.api":   "http://localhost:8888",
> "discovery.wallet": "http://localhost:8701/fcl/authn",
> "0xCoinFlip":       "0xf8d6e0586b0a20c7",
> ```

---

## 6. Update Inline Cadence Scripts

Inline Cadence scripts in the React components import contracts with hardcoded
emulator addresses like `import CoinFlip from 0xf8d6e0586b0a20c7`. Replace these
with your testnet address:

```typescript
// Before (emulator)
const SCRIPT = `
  import CoinFlip from 0xf8d6e0586b0a20c7
  ...
`

// After (testnet)
const SCRIPT = `
  import CoinFlip from 0xYOUR_TESTNET_ADDRESS
  ...
`
```

**Tip:** Define the address as a constant at the top of the file and reference it
everywhere — easier to update and harder to miss one:

```typescript
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS ?? "0xf8d6e0586b0a20c7"
```

Then in `vite.config.ts` or `.env.local`:
```bash
# .env.local (gitignored)
VITE_CONTRACT_ADDRESS=0xYOUR_TESTNET_ADDRESS
```

---

## 7. Update the Sponsor Service (coin-flip only)

The gasless transaction sponsor service needs a testnet payer account with real
test FLOW tokens. Create a dedicated payer account via the faucet (separate from
your deployer account) and set environment variables:

```bash
# sponsor-service/.env (gitignored — create this file)
PAYER_ADDRESS=0xYOUR_PAYER_TESTNET_ADDRESS
PAYER_PRIVATE_KEY=YOUR_PAYER_PRIVATE_KEY
```

Then start the service:
```bash
cd examples/coin-flip/sponsor-service
PAYER_ADDRESS=0x... PAYER_PRIVATE_KEY=... npx ts-node server.ts
```

---

## 8. Verify the Deployment

### Flow Diver (testnet block explorer)

Browse your deployed contracts and transactions at:
**https://www.flowdiver.io/?network=testnet**

Search for your account address to see:
- Deployed contracts
- All transactions
- Account storage

### Query via Flow CLI

```bash
# Check totalPools on testnet
flow scripts execute - --network testnet <<'EOF'
import CoinFlip from 0xYOUR_TESTNET_ADDRESS
access(all) fun main(): UInt64 { return CoinFlip.totalPools }
EOF
```

---

## Standard Contract Addresses

These are pre-deployed by the Flow team — you don't deploy them yourself.

### Testnet

| Contract | Address |
|----------|---------|
| NonFungibleToken | `0x631e88ae7f1d7c20` |
| MetadataViews | `0x631e88ae7f1d7c20` |
| FungibleToken | `0x9a0766d93b6608b7` |
| FlowToken | `0x7e60df042a9c0868` |
| RandomBeaconHistory | `0x8c5303eaa26202d6` |

### Mainnet

| Contract | Address |
|----------|---------|
| NonFungibleToken | `0x1d7e57aa55817448` |
| MetadataViews | `0x1d7e57aa55817448` |
| FungibleToken | `0xf233dcee88fe0abe` |
| FlowToken | `0x1654653399040a61` |
| RandomBeaconHistory | `0xd7431fd358660d73` |

---

## Useful Links

| Resource | URL |
|----------|-----|
| **Testnet Faucet** (create account + get FLOW) | https://faucet.flow.com/fund-account |
| **Flow Diver** (testnet block explorer) | https://www.flowdiver.io/?network=testnet |
| **Flow Playground** (browser-based Cadence sandbox) | https://play.flow.com/ |
| **FCL Documentation** | https://developers.flow.com/tools/clients/fcl-js |
| **Cadence Language Reference** | https://cadence-lang.org/docs |
| **Flow CLI Reference** | https://developers.flow.com/tools/flow-cli |
| **Flow Developer Discord** | https://discord.gg/flow |
| **Standard Contracts (testnet)** | https://developers.flow.com/networks/flow-networks/accessing-testnet |

---

## Testnet → Mainnet

Mainnet deployment requires extra care:

1. **Security audit** — have at least one external reviewer inspect the contracts
2. **Multisig** — use the patterns in `cadence/contracts/governance/Multisig.cdc`
3. **Emergency pause** — deploy `EmergencyPause.cdc` before going live
4. **Staged rollout** — use `cadence/contracts/systems/VersionRegistry.cdc` for upgrades

The Flow team offers a **testnet → mainnet review** through the [Flow Ecosystem Fund](https://flow.com/ecosystem-fund) for projects that need support.
