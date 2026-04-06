// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FlowEVMVRF.sol";

// Example: Coin flip game using FlowEVMVRF
contract CoinFlip {
    FlowEVMVRF public immutable vrf;

    struct Flip {
        address player;
        bool headsGuess;   // true = heads, false = tails
        bool resolved;
        bool won;
    }

    mapping(uint256 => Flip) public flips;
    uint256 public nextFlipId;

    event FlipCommitted(uint256 flipId, address player);
    event FlipResolved(uint256 flipId, address player, bool heads, bool won);

    constructor(address vrfAddress) {
        vrf = FlowEVMVRF(vrfAddress);
    }

    // Step 1: player commits (guesses heads/tails + secret)
    function commitFlip(uint256 secret, bool headsGuess) external returns (uint256 flipId) {
        flipId = nextFlipId++;
        flips[flipId] = Flip({ player: msg.sender, headsGuess: headsGuess, resolved: false, won: false });
        vrf.commit(secret, flipId);
        emit FlipCommitted(flipId, msg.sender);
    }

    // Step 2: reveal after at least 1 block
    function revealFlip(uint256 secret, uint256 flipId) external {
        Flip storage flip = flips[flipId];
        require(flip.player == msg.sender, "Not your flip");
        require(!flip.resolved, "Already resolved");

        uint256 raw = vrf.reveal(secret, flipId);
        uint256 result = vrf.boundedRandom(raw, 2);
        bool isHeads = result == 0;
        flip.resolved = true;
        flip.won = (isHeads == flip.headsGuess);
        emit FlipResolved(flipId, msg.sender, isHeads, flip.won);
    }
}
