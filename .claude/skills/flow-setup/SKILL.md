---
name: flow-setup
description: "Configure the Flow blockchain development environment. Installs Flow CLI, creates testnet account, configures flow.json, sets up FCL client, and verifies the full stack is working."
argument-hint: "[network: emulator|testnet|mainnet] (default: emulator)"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, WebSearch, WebFetch
---

# /flow-setup

Configures a complete Flow blockchain development environment for this game studio.

## Steps

### 1. Detect what's already installed

Run:
```bash
flow version 2>/dev/null && echo "Flow CLI: installed" || echo "Flow CLI: MISSING"
node --version 2>/dev/null && echo "Node: installed" || echo "Node: MISSING"
```

Report findings. Do not proceed until Flow CLI is installed.

### 2. If Flow CLI missing — provide install instructions

**macOS:**
```bash
brew install flow-cli
```
**Linux/Windows:**
```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
```
Tell user to re-run `/flow-setup` after installing.

### 3. Verify flow.json exists

Check for `flow.json` in project root.
- If missing: ask user which network to target (emulator/testnet/mainnet)
- The template is at `flow.json` — it should already exist from plan Phase 1.

### 4. Network-specific setup

**Emulator (default):**
```bash
flow emulator start --log-format=text &
sleep 2
flow accounts create --network emulator
```

**Testnet:**
1. Direct user to https://testnet-faucet.onflow.org to create an account and get FLOW tokens
2. Ask for their testnet address
3. Ask for their private key (remind them: never commit to git)
4. Write to `.env` (not `.env.example`)

### 5. Deploy contracts to emulator (if network=emulator)

```bash
flow project deploy --network emulator
```

Expected output: each contract in `flow.json` shows "deployed".

If any contract fails:
- Read the error
- Check `docs/flow-reference/VERSION.md` for known issues
- Fix and retry

### 6. Verify by running tests

```bash
flow test cadence/tests/
```

Report pass/fail counts.

### 7. FCL Setup (if game has a JS/TS client)

Check for `package.json` in project root or `src/`:
- If found, ask: "Should I configure FCL for your game client?"
- If yes:
  ```bash
  npm install @onflow/fcl @onflow/types
  ```
  Create `src/flow/config.js` with FCL initialization using `.env` values.

### 8. Summary

Report:
- Flow CLI version
- Network configured
- Contracts deployed (list)
- Tests passing
- Next step: `/flow-nft` to create your first game NFT
