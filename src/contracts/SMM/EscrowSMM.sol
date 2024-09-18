// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Escrow Contract SMM (Single Market Maker)
 * @dev Handles the bridging of assets between two chains, in conjunction with Payment Registry and a 3rd party
 * facilitator service.
 * Terminology:
 * User (usr): The entity wishing to bridge their assets.
 * Market Maker (mm): The entity facilitating the bridging process.
 * Source (src): The chain from which funds are being bridged.
 * Destination (dst): The chain to which the funds are being bridged.
 */
interface IFactsRegistry {
    function accountStorageSlotValues(address account, uint256 blockNumber, bytes32 slot)
        external
        view
        returns (bytes32);
}

contract Escrow is ReentrancyGuard, Pausable {
    // State variables
    address public owner;
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying slots to this contract
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // TODO: add proper withdrawal address

    address public PAYMENT_REGISTRY_ADDRESS = 0xdA406E807424a8b49B4027dC5335304C00469821;
    address public FACTS_REGISTRY_ADDRESS = 0xFE8911D762819803a9dC6Eb2dcE9c831EF7647Cd;

    uint256 private orderId = 1;

    IFactsRegistry factsRegistry = IFactsRegistry(FACTS_REGISTRY_ADDRESS);

    // Storage
    mapping(uint256 => InitialOrderData) public orders;
    mapping(uint256 => OrderStatusUpdates) public orderUpdates;

    // Events
    event OrderPlaced(uint256 orderId, address usrDstAddress, uint256 amount, uint256 fee);
    event ProveBridgeSuccess(uint256 orderId);
    event WithdrawSuccess(uint256 orderId);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrderReclaimed(uint256 orderId);

    // for debugging purposes
    // event SlotsReceived(bytes32 slot1, bytes32 slot2, bytes32 slot3, uint256 blockNumber);
    // event ValuesReceived(bytes32 _orderId, bytes32 dstAddress, bytes32 _amount);
    // event ValuesReceivedBatch(OrderSlots[] ordersToBeProved);
    // event SlotsReceivedBatch(OrderSlots[] ordersToBeProved);

    // Structs
    // Contains all information that is available during the order creation
    struct InitialOrderData {
        uint256 orderId;
        address usrDstAddress;
        uint256 expirationTimestamp;
        uint256 amount;
        uint256 fee;
        address usrSrcAddress;
    }

    // Suplementary information to be updated throughout the process
    struct OrderStatusUpdates {
        uint256 orderId;
        OrderStatus status;
    }

    struct OrderSlots {
        bytes32 orderIdSlot;
        bytes32 dstAddressSlot;
        bytes32 expirationTimestamp;
        bytes32 amountSlot;
        uint256 blockNumber;
    }

    //Enums
    enum OrderStatus {
        PLACED,
        PENDING,
        PROVING,
        PROVED,
        COMPLETED,
        RECLAIMED,
        DROPPED
    }

    // Modifiers
    modifier onlyAllowedAddress() {
        require(msg.sender == allowedRelayAddress, "Caller is not allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Contructor
    constructor() {
        owner = msg.sender;
    }

    // Functions
    /**
     * @dev Pause the contract in case of an error.
     */
    function pauseContract() external onlyAllowedAddress {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpauseContract() external onlyAllowedAddress {
        _unpause();
    }

    /**
     * @dev Allows the user to create an order.
     * @param _usrDstAddress The destination address of the user.
     * @param _fee The fee for the market maker.
     */
    function createOrder(address _usrDstAddress, uint256 _fee) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        uint256 currentTimestamp = block.timestamp;
        uint256 _expirationTimestamp = currentTimestamp + 1 days;

        uint256 bridgeAmount = msg.value - _fee; //no underflow since previous check is made
        orders[orderId] = InitialOrderData({
            orderId: orderId,
            usrDstAddress: _usrDstAddress,
            expirationTimestamp: _expirationTimestamp,
            amount: bridgeAmount,
            fee: _fee,
            usrSrcAddress: msg.sender
        });

        orderUpdates[orderId] = OrderStatusUpdates({orderId: orderId, status: OrderStatus.PLACED});

        emit OrderPlaced(orderId, _usrDstAddress, bridgeAmount, _fee);
        orderUpdates[orderId].status = OrderStatus.PENDING;

        orderId += 1;
    }

    /**
     * @dev Fetches and processes storage slot values from the FactsRegistry contract for a single order.
     * @param _orderIdSlot Slot of the order Id.
     * @param _dstAddressSlot Slot of the user's destination address.
     * @param _expirationTimestampSlot Slot of the expiratoin timestamp.
     * @param _amountSlot Slot of the amount.
     * @param _blockNumber The blockNumber.
     */
    function getValuesFromSlots(
        bytes32 _orderIdSlot,
        bytes32 _dstAddressSlot,
        bytes32 _expirationTimestampSlot,
        bytes32 _amountSlot,
        uint256 _blockNumber
    ) public onlyAllowedAddress whenNotPaused {
        bytes32 _orderIdValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _orderIdSlot);
        bytes32 _dstAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _dstAddressSlot);
        bytes32 _expirationTimestampValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _expirationTimestampSlot);
        bytes32 _amountValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _amountSlot);

        convertBytes32toNative(_orderIdValue, _dstAddressValue, _expirationTimestampValue, _amountValue);
    }

    /**
     * @dev Fetches and processes storage slot values for multiple orders in batch from the FactsRegistry contract.
     * And continues the flow of proving an order.
     * @param _ordersToBeProved an array of orders of type OrderSlots.
     */
    function batchGetValuesFromSlots(OrderSlots[] memory _ordersToBeProved) public onlyAllowedAddress whenNotPaused {
        require(_ordersToBeProved.length > 0, "Orders to be proved array cannot be empty");
        for (uint256 i = 0; i < _ordersToBeProved.length; i++) {
            OrderSlots memory singleOrder = _ordersToBeProved[i];
            bytes32 _orderIdValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.orderIdSlot
            );
            bytes32 _dstAddressValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.dstAddressSlot
            );
            bytes32 _expirationTimestampValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.expirationTimestamp
            );
            bytes32 _amountValue = factsRegistry.accountStorageSlotValues(
                PAYMENT_REGISTRY_ADDRESS, singleOrder.blockNumber, singleOrder.amountSlot
            );
            convertBytes32toNative(_orderIdValue, _dstAddressValue, _expirationTimestampValue, _amountValue);
        }
    }

    /**
     * @dev Converts bytes32 values to their native types.
     * @param _orderIdValue A bytes32 value of the orderId.
     * @param _dstAddressValue A bytes32 value of the dstAddress.
     * @param _expirationTimestampValue A bytes32 value of the expiration timestamp.
     * @param _amountValue A bytes32 value of the amount value.
     */
    function convertBytes32toNative(
        bytes32 _orderIdValue,
        bytes32 _dstAddressValue,
        bytes32 _expirationTimestampValue,
        bytes32 _amountValue
    ) private {
        // bytes32 to uint256
        uint256 _orderId = uint256(_orderIdValue);
        uint256 _amount = uint256(_amountValue);
        uint256 _expirationTimestamp = uint256(_expirationTimestampValue);

        //bytes32 to address
        address _dstAddress = address(uint160(uint256(_dstAddressValue)));

        require(orders[_orderId].orderId != 0, "This order does not exist");
        require(
            orderUpdates[_orderId].status == OrderStatus.PENDING,
            "The order can only be in the PENDING status; any other status is invalid."
        );

        orderUpdates[_orderId].status = OrderStatus.PROVING;

        proveBridgeTransaction(_orderId, _dstAddress, _expirationTimestamp, _amount);
    }

    /**
     * @dev Validates the transaction proof, and updates the status of the order.
     * @param _orderId The order's Id.
     * @param _dstAddress The destination address of the order.
     * @param _expirationTimestamp The expiration timestamp of the order.
     * @param _amount The amount of the order.
     */
    function proveBridgeTransaction(
        uint256 _orderId,
        address _dstAddress,
        uint256 _expirationTimestamp,
        uint256 _amount
    ) private {
        InitialOrderData memory correctOrder = orders[_orderId];
        OrderStatusUpdates memory correctOrderStatus = orderUpdates[_orderId];

        require(correctOrderStatus.status != OrderStatus.PROVED, "Cannot prove an order that has already been proved");

        uint256 currentTimestamp = block.timestamp;
        require(correctOrder.expirationTimestamp > currentTimestamp, "Cannot prove an order that has expired.");

        // make sure that proof data matches the contract's own data
        if (
            correctOrder.usrDstAddress == _dstAddress && correctOrder.amount == _amount
                && correctOrder.expirationTimestamp == _expirationTimestamp
        ) {
            orderUpdates[_orderId].status = OrderStatus.PROVED;

            emit ProveBridgeSuccess(_orderId);
        } else {
            // if the proof fails, this will allow the order to be proved again
            orderUpdates[_orderId].status = OrderStatus.PENDING;
        }
    }

    /**
     * @dev Allows the market maker to unlock the funds for a transaction fulfilled by them.
     * @param _orderId The id of the order to be withdrawn.
     */
    function withdrawProved(uint256 _orderId) external nonReentrant whenNotPaused {
        // get order from this contract's state
        InitialOrderData memory _order = orders[_orderId];
        OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

        // validate
        // for a non-existing order a 0 will be returned as the orderId
        // also covers edge case where a orderId 0 passed will return a 0 also
        require(_order.orderId != 0, "The following order doesn't exist");
        require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
        require(msg.sender == allowedRelayAddress, "Only the approved MM address can call to withdraw.");

        // calculate payout
        uint256 transferAmountAndFee = _order.amount + _order.fee;
        require(address(this).balance >= transferAmountAndFee, "Escrow: Insuffienct balance to withdraw");

        // update status
        orderUpdates[_orderId].status = OrderStatus.COMPLETED;

        // payout MM
        payable(allowedWithdrawalAddress).transfer(transferAmountAndFee);
        emit WithdrawSuccess(_orderId);
    }

    /**
     * @dev Allows the market maker to batch unlock the funds for a transaction fulfilled by them.
     * @param _orderIds The ids of the orders to be withdrawn.
     */
    function batchWithdrawProved(uint256[] memory _orderIds) external nonReentrant whenNotPaused {
        uint256 amountToWithdraw = 0;
        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 _orderId = _orderIds[i];
            // get order from this contract's state
            InitialOrderData memory _order = orders[_orderId];
            OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

            // validate
            // for a non-existing order a 0 will be returned as the orderId,
            // also covers edge case where a orderId 0 passed will return a 0
            require(_order.orderId != 0, "The following order doesn't exist");
            require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
            require(msg.sender == allowedRelayAddress, "Only the MM can withdraw.");

            // calculate payout
            amountToWithdraw += _order.amount + _order.fee;

            // update status
            orderUpdates[_orderId].status = OrderStatus.COMPLETED;
        }
        // payout MM
        require(address(this).balance >= amountToWithdraw, "Escrow: Insuffienct balance to withdraw");
        payable(allowedWithdrawalAddress).transfer(amountToWithdraw);
        emit WithdrawSuccessBatch(_orderIds);
    }

    /**
     * @dev Allows the user to withdraw their order if it has not been fulfilled by the exipration date.
     * @param _orderId The Id of the order to be refunded.
     */
    function refundOrder(uint256 _orderId) external payable nonReentrant whenNotPaused {
        InitialOrderData memory _orderToRefund = orders[_orderId];
        OrderStatusUpdates memory _orderToRefundUpdates = orderUpdates[_orderId];
        // require(
        //     msg.sender == _orderToRefund.usrSrcAddress,
        //     "Can only refund with the same address that was used to create the order."
        // );
        require(_orderToRefundUpdates.status == OrderStatus.PENDING, "Cannot refund an order if it is not pending.");

        uint256 currentTimestamp = block.timestamp;
        require(currentTimestamp > _orderToRefund.expirationTimestamp, "Cannot refund an order that has not expired.");

        orderUpdates[_orderId].status = OrderStatus.RECLAIMED;

        uint256 amountToRefund = _orderToRefund.amount + _orderToRefund.fee;
        require(address(this).balance >= amountToRefund, "Insufficient contract balance for refund");

        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Transfer failed");

        emit OrderReclaimed(_orderId);
    }

    // Only owner functions

    /**
     * @dev Change the allowed relay address.
     */
    function setAllowedAddress(address _newAllowedAddress) public onlyOwner {
        allowedRelayAddress = _newAllowedAddress;
    }

    /**
     * @dev Change the payment registry address.
     */
    function setPaymentRegistryAddress(address _newPaymentRegistryAddress) public onlyOwner {
        PAYMENT_REGISTRY_ADDRESS = _newPaymentRegistryAddress;
    }
}
