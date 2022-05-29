pragma solidity ^0.8.14;

contract Campaign {
    struct Request{
        string description;
        uint value;
        address payable recipient;
        bool complete;
        uint approvalCount;
        mapping(address => bool) approvals;
    }
    
    address public manager;
    uint public minimumContribution;
    mapping(address => bool) public approvers;
    mapping(uint => Request) requests;
    uint numRequests;
    uint public approverCount;

    constructor (uint minimum){
        //The manager variable will be set to whoever deploys the contract
        manager = msg.sender;
        minimumContribution = minimum;
    }

    modifier restricted(){
        require(msg.sender == manager);
        _;
    }

    function contribute() public payable{
        require(msg.value > minimumContribution);
        approvers[msg.sender] = true;
        approverCount++;
    }

    function createRequest(string calldata descriptionIn, uint valueIn, address payable recipientIn) public restricted{
        //Get the last index of requests from storage
        Request storage newRequest = requests[numRequests];
        numRequests++;
        
        newRequest.description = descriptionIn;
        newRequest.value = valueIn;
        newRequest.recipient = recipientIn;
        newRequest.complete = false;
        newRequest.approvalCount = 0;
    }

    function approveRequest(uint index) public {
        Request storage request = requests[index];
        //Sender must be on the list of approvers
        require(approvers[msg.sender]);
        //Sender must not have voted yet
        require(!(request.approvals[msg.sender]));

        request.approvals[msg.sender] = true;
        request.approvalCount++;
    }

    function finalizeRequest(uint index) public payable restricted{
        //Make sure that the request hasn't already been finalized
        require(!(requests[index].complete));

        Request storage request = requests[index];
        //Make sure that the number of yes votes is greater than half of the number of approvers
        require(request.approvalCount > (approverCount / 2));

        request.recipient.transfer(request.value);
        request.complete = true;
    }
}
