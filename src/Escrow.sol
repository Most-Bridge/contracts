// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

contract Escrow {
    // MVP of a unilateral bridge from sepolia to sepolia
    // with a single type of asset

    mapping(uint256 => InitialOrderData) public orders;
    mapping(uint256 => OrderStatusUpdates) public orderUpdates;

    uint256 private orderId = 1;

    event OrderPlaced(uint256 orderId, address creatorDestinationAddress, uint256 amount, uint256 fee);
    event SlotsReceived(string slot1, string slot2, string slot3, string slot4, string slot5, uint256 blockNumber);

    struct InitialOrderData {
        uint256 orderId;
        address creatorDestinationAddress;
        uint256 amount;
        uint256 fee;
    }

    struct OrderStatusUpdates {
        uint256 orderId;
        OrderStatus status;
        address marketMakerSourceAddress;
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

    // TODO: hardcode the address of the PaymentRegistry contract

    // for now assuming only eth is being sent
    //Function recieves in msg.value the total value, and in fee the user specifies what portion of that msg.value is fee for MM
    function createOrder(address _destinationAddress, uint256 _fee) public payable {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        uint256 bridgeAmount = msg.value - _fee; //no underflow since previous check is made
        orders[orderId] = InitialOrderData({
            orderId: orderId,
            creatorDestinationAddress: _destinationAddress,
            amount: bridgeAmount,
            fee: _fee
        });

        orderUpdates[orderId] =
            OrderStatusUpdates({orderId: orderId, status: OrderStatus.PLACED, marketMakerSourceAddress: address(0)});

        emit OrderPlaced(orderId, _destinationAddress, bridgeAmount, _fee);
        orderUpdates[orderId].status = OrderStatus.PENDING;

        orderId += 1;
    }

    // accepting just slots, should be coming in the context of strings,
    // accepting just slots, should be coming in the context of strings,
    function acceptProofSlots(
        string calldata _orderIdSlot,
        string calldata _dstAddressSlot,
        string calldata _amountSlot,
        string calldata _mmSrcAddressSlot,
        string calldata _mmDstAddressSlot,
        uint256 _blockNumber
    ) public {
        emit SlotsReceived(
            _orderIdSlot, _dstAddressSlot, _amountSlot, _mmSrcAddressSlot, _mmDstAddressSlot, _blockNumber
        );
        // so this will take in all the slots that are to be checked as well as the block number,
        // call the facts registry and then get the values for those slots
        // then using the values from the slots, it will call the proveBridgeTransaction
        // mark the order as PROVING
    }

    function proveBridgeTransaction() external {
        // check the values passed from the slots against own mapping of the order
        // once those all pass, then add in the MM source address into the OrderStatusUpdates
        // mark the transaction as PROVED
    }

    function withdrawProved(uint256 _orderId) external {
        // could also add reenterancy guard here from openzeppelin
        InitialOrderData memory _order = orders[_orderId];
        OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

        require(_order.orderId != 0, "The following order doesn't exist"); // for a non-existing order a 0 will be returned as the orderId, also covers edge case where a orderId 0 passed will return a 0 also
        require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
        require(msg.sender == _orderUpdates.marketMakerSourceAddress, "Only the MM can withdraw.");

        uint256 transferAmountAndFee = _order.amount + _order.fee;
        require(address(this).balance >= transferAmountAndFee, "Escrow: Insuffienct balance to withdraw");

        orderUpdates[_orderId].status = OrderStatus.COMPLETED;
        payable(msg.sender).transfer(transferAmountAndFee);
    }

    // getters
    function getInitialOrderData(uint256 _orderId) public view returns (InitialOrderData memory) {
        return orders[_orderId];
    }

    function getOrderUpdates(uint256 _orderId) public view returns (OrderStatusUpdates memory) {
        return orderUpdates[_orderId];
    }

    //TODO: to be removed
    // setters for testing purposes only
    function updateMarketMakerSourceAddress(uint256 _orderId, address _newAddress) public {
        orderUpdates[_orderId].marketMakerSourceAddress = _newAddress;
    }

    function updateOrderStatus(uint256 _orderId, OrderStatus _newStatus) public {
        orderUpdates[_orderId].status = _newStatus;
    }
}
