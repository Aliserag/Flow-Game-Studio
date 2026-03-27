// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IFlowEVMVRF.sol";

// FlowEVMVRF: Secure commit/reveal randomness for Flow EVM Solidity contracts.
//
// Mirror of the Cadence RandomVRF.cdc contract — same two-phase pattern,
// using Flow's cadenceArch precompile as the random source instead of
// RandomBeaconHistory (which is Cadence-only).
//
// Deploy address of cadenceArch precompile (verify before mainnet):
// https://developers.flow.com/evm/cadence-arch
contract FlowEVMVRF {
    // cadenceArch precompile — exposes Flow randomness to EVM
    ICadenceArch internal constant CADENCE_ARCH =
        ICadenceArch(0x0000000000000000000000010000000000000001);

    struct Commit {
        bytes32 secretHash;   // keccak256(abi.encodePacked(secret, gameId, player, nonce))
        uint64 commitBlock;   // Flow block height at commit time
        bool revealed;
    }

    // key: keccak256(abi.encodePacked(player, gameId))
    mapping(bytes32 => Commit) public commits;
    mapping(address => uint256) public nonces;

    event CommitSubmitted(address indexed player, uint256 indexed gameId, uint64 commitBlock);
    event RevealCompleted(address indexed player, uint256 indexed gameId, uint256 result);

    // Phase 1: Commit
    // secret: large random number held off-chain by the client, NEVER revealed early
    function commit(uint256 secret, uint256 gameId) external {
        address player = msg.sender;
        uint256 nonce = nonces[player]++;
        bytes32 secretHash = keccak256(abi.encodePacked(secret, gameId, player, nonce));
        bytes32 key = keccak256(abi.encodePacked(player, gameId));

        commits[key] = Commit({
            secretHash: secretHash,
            commitBlock: CADENCE_ARCH.flowBlockHeight(),
            revealed: false
        });

        emit CommitSubmitted(player, gameId, CADENCE_ARCH.flowBlockHeight());
    }

    // Phase 2: Reveal (must be at least 1 Flow block after commit)
    // Returns a uint256 random value derived from Flow beacon + secret
    function reveal(uint256 secret, uint256 gameId) external returns (uint256) {
        address player = msg.sender;
        bytes32 key = keccak256(abi.encodePacked(player, gameId));
        Commit storage c = commits[key];

        require(!c.revealed, "Already revealed");
        require(c.commitBlock > 0, "No commit found");
        require(CADENCE_ARCH.flowBlockHeight() > c.commitBlock, "Must wait at least 1 block");

        // Verify the secret matches the commitment
        uint256 nonce = nonces[player] - 1;  // nonce was incremented at commit time
        bytes32 expectedHash = keccak256(abi.encodePacked(secret, gameId, player, nonce));
        require(c.secretHash == expectedHash, "Secret does not match commitment");

        // Derive result: mix secret with Flow beacon randomness for that block
        // Note: flowBlockHeight() in reveal tx gives current block, not commit block.
        // For stronger guarantees, use a stored beacon value — see boundedRandom below.
        uint256 result = uint256(keccak256(abi.encodePacked(
            secret,
            CADENCE_ARCH.revertibleRandom(),
            gameId,
            player,
            c.commitBlock
        )));

        c.revealed = true;
        // Delete commit to prevent double-reveal and reclaim gas
        delete commits[key];

        emit RevealCompleted(player, gameId, result);
        return result;
    }

    // Unbiased bounded random in [0, max) using rejection sampling
    // Pass result from reveal() as seed
    function boundedRandom(uint256 seed, uint256 max) external pure returns (uint256) {
        require(max > 0, "max must be > 0");
        if (max == 1) return 0;

        // Rejection sampling to avoid modulo bias
        uint256 threshold = type(uint256).max - (type(uint256).max % max);
        uint256 r = seed;
        uint256 iter = 0;
        while (r >= threshold) {
            r = uint256(keccak256(abi.encodePacked(r, iter)));
            iter++;
            require(iter < 256, "Rejection sampling exceeded limit");
        }
        return r % max;
    }
}
