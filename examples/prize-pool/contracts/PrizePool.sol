// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title PrizePool — Accepts ERC-20 deposits for a wagering round.
/// @dev Owned by a Cadence Owned Account (COA). Only owner can close round + release prize.
/// Players deposit any amount. Winner takes all.
/// The COA owner is set at deploy time and transfers ownership to the Cadence side
/// after `setup_coa.cdc` is run and `transferOwnership` is called.
contract PrizePool is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;        // Prize token
    uint256 public roundId;     // Increments per round
    bool public isOpen;         // True while accepting deposits

    struct Deposit {
        address player;
        uint256 amount;
    }

    // roundId => player => amount
    mapping(uint256 => mapping(address => uint256)) public deposits;
    // roundId => list of depositors (for iteration)
    mapping(uint256 => address[]) public depositors;
    mapping(uint256 => uint256) public totalDeposited;

    event Deposited(uint256 indexed roundId, address indexed player, uint256 amount);
    event RoundClosed(uint256 indexed roundId, address indexed winner, uint256 prize);
    event RoundOpened(uint256 indexed roundId);

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
        roundId = 0;
        isOpen = true;
        emit RoundOpened(0);
    }

    /// @notice Deposit tokens into the current round. Must approve first.
    function deposit(uint256 amount) external {
        require(isOpen, "Round closed");
        require(amount > 0, "Amount must be > 0");
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (deposits[roundId][msg.sender] == 0) {
            depositors[roundId].push(msg.sender);
        }
        deposits[roundId][msg.sender] += amount;
        totalDeposited[roundId] += amount;
        emit Deposited(roundId, msg.sender, amount);
    }

    /// @notice Close current round, release prize to winner. Only callable by owner (COA).
    function closeRound(address winner) external onlyOwner {
        require(isOpen, "Already closed");
        require(depositors[roundId].length > 0, "No players");
        isOpen = false;
        uint256 prize = totalDeposited[roundId];
        token.safeTransfer(winner, prize);
        emit RoundClosed(roundId, winner, prize);
    }

    /// @notice Start a new round. Only callable by owner.
    function openNewRound() external onlyOwner {
        require(!isOpen, "Current round still open");
        roundId++;
        isOpen = true;
        emit RoundOpened(roundId);
    }

    /// @notice Get all depositors for a round (for VRF selection in Cadence).
    function getDepositors(uint256 _roundId) external view returns (address[] memory) {
        return depositors[_roundId];
    }

    /// @notice Get deposit amount for a player in a round.
    function getDeposit(uint256 _roundId, address player) external view returns (uint256) {
        return deposits[_roundId][player];
    }
}
