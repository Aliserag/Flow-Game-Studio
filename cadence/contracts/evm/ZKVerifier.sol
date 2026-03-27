// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ZKVerifier: Groth16 proof verifier using BN254 curve precompiles.
// This is a TEMPLATE — replace the verifying key with output from snarkjs.
//
// Workflow:
// 1. Write circuit in Circom
// 2. Run trusted setup: `snarkjs groth16 setup`
// 3. Export verifying key: `snarkjs zkey export solidityverifier`
// 4. Replace the VerifyingKey constants below with output from step 3
// 5. Deploy to Flow EVM testnet
// 6. Call verifyProof() from Cadence via EVMBridge
//
// BN254 precompile addresses (same on all EVM networks including Flow EVM):
// 0x06 = ecAdd
// 0x07 = ecMul
// 0x08 = ecPairing (the heavy lifting for Groth16)

contract ZKVerifier {

    // --- REPLACE THESE WITH SNARKJS OUTPUT ---
    // Run: snarkjs zkey export solidityverifier circuit.zkey verifier.sol
    // Then copy the VerifyingKey struct values here

    struct VerifyingKey {
        uint256[2] alpha1;
        uint256[2][2] beta2;
        uint256[2][2] gamma2;
        uint256[2][2] delta2;
        uint256[2][] ic;  // one per public input + 1
    }

    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    event ProofVerified(address indexed submitter, bytes32 indexed proofHash, bool valid);

    // Stores verified proof hashes to prevent replay
    mapping(bytes32 => bool) public verifiedProofs;

    function getVerifyingKey() internal pure returns (VerifyingKey memory vk) {
        // REPLACE: paste snarkjs output here
        // vk.alpha1 = [uint256(xxx), uint256(yyy)];
        // vk.beta2 = [[uint256(xxx), uint256(yyy)], [uint256(xxx), uint256(yyy)]];
        // etc.
        revert("Verifying key not configured — replace with snarkjs output");
    }

    // Verify a Groth16 proof with public inputs
    // inputs: array of public signal values (in same order as circuit outputs)
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory inputs
    ) public returns (bool) {
        VerifyingKey memory vk = getVerifyingKey();
        require(inputs.length + 1 == vk.ic.length, "Wrong number of public inputs");

        // Compute linear combination of IC points
        uint256[3] memory vkX = [vk.ic[0][0], vk.ic[0][1], uint256(1)];
        for (uint256 i = 0; i < inputs.length; i++) {
            require(inputs[i] < snarkScalarField(), "Input >= scalar field");
            uint256[3] memory scaled = ecMul([vk.ic[i+1][0], vk.ic[i+1][1]], inputs[i]);
            vkX = ecAdd(vkX, scaled);
        }

        // Pairing check: e(proof.A, proof.B) == e(alpha1, beta2) * e(vkX, gamma2) * e(proof.C, delta2)
        bool valid = pairingCheck(
            [a[0], a[1]],
            b,
            vk.alpha1,
            vk.beta2,
            [vkX[0], vkX[1]],
            vk.gamma2,
            c,
            vk.delta2
        );

        bytes32 proofHash = keccak256(abi.encodePacked(a, b, c, inputs));
        require(!verifiedProofs[proofHash], "Proof already used (replay protection)");

        if (valid) {
            verifiedProofs[proofHash] = true;
        }

        emit ProofVerified(msg.sender, proofHash, valid);
        return valid;
    }

    function snarkScalarField() internal pure returns (uint256) {
        return 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    }

    // EVM precompile wrappers
    function ecAdd(uint256[3] memory p1, uint256[3] memory p2) internal view returns (uint256[3] memory r) {
        uint256[4] memory input = [p1[0], p1[1], p2[0], p2[1]];
        bool success;
        assembly {
            success := staticcall(gas(), 0x06, input, 0x80, r, 0x40)
        }
        require(success, "ecAdd precompile failed");
        r[2] = 1;
    }

    function ecMul(uint256[2] memory p, uint256 s) internal view returns (uint256[3] memory r) {
        uint256[3] memory input = [p[0], p[1], s];
        bool success;
        assembly {
            success := staticcall(gas(), 0x07, input, 0x60, r, 0x40)
        }
        require(success, "ecMul precompile failed");
        r[2] = 1;
    }

    function pairingCheck(
        uint256[2] memory a1, uint256[2][2] memory a2,
        uint256[2] memory b1, uint256[2][2] memory b2,
        uint256[2] memory c1, uint256[2][2] memory c2,
        uint256[2] memory d1, uint256[2][2] memory d2
    ) internal view returns (bool) {
        uint256[24] memory input = [
            a1[0], a1[1], a2[0][0], a2[0][1], a2[1][0], a2[1][1],
            b1[0], b1[1], b2[0][0], b2[0][1], b2[1][0], b2[1][1],
            c1[0], c1[1], c2[0][0], c2[0][1], c2[1][1], c2[1][0],
            d1[0], d1[1], d2[0][0], d2[0][1], d2[1][0], d2[1][1]
        ];
        uint256[1] memory result;
        bool success;
        assembly {
            success := staticcall(gas(), 0x08, input, 0x300, result, 0x20)
        }
        require(success, "ecPairing precompile failed");
        return result[0] == 1;
    }
}
