// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockLoot
 * @dev A simplified version of Loot NFT for testing governance
 */
contract MockLoot is ERC721Enumerable, Ownable {
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 8000; // Same as original Loot

    constructor() ERC721("Mock Loot", "MLOOT") Ownable(msg.sender) {
        _tokenIdCounter = 1; // Start from ID 1 like original Loot
    }

    /**
     * @dev Mint a new Loot NFT
     * @param to Address to mint the NFT to
     */
    function mint(address to) external {
        require(_tokenIdCounter <= MAX_SUPPLY, "Max supply reached");
        _safeMint(to, _tokenIdCounter);
        _tokenIdCounter++;
    }

    /**
     * @dev Mint multiple Loot NFTs at once
     * @param to Address to mint the NFTs to
     * @param amount Number of NFTs to mint
     */
    function mintMultiple(address to, uint256 amount) external {
        require(_tokenIdCounter + amount - 1 <= MAX_SUPPLY, "Would exceed max supply");
        
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(to, _tokenIdCounter);
            _tokenIdCounter++;
        }
    }

    /**
     * @dev Override to make it compliant with the original Loot interface
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked("Mock Loot #", _toString(tokenId)));
    }

    /**
     * @dev Simple conversion from uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}