// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// simple nft to represent the
contract DaoMemberShip is ERC721 {
    uint256 nextid = 1;

    // owner => privacy level (used for front parameters)
    mapping(address => uint8) public privacyLevel;

    constructor() ERC721("DaoMemberShip", "DAOM") {}

    // lock transferFrom function
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public pure override {
        revert("transfer is locked");
    }

    // lock safeTransferFrom function
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public pure override {
        revert("transfer is locked");
    }

    function mint(uint8 level) public {
        // only one token per address
        require(balanceOf(msg.sender) == 0, "only one token per address");

        privacyLevel[msg.sender] = level;
        _mint(msg.sender, nextid);
        nextid++;
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "only owner can burn");
        delete privacyLevel[msg.sender];
        _burn(tokenId);
    }

    function setPrivacyLevel(uint8 level) public {
        require(balanceOf(msg.sender) > 0, "only member can set privacy level");
        privacyLevel[msg.sender] = level;
    }
}
