# Flow EVM VRF Guide

## The cadenceArch Precompile

Flow EVM ships with a special precompile at `0x0000000000000000000000010000000000000001`
called `cadenceArch`. It bridges Cadence runtime data into EVM execution:

- `revertibleRandom()` → uint64 from Flow's random beacon for the current block
- `flowBlockHeight()` → current Flow block height

**ALWAYS verify the precompile address from Flow docs before mainnet deploy.**
The address is fixed across emulator/testnet/mainnet but confirm at:
https://developers.flow.com/evm/cadence-arch

## Why Commit/Reveal is Still Required

`revertibleRandom()` is called "revertible" because a validator can observe the random
value before proposing their block. If they dislike the value (e.g., it would cause their
in-game character to lose), they can revert the block and try again on the next one.

The commit/reveal scheme breaks this: the player commits to their choice BEFORE the random
value for the reveal block is known. By the time of reveal, the commit block is sealed
and immutable — the validator's window to bias is gone.

## Deployment

Deploy `FlowEVMVRF.sol` once and reuse across all game contracts:

```bash
# Using Hardhat with Flow EVM network config
npx hardhat deploy --network flow-testnet
# Or using cast:
cast send --rpc-url https://testnet.evm.nodes.onflow.org \
  --private-key $PRIVATE_KEY \
  --create $(cat out/FlowEVMVRF.bin)
```
