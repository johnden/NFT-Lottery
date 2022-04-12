// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Redemption is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter _itemIds;
    struct PairItem {
        uint itemId;
        address tokenContract;
        uint256 amount;
        address prizeContract;
    }

    mapping(uint256 => PairItem) public idToPairItem;

    event PairItemCreated (
        uint indexed itemId,
        address tokenContract,
        uint256 amount,
        address prizeContract
    );

    event PairItemRedempt (
        uint indexed itemId,
        address player,
        uint256 prizeId,
        uint256 amount
    );

    constructor() {}

    function createPair(address tokenContract, uint256 amount, address prizeContract) external onlyOwner {
        // ERC721 prize = ERC721(prizeContract);
        uint256 itemId = _itemIds.current();
        idToPairItem[itemId] =  PairItem(
            itemId,
            tokenContract,
            amount,
            prizeContract
        );
        _itemIds.increment();
        emit PairItemCreated(
            itemId,
            tokenContract,
            amount,
            prizeContract
        );
    }

    function redempt(uint pairIndex, uint256 prizeId) external nonReentrant {
        PairItem storage pair = idToPairItem[pairIndex];
        IERC721 prize = IERC721(pair.prizeContract);
        IERC20 token = IERC20(pair.tokenContract);
        require(prize.ownerOf(prizeId) == msg.sender, "You aren't this prize owner.");
        require(token.allowance(owner(), address(this)) >= pair.amount, "Not enough token amount in Redemption");

        prize.transferFrom(msg.sender, address(this), prizeId);
        token.transferFrom(owner(), msg.sender, pair.amount);

        emit PairItemRedempt(
            pairIndex,
            msg.sender,
            prizeId,
            pair.amount
        );
    }
}