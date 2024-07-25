// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/IFactsRegistry.sol";

contract Escrow {
    // MVP of a unilateral bridge from sepolia to sepolia
    // with a single type of asset

    mapping(uint256 => InitialOrderData) public orders;
    mapping(uint256 => OrderStatusUpdates) public orderUpdates;

    uint256 private orderId = 1;

    event OrderPlaced(uint256 orderId, address creatorDestinationAddress, uint256 amount, uint256 fee);
    event SlotsReceived(bytes32 slot1, bytes32 slot2, bytes32 slot3, bytes32 slot4, bytes32 slot5, uint256 blockNumber); // TODO: remove when done testing
    event ValuesReceived(
        bytes32 _orderId, bytes32 dstAddress, bytes32 _amount, bytes32 _mmSrcAddress, bytes32 _mmDstAddress
    ); // TODO: remove when done testing

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

    address constant PAYMENT_REGISTRY_ADDRESS = 0xbAF6625e54035Ed93B3FEa38fa5F0aba1fBC5027;
    address constant FACTS_REGISTRY_ADDRESS = 0x7Cb1C4a51575Dc4505D8a8Ea361fc07346E5BC02;

    // FactsRegistry interface
    IFactsRegistry factsRegistry = IFactsRegistry(FACTS_REGISTRY_ADDRESS);

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
    // rename option: checkProofSlots
    // TODO: should be limited to only be called by one address that is trusted, which is the relaySlotsToEscrow from eventWatch
    // TODO: finish functionality and test
    function acceptProofSlots(
        bytes32 _orderIdSlot,
        bytes32 _dstAddressSlot,
        bytes32 _amountSlot,
        bytes32 _mmSrcAddressSlot,
        bytes32 _mmDstAddressSlot,
        uint256 _blockNumber
    ) public {
        emit SlotsReceived(
            _orderIdSlot, _dstAddressSlot, _amountSlot, _mmSrcAddressSlot, _mmDstAddressSlot, _blockNumber
        );
        // so this will take in all the slots that are to be checked as well as the block number,
        // call the facts registry and then get the values for those slots
        bytes32 _orderIdValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _orderIdSlot);
        bytes32 _dstAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _dstAddressSlot);
        bytes32 _amountValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _amountSlot);
        bytes32 _mmSrcAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _mmSrcAddressSlot);
        bytes32 _mmDstAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _mmDstAddressSlot);
        // then using the values from the slots, it will call the proveBridgeTransaction
        // UNCOMMENT proveBridgeTransaction(_orderIdValue, _dstAddressValue, _amountValue, _mmSrcAddressValue, _mmDstAddressValue);
        // mark the order as PROVING
        // UNCOMMENT orderUpdates[_orderIdValue].status = OrderStatus.PROVING;
        emit ValuesReceived(_orderIdValue, _dstAddressValue, _amountValue, _mmSrcAddressValue, _mmDstAddressValue);
    }

    // TODO: finish functionality and testing
    function proveBridgeTransaction(
        uint256 _orderId,
        address _dstAddress,
        uint256 _amount,
        address _mmSrcAddress,
        address _mmDstAddress
    ) external {
        InitialOrderData memory correctOrder = orders[_orderId];
        // check the values passed from the slots against own mapping of the order
        if (correctOrder.creatorDestinationAddress == _dstAddress && correctOrder.amount == _amount) {
            // once those all pass, then add in the MM source address into the OrderStatusUpdates
            orderUpdates[_orderId].marketMakerSourceAddress = _mmSrcAddress;
            // mark the transaction as PROVED
            orderUpdates[_orderId].status = OrderStatus.PROVED;
        }
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
