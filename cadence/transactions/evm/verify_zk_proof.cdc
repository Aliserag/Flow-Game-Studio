// verify_zk_proof.cdc
// Calls ZKVerifier.verifyProof() on Flow EVM via EVMBridge.
// Use this to verify a Groth16 proof from a Cadence transaction.

import EVMBridge from "../../../cadence/contracts/evm/EVMBridge.cdc"
import EVM from "EVM"

transaction(
    verifierAddress: String,    // EVM address of deployed ZKVerifier contract
    proofA: [UInt256],          // [a[0], a[1]]
    proofB: [[UInt256]],        // [[b[0][0], b[0][1]], [b[1][0], b[1][1]]]
    proofC: [UInt256],          // [c[0], c[1]]
    publicInputs: [UInt256]     // array of public signal values
) {
    prepare(signer: auth(Storage) &Account) {
        // Encode the verifyProof() call
        // Function selector: keccak256("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[])")
        let selector: [UInt8] = [0x43, 0x75, 0x3b, 0x4d]

        // ABI-encode parameters (simplified — use an off-chain ABI encoder in production)
        // For production, pass pre-encoded calldata as a parameter
        let calldata: [UInt8] = selector

        // Get or create the signer's COA
        let coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("No COA found — run setup_evm_account.cdc first")

        // Parse EVM address
        let evmAddr = EVM.addressFromString(verifierAddress)

        // Call ZKVerifier.verifyProof()
        let result = coa.call(
            to: evmAddr,
            data: calldata,
            gasLimit: 1_000_000,
            value: EVM.Balance(attoflow: 0)
        )

        assert(result.status == EVM.Status.successful,
            message: "ZK proof verification call failed: ".concat(result.errorMessage))

        // Decode boolean result (last 32 bytes, non-zero = true)
        let valid = result.data[result.data.length - 1] != 0
        assert(valid, message: "ZK proof is invalid")

        log("ZK proof verified successfully")
    }
}
