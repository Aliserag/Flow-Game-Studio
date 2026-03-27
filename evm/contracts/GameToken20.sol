// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// GameToken20: ERC-20 game currency for EVM-native players.
// Separate from Cadence GameToken.cdc — serves EVM wallet holders.
// ERC20Permit enables gasless approvals (EIP-2612).

contract GameToken20 is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    uint256 public immutable maxSupply;
    address public minter;

    event MinterUpdated(address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner(), "Not minter");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        address _minter
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        minter = _minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
        emit MinterUpdated(_minter);
    }
}
