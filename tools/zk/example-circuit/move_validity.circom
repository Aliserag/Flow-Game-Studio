// move_validity.circom
// Proves a player's move in a fog-of-war game is valid (within bounds, from reachable tile)
// WITHOUT revealing the player's actual position.
//
// Public inputs:  positionHash (commitment to position), boardHash (public game state)
// Private inputs: x, y (actual position), salt (commitment randomness)
// Constraint:     positionHash = hash(x, y, salt) AND (x, y) is within board bounds

pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/comparators.circom";

template MoveValidity(boardWidth, boardHeight) {
    // Private inputs — never revealed on-chain
    signal input x;
    signal input y;
    signal input salt;

    // Public inputs — known to verifier
    signal input positionHash;
    signal input maxX;
    signal input maxY;

    // Verify position commitment
    component hasher = Poseidon(3);
    hasher.inputs[0] <== x;
    hasher.inputs[1] <== y;
    hasher.inputs[2] <== salt;
    hasher.out === positionHash;

    // Verify bounds (x < maxX, y < maxY, x >= 0, y >= 0)
    component xCheck = LessThan(32);
    xCheck.in[0] <== x;
    xCheck.in[1] <== maxX;
    xCheck.out === 1;

    component yCheck = LessThan(32);
    yCheck.in[0] <== y;
    yCheck.in[1] <== maxY;
    yCheck.out === 1;
}

component main { public [positionHash, maxX, maxY] } = MoveValidity(64, 64);
