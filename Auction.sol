//SPDX-License-Identifier: GPL-30
pragma solidity >= 0.7.0 < 0.9.0;

contract Auction{
    address payable public auctioneer;
    address highestBidder;
    uint highestBid;
    uint public endTime;
    mapping(address => uint) public bids;
    uint[] bidArray;
    address[] bidderAddresses;

    constructor () payable{
        auctioneer = payable(msg.sender);
        endTime = block.timestamp + 1 weeks;
    }

    //A contract must have a payable fallback function in order to receive funds
    fallback () external payable {
    }

    //If something goes wrong, this contract still receives all of the funds sent to it
    //with no way to get it back
    receive () external payable{
    }

    modifier OnlyOwner(){
        require(msg.sender == auctioneer);
        _;
    }

    modifier OnlyAfter{
        require(block.timestamp >= endTime);
        _;
    }

    event NewHighestBidder(address indexed newHighestBidder, uint indexed newHighestBid);
    event AuctionEnded(address winnerAddress, uint winningBid);

    function bid() external payable {
        if(block.timestamp > endTime){
            revert("Auction has already ended!");
        }

        else if(msg.value > highestBid){
            highestBidder = msg.sender;
            highestBid = msg.value;
            bids[msg.sender] = msg.value;
            bidArray.push(msg.value);
            bidderAddresses.push(msg.sender);
            emit NewHighestBidder(msg.sender, msg.value);
        }

        else{
            payable(msg.sender).transfer(msg.value);
        }
    }

    function withdraw() external payable returns(bool success){
        require(bids[msg.sender] > 0, "You have nothing to withdraw.");

        uint withdrawalAmount = bids[msg.sender];
        success = payable(msg.sender).send(withdrawalAmount);

        if(!success){
            bids[msg.sender] = withdrawalAmount;
        }

        else{
            delete(bids[msg.sender]);
        }

        return success;
    }
    
    function viewBids() view external returns(uint[] memory){
        return bidArray;
    }

    function endAuction() public payable OnlyOwner OnlyAfter returns(bool success){
        emit AuctionEnded(highestBidder, highestBid);
        success = payable(auctioneer).send(highestBid);
        
        for(uint i = 0; i < bidArray.length; i++){
            delete(bidArray[i]);
        }

        for(uint j = 0; j < bidderAddresses.length; j++){
            delete(bids[bidderAddresses[j]]);
        }
    }
}
