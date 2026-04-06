# ZK Circuit Development Guide

This directory contains zero-knowledge circuit scaffolding for Flow blockchain games.

## Toolchain Requirements

```bash
npm install -g circom snarkjs
npm install circomlib
```

## Directory Structure

```
tools/zk/
├── README.md                      # This guide
└── example-circuit/
    └── move_validity.circom       # Fog-of-war position proof example
```

## Workflow: Circuit to On-Chain Verification

### Step 1: Write your circuit

Use Circom 2.0. See `example-circuit/move_validity.circom` for a fog-of-war example.

### Step 2: Compile the circuit

```bash
circom example-circuit/move_validity.circom --r1cs --wasm --sym -o build/
```

### Step 3: Trusted setup (Powers of Tau)

```bash
# Phase 1 (reusable across circuits)
snarkjs powersoftau new bn128 12 pot12_0000.ptau
snarkjs powersoftau contribute pot12_0000.ptau pot12_final.ptau

# Phase 2 (circuit-specific)
snarkjs groth16 setup build/move_validity.r1cs pot12_final.ptau circuit_0000.zkey
snarkjs zkey contribute circuit_0000.zkey circuit_final.zkey
```

### Step 4: Export Solidity verifier

```bash
snarkjs zkey export solidityverifier circuit_final.zkey ZKVerifier_generated.sol
```

Copy the verifying key values into `cadence/contracts/evm/ZKVerifier.sol`.

### Step 5: Deploy to Flow EVM

```bash
cast deploy cadence/contracts/evm/ZKVerifier.sol --rpc-url https://testnet.evm.nodes.onflow.org
```

### Step 6: Generate and verify proofs

```bash
# Generate witness
node build/move_validity_js/generate_witness.js build/move_validity_js/move_validity.wasm input.json witness.wtns

# Generate proof
snarkjs groth16 prove circuit_final.zkey witness.wtns proof.json public.json

# Verify locally
snarkjs groth16 verify verification_key.json public.json proof.json
```

### Step 7: Call from Cadence

Use `cadence/transactions/evm/verify_zk_proof.cdc` to call `ZKVerifier.verifyProof()` via EVMBridge.

## Production Notes

- Use the Hermez Powers of Tau ceremony for mainnet (supports up to 2^28 constraints)
- Proof generation is CPU-intensive — run in a Web Worker or server-side
- Groth16 verification costs ~800,000 gas on Flow EVM
