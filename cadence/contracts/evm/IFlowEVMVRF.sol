// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Interface for the Flow CadenceArch precompile.
// This precompile is deployed at a fixed address on all Flow EVM networks.
// It bridges Flow Cadence runtime data into EVM execution context.
//
// VERIFY address at: https://developers.flow.com/evm/cadence-arch
// Current address: 0x0000000000000000000000010000000000000001
interface ICadenceArch {
    // Returns the random source for the CURRENT block from Flow's random beacon.
    // IMPORTANT: This is revertible — a validator seeing an unfavorable result
    // can abort their block proposal, biasing outcomes over many rounds.
    // NEVER use this directly for high-value randomness.
    // ALWAYS wrap in a commit/reveal scheme (see FlowEVMVRF.sol).
    function revertibleRandom() external view returns (uint64);

    // Returns the Flow block height at which this EVM transaction is executing.
    function flowBlockHeight() external view returns (uint64);
}
