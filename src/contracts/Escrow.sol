// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/*
* Escrow along with the PaymentRegistry contract and a 3rd party service EventWatch 
* make up the MVP of a unilateral bridge from OP Sepolia to ETH Sepolia with a single type of asset. 
* 
* Terminology: 
* User(usr) - The entity that is wishing to bridge their assets. 
* Market Maker(mm) - The entity that is going to facilitate the bridging process. 
* Source(src) -  Where funds are being bridged from, and where an order is created. 
* Destination(dst) - The chain to which the funds are being bridged. 
*/

interface IFactsRegistry {
    function accountStorageSlotValues(address account, uint256 blockNumber, bytes32 slot)
        external
        view
        returns (bytes32);
}

contract Escrow is ReentrancyGuard, Pausable {
    mapping(uint256 => InitialOrderData) public orders;
    mapping(uint256 => OrderStatusUpdates) public orderUpdates;

    uint256 private orderId = 1;

    event OrderPlaced(uint256 orderId, address usrDstAddress, uint256 amount, uint256 fee);
    event SlotsReceived(bytes32 slot1, bytes32 slot2, bytes32 slot3, bytes32 slot4, uint256 blockNumber); // TODO: remove when done testing
    event ValuesReceived(bytes32 _orderId, bytes32 dstAddress, bytes32 _amount, bytes32 _mmSrcAddress); // TODO: remove when done testing
    event ProveBridgeSuccess(uint256 orderId);
    event WithdrawSuccess(address mmSrcAddress, uint256 orderId);
    event BatchSlotsReceived(OrderSlots[] ordersToBeProved);

    // Contains all information that is available during the order creation
    struct InitialOrderData {
        uint256 orderId;
        address usrDstAddress;
        uint256 amount;
        uint256 fee;
    }

    // Suplementary information to be updated throughout the process
    struct OrderStatusUpdates {
        uint256 orderId;
        OrderStatus status;
        address mmSrcAddress;
    }

    enum OrderStatus {
        PLACED, // once order has been placed by user
        PENDING, // the order has been emitted to the MMs
        PROVING, // proof has come to the escrow contract
        PROVED, // proof has been validated, able to be claimed
        COMPLETED, // MM has been paid out
        DROPPED // something is wrong with the order

    }

    struct OrderSlots {
        bytes32 orderIdSlot;
        bytes32 dstAddressSlot;
        bytes32 mmSrcAddressSlot;
        bytes32 amountSlot;
        uint256 blockNumber;
    }

    constructor() {
        owner = msg.sender;
    }

    address public owner;
    address public allowedRelayAddress = 0x0616BaE9f787949066aa277038e35f4d0C32Bc3D; // address which will be relayig slots to this contract

    address public PAYMENT_REGISTRY_ADDRESS = 0xda406e807424a8b49b4027dc5335304c00469821;
    address public FACTS_REGISTRY_ADDRESS = 0xFE8911D762819803a9dC6Eb2dcE9c831EF7647Cd;

    // interface for the contract which delivers slot values
    IFactsRegistry factsRegistry = IFactsRegistry(FACTS_REGISTRY_ADDRESS);

    modifier onlyAllowedAddress() {
        require(msg.sender == allowedRelayAddress, "Caller is not allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // emergency kill switch
    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }

    //Function recieves funds in msg.value, and the user specifies what portion of that msg.value is a fee for MM
    function createOrder(address _usrDstAddress, uint256 _fee) public payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        uint256 bridgeAmount = msg.value - _fee; //no underflow since previous check is made
        orders[orderId] =
            InitialOrderData({orderId: orderId, usrDstAddress: _usrDstAddress, amount: bridgeAmount, fee: _fee});

        orderUpdates[orderId] =
            OrderStatusUpdates({orderId: orderId, status: OrderStatus.PLACED, mmSrcAddress: address(0)});

        emit OrderPlaced(orderId, _usrDstAddress, bridgeAmount, _fee);
        orderUpdates[orderId].status = OrderStatus.PENDING;

        orderId += 1;
    }

    function getValuesFromSlots(
        bytes32 _orderIdSlot,
        bytes32 _dstAddressSlot,
        bytes32 _mmSrcAddressSlot,
        bytes32 _amountSlot,
        uint256 _blockNumber
    ) public onlyAllowedAddress whenNotPaused {
        emit SlotsReceived(_orderIdSlot, _dstAddressSlot, _mmSrcAddressSlot, _amountSlot, _blockNumber);
        bytes32 _orderIdValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _orderIdSlot);
        bytes32 _dstAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _dstAddressSlot);
        bytes32 _mmSrcAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _mmSrcAddressSlot);
        bytes32 _amountValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _amountSlot);

        convertBytes32toNative(_orderIdValue, _dstAddressValue, _mmSrcAddressValue, _amountValue);
        emit ValuesReceived(_orderIdValue, _dstAddressValue, _mmSrcAddressValue, _amountValue);
    }

    function batchGetValuesFromSlots(OrderSlots[] memory ordersToBeProved) public onlyAllowedAddress whenNotPaused {
        require(ordersToBeProved.length > 0, "Orders to be proved array cannot be empty");
        emit BatchSlotsReceived(ordersToBeProved);
        for (uint256 i = 0; i < ordersToBeProved.length; i++) {
            OrderSlots memory singleOrder = ordersToBeProved[i];
            bytes32 _orderIdValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.orderIdSlot
            );
            bytes32 _dstAddressValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.dstAddressSlot
            );
            bytes32 _mmSrcAddressValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.mmSrcAddressSlot
            );
            bytes32 _amountValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.amountSlot
            );
            convertBytes32toNative(_orderIdValue, _dstAddressValue, _mmSrcAddressValue, _amountValue);
            emit ValuesReceived(_orderIdValue, _dstAddressValue, _mmSrcAddressValue, _amountValue);
        }
    }

    function convertBytes32toNative(
        bytes32 _orderIdValue,
        bytes32 _dstAddressValue,
        bytes32 _mmSrcAddressValue,
        bytes32 _amountValue
    ) private {
        // bytes32 to uint256
        uint256 _orderId = uint256(_orderIdValue);
        uint256 _amount = uint256(_amountValue);

        //bytes32 to address
        address _dstAddress = address(uint160(uint256(_dstAddressValue)));
        address _mmSrcAddress = address(uint160(uint256(_mmSrcAddressValue)));

        require(orders[_orderId].orderId != 0, "This order does not exist");
        orderUpdates[_orderId].status = OrderStatus.PROVING;
        proveBridgeTransaction(_orderId, _dstAddress, _mmSrcAddress, _amount);
    }

    function proveBridgeTransaction(uint256 _orderId, address _dstAddress, address _mmSrcAddress, uint256 _amount)
        private
    {
        InitialOrderData memory correctOrder = orders[_orderId];
        // make sure that proof data matches the contract's own data
        if (correctOrder.usrDstAddress == _dstAddress && correctOrder.amount == _amount) {
            // add the address which will be paid out to, and update status
            orderUpdates[_orderId].mmSrcAddress = _mmSrcAddress;
            orderUpdates[_orderId].status = OrderStatus.PROVED;
            // TODO: emit event here that prove bridge was successful
            emit ProveBridgeSuccess(_orderId);
        } else {
            // if the proof fails, this will allow the order to be fulfilled again
            orderUpdates[_orderId].status = OrderStatus.PENDING;
        }
    }

    function withdrawProved(uint256 _orderId) external onlyAllowedAddress whenNotPaused {
        // get order from this contract's state
        InitialOrderData memory _order = orders[_orderId];
        OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

        // validate
        require(_order.orderId != 0, "The following order doesn't exist"); // for a non-existing order a 0 will be returned as the orderId, also covers edge case where a orderId 0 passed will return a 0 also
        require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
        require(msg.sender == _orderUpdates.mmSrcAddress, "Only the MM can withdraw.");

        // calculate payout
        uint256 transferAmountAndFee = _order.amount + _order.fee;
        require(address(this).balance >= transferAmountAndFee, "Escrow: Insuffienct balance to withdraw");

        // update status
        orderUpdates[_orderId].status = OrderStatus.COMPLETED;

        // payout MM
        payable(msg.sender).transfer(transferAmountAndFee);
        emit WithdrawSuccess(msg.sender, _orderId);
    }

    // TODO: add re-enterancy guard
    function batchWithdrawProved(uint256[] memory _orderIds) external onlyAllowedAddress whenNotPaused {
        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 _orderId = _orderIds[i];
            // get order from this contract's state
            InitialOrderData memory _order = orders[_orderId];
            OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

            // validate
            require(_order.orderId != 0, "The following order doesn't exist"); // for a non-existing order a 0 will be returned as the orderId, also covers edge case where a orderId 0 passed will return a 0 also
            require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
            require(msg.sender == _orderUpdates.mmSrcAddress, "Only the MM can withdraw.");

            // calculate payout
            uint256 transferAmountAndFee = _order.amount + _order.fee;
            require(address(this).balance >= transferAmountAndFee, "Escrow: Insuffienct balance to withdraw");

            // update status
            orderUpdates[_orderId].status = OrderStatus.COMPLETED;

            // payout MM
            payable(msg.sender).transfer(transferAmountAndFee);
            emit WithdrawSuccess(msg.sender, _orderId);
        }
    }

    function setAllowedAddress(address _newAllowedAddress) public onlyOwner {
        allowedRelayAddress = _newAllowedAddress;
    }

    function setFactsRegistryAddress(address _newFactsRegistryAddress) public onlyOwner {
        FACTS_REGISTRY_ADDRESS = _newFactsRegistryAddress; 
    }

    function setPaymentRegistryAddress(address _newPaymentRegistryAddress) public onlyOwner {
        PAYMENT_REGISTRY_ADDRESS = _newPaymentRegistryAddress;
    }
}
