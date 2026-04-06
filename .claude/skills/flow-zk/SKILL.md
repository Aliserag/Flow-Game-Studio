# /flow-zk

Scaffold zero-knowledge proof verification for Flow games via Flow EVM.

## Honest ZK Assessment for Flow

| Layer | ZK Support |
|-------|-----------|
| Cadence VM | None — no ZK precompiles |
| Flow EVM | Full BN254 support (Groth16, PLONK via 0x06/0x07/0x08 precompiles) |

**The pattern**: Generate proof off-chain → verify in `ZKVerifier.sol` on Flow EVM → Cadence reads the result via EVMBridge.

## Usage

```
/flow-zk scaffold --circuit fog-of-war --public-inputs "positionHash,boardHash"
/flow-zk generate-verifier --zkey circuit.zkey
/flow-zk test-proof --inputs "positionHash:0x123..."
```

## Full Workflow

1. **Design circuit** (`tools/zk/your-circuit.circom`)
2. **Compile**: `circom your-circuit.circom --r1cs --wasm --sym`
3. **Trusted setup**: `snarkjs groth16 setup your-circuit.r1cs pot12_final.ptau circuit_final.zkey`
4. **Export verifier**: `snarkjs zkey export solidityverifier circuit_final.zkey ZKVerifier.sol`
5. **Replace verifying key** in `cadence/contracts/evm/ZKVerifier.sol`
6. **Deploy** to Flow EVM testnet
7. **Generate proof** (client-side): `snarkjs groth16 prove circuit_final.zkey input.json proof.json public.json`
8. **Verify on-chain**: call `ZKVerifier.verifyProof()` via EVMBridge from a Cadence transaction

## Good ZK Use Cases for Games

| Use case | What's private | What's public |
|----------|---------------|---------------|
| Fog-of-war movement | Player position | Position commitment, board hash |
| Sealed card hand | Cards held | Deck commitment, hand hash |
| Hidden resource count | Resource amount | "Has at least N resources" (range proof) |
| Provably fair RNG (pre-Flow VRF) | Player seed | Combined entropy hash |

## Notes

- Trusted setup requires a Powers of Tau ceremony — use the Hermez ceremony for production (ptau with 2^28 constraints)
- Proof generation is CPU-intensive — do it in a Web Worker or server-side, not in the game main thread
- Flow EVM gas for a Groth16 verification is approximately 800,000 gas (roughly equivalent cost to ETH mainnet)
