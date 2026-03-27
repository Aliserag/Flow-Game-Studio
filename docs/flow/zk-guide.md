# ZK on Flow: Complete Guide

## Architecture

```
[Off-chain: circom + snarkjs]     [Flow EVM: ZKVerifier.sol]     [Cadence: game contract]
  Player generates proof    →    Proof verified on-chain    →    Contract reads result
  (private inputs hidden)        (BN254 precompiles)              via EVMBridge.call()
```

## What ZK Enables in Games

**Without ZK**: Players must reveal game state to prove moves are valid.
**With ZK**: Players prove moves are valid without revealing private state.

Examples:
- Chess: prove a move is legal without revealing your intended strategy
- Card games: prove your hand composition without showing cards
- Hidden information games: prove resource counts satisfy conditions without revealing exact amounts

## Toolchain

- **Circom 2.0**: Circuit description language (npm: circom)
- **snarkjs**: Proof generation and verification (npm: snarkjs)
- **circomlib**: Standard circuit library (Poseidon hash, comparators, etc.)
- **Hardhat/cast**: Deploy ZKVerifier.sol to Flow EVM

## Setup Commands

```bash
npm install -g circom snarkjs
# Compile circuit
circom tools/zk/your-circuit.circom --r1cs --wasm --sym -o build/
# Download Powers of Tau (phase 1)
snarkjs powersoftau new bn128 12 pot12_0000.ptau
snarkjs powersoftau contribute pot12_0000.ptau pot12_final.ptau
# Phase 2 (circuit-specific)
snarkjs groth16 setup build/your-circuit.r1cs pot12_final.ptau circuit_0000.zkey
snarkjs zkey contribute circuit_0000.zkey circuit_final.zkey
snarkjs zkey export solidityverifier circuit_final.zkey ZKVerifier.sol
```
