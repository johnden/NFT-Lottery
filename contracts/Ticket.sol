// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ticket is ERC721A, Ownable {
  constructor(address lotteryContract) ERC721A("Ticket", "T") {
    transferOwnership(lotteryContract);
  }

  function mint(address owner, uint256 quantity) external payable onlyOwner{
    // _safeMint's second argument now takes in a quantity, not a tokenId.
    _safeMint(owner, quantity);
  }
}