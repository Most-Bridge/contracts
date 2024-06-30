// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

contract Escrow { 
    // MVP of a unilateral bridge from sepolia to sepolia 
    // with a single type of asset 

    mapping(uint256 => OrderInfo) public orders;
    mapping(uint256 => OrderLog) public orderLogs;

    uint256 private orderId = 0;

    event OrderPlaced(
        uint256 orderId,
        uint256 creatorDestinationAddress, 
        uint256 amount, 
        uint256 fee
    );

    struct OrderInfo {
        uint256 orderId;
        uint256 creatorDestinationAddress;
        uint256 amount;
        uint256 fee; 
    }

    struct OrderLog {
        uint256 orderId;
        OrderStatus status;
        uint256 marketMakerSourceAddress;
    }

    enum OrderStatus {
        PLACED, // once order has been placed by user
        PENDING, // the order has been emitted to the MM's 
        FULFILLED, // MM sent funds on destination chain
        PROVING, // proof has come to the escrow contract (might drop) 
        PROVED, // proof has been validated, able to be claimed 
        COMPLETED, // MM has been paid out 
        DROPPED // something wrong with the order 
    }

    // for now assuming only eth is being sent 
    //Function recieves in msg.value the total value, and in fee the user specifies what portion of that msg.value is fee for MM
    function createOrder(
        uint256 _destinationAddress,
        uint256 _fee
        ) public payable {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        uint256 bridge_amount = msg.value - _fee; //no underflow since previous check is made
        orders[orderId] = OrderInfo({
            orderId: orderId, 
            creatorDestinationAddress: _destinationAddress, 
            amount: bridge_amount,
            fee: _fee
            });

        orderLogs[orderId] = OrderLog({orderId: orderId, status: OrderStatus.PLACED, marketMakerSourceAddress: 0});

        emit OrderPlaced(orderId, _destinationAddress, bridge_amount, _fee);
        orderLogs[orderId].status = OrderStatus.PENDING;

        orderId += 1;
    } 

    function proveBridgeTransaction() external {
        // this function will be called by the relay system that will pass the proof
        // need to figure out how the data from Herodotus is going to look like 
        // however you would call this function with the proof of the transaction
        // on the destination chain, then the function would check the info passed 
        // from the proof, to it's own info in the OrderInfo, 
        // ** note ** the proof will contain the MM's source and destination address
        // check that marketMakerDestinationAddress is the same as the address in the proof
        // check that the userDestinationAddress matches
        // check that the amounts match 
        // mark the pendingOrder as PROVED
    }

    function withdrawProoved(uint256 _orderId, uint256 mmSourceAddress) internal { 
        // require _orderId exists
        // require OrdersReceived[_orderId].status == OrderStatus.PROVED
        // require OrdersReceived[_orderId].marketMakerSourceAddress == msg.sender
        // transfer the (amount + fee - contract fee) msg.sender who is being assumed
        // is the Market Maker 
    } 


}
