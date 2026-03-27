# Flow EVM Integration Guide

## Overview

Flow EVM is an EVM-compatible execution environment running natively inside Flow.
It is NOT a sidechain — it shares the same validator set and finality as Cadence.

## Key Concepts

- **COA (Cadence-Owned Account)**: An EVM account controlled by a Cadence resource.
  This is the recommended way to interact with EVM from Cadence.
- **Cross-VM calls**: Synchronous and atomic within a single Flow transaction.
- **Gas**: Paid in FLOW, not ETH.

## RPC Endpoints

| Network | Endpoint | Chain ID |
|---------|----------|----------|
| Testnet | `https://testnet.evm.nodes.onflow.org` | 545 |
| Mainnet | `https://mainnet.evm.nodes.onflow.org` | 747 |

## Tooling

- **Hardhat**: Configure with Flow EVM RPC in `hardhat.config.js`
- **Foundry/Cast**: Use `--rpc-url https://testnet.evm.nodes.onflow.org`
- **MetaMask**: Add Flow EVM as a custom network using the chain IDs above

## COA Lifecycle

1. Create COA: `EVMBridge.createEVMAccount(signer:)` — stores in `/storage/evm`
2. Fund COA: Send FLOW to the EVM address
3. Call contracts: `EVMBridge.callContract(signer:to:data:gasLimit:value:)`
4. Withdraw: Use `coa.withdraw(balance:)` to move FLOW back to Cadence

## ABI Encoding in Cadence

Use `EVM.encodeABIWithSignature("transfer(address,uint256)", [recipient, amount])` to
generate calldata without leaving Cadence.

## Security Considerations

- COA private key is the Cadence account key — protect it accordingly
- EVM contracts deployed to Flow EVM are visible on-chain; audit them
- Cross-VM calls can fail silently if not checking `result.status`
- Always assert `result.status == EVM.Status.successful`

## References

- Flow EVM docs: https://developers.flow.com/evm/about
- FLIP-223 (Flow EVM spec): https://github.com/onflow/flips/blob/main/protocol/20231116-evm-support.md
