// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockToken — Simple mintable ERC-20 for local testing.
/// @dev Deploy this first, then deploy PrizePool with this token's address.
contract MockToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Mint additional tokens. Only callable by owner.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
