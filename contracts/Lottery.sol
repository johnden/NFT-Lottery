// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Ticket.sol";


contract Lottery is VRFConsumerBaseV2, Ownable, ReentrancyGuard {
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsAwarded;

  uint64 s_subscriptionId;

  address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

  address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

  bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

  uint32 callbackGasLimit = 1000000;

  uint16 requestConfirmations = 3;

  uint32 numWords =  1;

  uint256[] public s_randomWords;
  uint256 public s_requestId;

  struct LotteryItem {
    uint itemId;
    address ticketContract;
    uint256 price;
    uint256 winnerId;
    address prizeContract;
    uint256 prizeId;
    address payable winner;
    uint256 currentCount;
    uint256 numberLimited;
    uint256 requestId;
    bool awarded;
    bool claimed;

  }
  mapping(uint256 => LotteryItem) public idToLotteryItem;

  event LotteryItemCreated (
    uint indexed itemId,
    address indexed ticketContract,
    uint256 indexed winnerId,
    uint256 price,
    address prizeContract,
    uint256 prizeId,
    address winner,
    uint256 currentCount,
    uint256 numberLimited,
    uint256 requestId,
    bool awarded,
    bool claimed
  );

  event LotteryItemJoin (
    uint indexed itemId,
    address player,
    uint256 count,
    uint256 totalCount
  );

  event LotteryItemEnded (
    uint indexed itemId,
    address indexed ticketContract,
    uint256 indexed winnerId,
    address prizeContract,
    uint256 prizeId,
    address winner,
    bool awarded,
    bool claimed
  );

  constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    s_subscriptionId = subscriptionId;
  }

  function createLotteryItem(
    address prizeContract,
    uint256 prizeId,
    uint256 price,
    address ticketContract,
    uint256 numberLimited
  ) public payable onlyOwner {
    require(IERC721(prizeContract).ownerOf(prizeId) == msg.sender, "You doesn't own prize");
    
    uint256 itemId = _itemIds.current();
  
    idToLotteryItem[itemId] =  LotteryItem(
      itemId,
      ticketContract,
      price,
      0,
      prizeContract,
      prizeId,
      payable(address(0)),
      0,
      numberLimited,
      0,
      false,
      false
    );

    IERC721(prizeContract).transferFrom(msg.sender, address(this), prizeId);
    // increase item ID
    _itemIds.increment();
    emit LotteryItemCreated(
      itemId,
      ticketContract,
      0,
      price,
      prizeContract,
      prizeId,
      address(0),
      0,
      numberLimited,
      0,
      false,
      false
    );
  }

  function joinLottery(
    uint256 lotteryIndex,
    uint256 count
  ) external payable nonReentrant{
    LotteryItem storage lottery = idToLotteryItem[lotteryIndex];
    require(lottery.currentCount + count <= lottery.numberLimited, "Over limit");
    require(lottery.awarded == false, "This lottery has awarded");
    require(lottery.price * count <= msg.value, "Ether value sent is not correct");
    Ticket(lottery.ticketContract).mint(msg.sender, count);

    lottery.currentCount += count;

    emit LotteryItemJoin(
      lottery.itemId,
      msg.sender,
      count,
      lottery.currentCount
    );
    
    if(lottery.currentCount == lottery.numberLimited) {
      s_requestId = COORDINATOR.requestRandomWords(
          keyHash,
          s_subscriptionId,
          requestConfirmations,
          callbackGasLimit,
          numWords
      );
      lottery.requestId = s_requestId;
    
      emit LotteryItemEnded(
        lottery.itemId,
        lottery.ticketContract,
        0,
        lottery.prizeContract,
        lottery.prizeId,
        lottery.winner,
        true,
        false
      );
    }
  }

  function claim(
    uint256 lotteryIndex
  ) external {
    LotteryItem storage lottery = idToLotteryItem[lotteryIndex];
    require(lottery.winner == msg.sender, "You are not the winner.");
    IERC721(lottery.prizeContract).transferFrom(address(this), lottery.winner, lottery.prizeId);
    lottery.claimed = true;
    emit LotteryItemEnded(
      lottery.itemId,
      lottery.ticketContract,
      lottery.winnerId,
      lottery.prizeContract,
      lottery.prizeId,
      lottery.winner,
      true,
      true
    );
  }

  function fetchLotteryItems() public view returns (LotteryItem[] memory) {
    uint itemCount = _itemIds.current();

    LotteryItem[] memory items = new LotteryItem[](itemCount);
    for (uint i = 0; i < itemCount; i++) {
      LotteryItem memory currentItem = idToLotteryItem[i];
      items[i] = currentItem;
    }
    return items;
  }

  function withdrawMoney() external onlyOwner nonReentrant {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function requestRandomWords() external onlyOwner {
    s_requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
  }
  
  function fulfillRandomWords(
    uint256 requestId, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    s_randomWords = randomWords;
    LotteryItem storage lottery;
    uint itemCount = _itemIds.current();

    for (uint i = 0; i < itemCount; i++) {
      LotteryItem storage currentItem = idToLotteryItem[i];
      if(currentItem.requestId == requestId){
        lottery = currentItem;
        uint256 winnerId = randomWords[0] % lottery.numberLimited;
        _itemsAwarded.increment();
        lottery.winnerId = winnerId;
        lottery.winner = payable(Ticket(lottery.ticketContract).ownerOf(winnerId));
        lottery.awarded = true;
      }
    }
    
  }
}
