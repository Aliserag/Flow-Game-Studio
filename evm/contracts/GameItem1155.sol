// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// GameItem1155: ERC-1155 multi-token for consumables, crafting materials, and bundles.
// More gas-efficient than ERC-721 for fungible game items (potions, materials, keys).
// Each token ID represents a distinct item type; balances represent quantities held.

contract GameItem1155 is ERC1155Supply, Ownable {
    mapping(uint256 => uint256) public maxSupplyPerToken;
    mapping(uint256 => string) private _tokenURIs;
    address public minter;

    event ItemMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event ItemTypeDefined(uint256 indexed tokenId, uint256 maxSupply, string uri);

    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner(), "Not minter");
        _;
    }

    constructor(string memory baseUri) ERC1155(baseUri) Ownable(msg.sender) {
        minter = msg.sender;
    }

    // Define a new item type before minting
    function defineItemType(uint256 tokenId, uint256 _maxSupply, string memory _uri) external onlyOwner {
        maxSupplyPerToken[tokenId] = _maxSupply;
        _tokenURIs[tokenId] = _uri;
        emit ItemTypeDefined(tokenId, _maxSupply, _uri);
    }

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyMinter {
        uint256 maxSup = maxSupplyPerToken[tokenId];
        if (maxSup > 0) {
            require(totalSupply(tokenId) + amount <= maxSup, "Exceeds token max supply");
        }
        _mint(to, tokenId, amount, data);
        emit ItemMinted(to, tokenId, amount);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyMinter {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 maxSup = maxSupplyPerToken[ids[i]];
            if (maxSup > 0) {
                require(totalSupply(ids[i]) + amounts[i] <= maxSup, "Exceeds token max supply");
            }
        }
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenUri = _tokenURIs[tokenId];
        if (bytes(tokenUri).length > 0) return tokenUri;
        return super.uri(tokenId);
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }
}
