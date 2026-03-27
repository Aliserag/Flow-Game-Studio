// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// GameNFT721: ERC-721 game asset for EVM-native players on Flow EVM.
// Compatible with OpenSea, Blur, and Flow EVM block explorers.
// Metadata stored on IPFS — set baseURI after batch pinning.
//
// RELATIONSHIP TO CADENCE:
// These are separate NFTs from cadence/contracts/core/GameNFT.cdc.
// They serve EVM-native players who use MetaMask / EVM wallets.
// Cross-VM composability via EVMBridge.cdc if needed.

contract GameNFT721 is ERC721URIStorage, ERC721Royalty, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 public maxSupply;
    uint256 public mintPrice;
    string public baseTokenURI;
    bool public revealed;

    // Pre-reveal placeholder URI (for fair-launch drops)
    string public placeholderURI;

    address public minter;

    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event Revealed(string baseURI);

    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner(), "Not minter");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        string memory _placeholderURI,
        address royaltyReceiver,
        uint96 royaltyBps  // e.g., 500 = 5%
    ) ERC721(name, symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        placeholderURI = _placeholderURI;
        minter = msg.sender;
        _setDefaultRoyalty(royaltyReceiver, royaltyBps);
    }

    function mint(address to) external payable onlyMinter returns (uint256) {
        require(_tokenIds.current() < maxSupply, "Max supply reached");
        if (msg.sender != owner()) require(msg.value >= mintPrice, "Insufficient payment");

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _safeMint(to, tokenId);
        emit Minted(to, tokenId, tokenURI(tokenId));
        return tokenId;
    }

    function batchMint(address to, uint256 count) external onlyMinter {
        for (uint256 i = 0; i < count; i++) {
            mint(to);
        }
    }

    // Reveal: set the real base URI after randomized metadata assignment
    function reveal(string memory _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
        revealed = true;
        emit Revealed(_baseURI);
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function withdraw() external onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    // OpenSea contract-level metadata
    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, "collection.json"));
    }

    // Override: return placeholder until revealed
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireOwned(tokenId);
        if (!revealed) return placeholderURI;
        return string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721URIStorage, ERC721Royalty) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal override(ERC721, ERC721URIStorage) returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal override(ERC721, ERC721URIStorage)
    {
        super._increaseBalance(account, amount);
    }
}
