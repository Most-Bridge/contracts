// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Escrow Contract Whitelist SMM (Single Market Maker)
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
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying fulfilled orders
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    address public PAYMENT_REGISTRY_ADDRESS = 0x6B911a94ee908BF9503143863A52Ea6c1f38b50A;
    address public FACTS_REGISTRY_ADDRESS = 0xFE8911D762819803a9dC6Eb2dcE9c831EF7647Cd;

    uint256 private orderId = 1;

    IFactsRegistry factsRegistry = IFactsRegistry(FACTS_REGISTRY_ADDRESS);

    // Storage
    mapping(uint256 => InitialOrderData) public orders;
    mapping(uint256 => OrderStatusUpdates) public orderUpdates;
    mapping(address => bool) private whitelist;

    // Events
    event OrderPlaced(uint256 orderId, address usrDstAddress, uint256 amount, uint256 fee, uint256 expirationTimestamp);
    event ProveBridgeSuccess(uint256 orderId);
    event WithdrawSuccess(uint256 orderId);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrderReclaimed(uint256 orderId);

    // for debugging purposes
    // event SlotsReceived(bytes32 slot1, bytes32 slot2, bytes32 slot3, uint256 blockNumber);
    // event SlotsReceivedBatch(OrderSlots[] ordersToBeProved);
    // event ValuesReceived(bytes32 _orderId, bytes32 dstAddress, bytes32 _amount);
    // event ValuesReceivedBatch(OrderSlots[] ordersToBeProved);

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

    // Supplementary information to be updated throughout the process
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

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Caller is not on the white list");
        _;
    }

    // Constructor
    constructor() {
        owner = msg.sender;

        // whitelist addresses
        whitelist[0xe727dbADBB18c998e5DeE2faE72cBCFfF2e6d03D] = true;
        whitelist[0x898e87f1f5DCabCCbF68f2C17E2929672c6CA7DC] = true;
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
    function createOrder(address _usrDstAddress, uint256 _fee)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyWhitelist
    {
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

        orderUpdates[orderId] = OrderStatusUpdates({orderId: orderId, status: OrderStatus.PENDING});

        emit OrderPlaced(orderId, _usrDstAddress, bridgeAmount, _fee, _expirationTimestamp);

        orderId += 1;
    }

    /**
     * @dev Proves the fulfillment of an order by verifying order data stored on the Payment Registry contract at a specific block.
     *
     * This function calculates the storage slots associated with the order, retrieves the values from those slots,
     * converts them to their native types, and compares them with the stored order information to confirm fulfillment.
     * If the data matches, the order status is updated to "PROVED"; otherwise, it remains "PENDING."
     *
     * @param _orderId The order ID of the order to be proven.
     * @param _blockNumber The point in time in which the slot state will be accessed.
     */
    function proveOrderFulfillment(uint256 _orderId, uint256 _blockNumber) public onlyAllowedAddress whenNotPaused {
        // check that the order exists in the mapping
        require(orders[_orderId].orderId != 0, "Order does not exist");
        require(
            orderUpdates[_orderId].status == OrderStatus.PENDING,
            "The order can only be in the PENDING status; any other status is invalid."
        );

        // get the stored order data
        InitialOrderData memory correctOrder = orders[_orderId];
        OrderStatusUpdates memory correctOrderStatus = orderUpdates[_orderId];

        // STEP 1: CALCULATING THE STORAGE SLOTS
        bytes32 transfersMappingKey =
            keccak256(abi.encodePacked(correctOrder.orderId, correctOrder.usrDstAddress, correctOrder.amount));
        uint256 transfersMappingSlot = 2; // Please check payment registry storage layout for changes before deployment

        bytes32 baseStorageSlot = keccak256(abi.encodePacked(transfersMappingKey, transfersMappingSlot));

        bytes32 _orderIdSlot = baseStorageSlot;
        bytes32 _usrDstAddressSlot = bytes32(uint256(baseStorageSlot) + 1);
        bytes32 _expirationTimestampSlot = bytes32(uint256(baseStorageSlot) + 2);
        bytes32 _amountSlot = bytes32(uint256(baseStorageSlot) + 3);

        orderUpdates[_orderId].status = OrderStatus.PROVING;

        // STEP 2: GET THE VALUES OF THE STORAGE SLOTS
        bytes32 _orderIdValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _orderIdSlot);
        bytes32 _dstAddressValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _usrDstAddressSlot);
        bytes32 _expirationTimestampValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _expirationTimestampSlot);
        bytes32 _amountValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _amountSlot);

        // STEP 3: CONVERT THE VALUES TO THEIR NATIVE TYPES
        (uint256 orderIdNative, address dstAddressNative, uint256 expirationTimestampNative, uint256 amountNative) =
            convertBytes32toNative(_orderIdValue, _dstAddressValue, _expirationTimestampValue, _amountValue);

        // STEP 4: COMPARE ORDER FULFILLMENT DATA
        require(correctOrderStatus.status != OrderStatus.PROVED, "Cannot prove an order that has already been proved");

        uint256 currentTimestamp = block.timestamp;
        require(correctOrder.expirationTimestamp > currentTimestamp, "Cannot prove an order that has expired.");

        // make sure that proof data matches the contract's own data
        if (
            correctOrder.orderId == orderIdNative && correctOrder.usrDstAddress == dstAddressNative
                && correctOrder.amount == amountNative && correctOrder.expirationTimestamp == expirationTimestampNative
        ) {
            orderUpdates[_orderId].status = OrderStatus.PROVED;

            emit ProveBridgeSuccess(_orderId);
        } else {
            // if the proof fails, this will allow the order to be proved again
            orderUpdates[_orderId].status = OrderStatus.PENDING;
        }
    }

    /**
     * @dev In a batch format, calculates the slots which will be proven for the given orderIds, at the given blockNumber.
     * @param _orderIds An array of orders who's slots will be proven.
     * @param _blockNumber The point in time in which the slot state will be accessed.
     */
    function proveOrderFulfillmentBatch(uint256[] memory _orderIds, uint256 _blockNumber) public onlyAllowedAddress {
        // batch call proveOrderFulfillment
        for (uint256 i = 0; i < _orderIds.length; i++) {
            proveOrderFulfillment(_orderIds[i], _blockNumber);
        }
    }

    /**
     * @dev Converts bytes32 values to their native types.
     * @param _orderIdValue A bytes32 value of the orderId.
     * @param _dstAddressValue A bytes32 value of the dstAddress.
     * @param _expirationTimestampValue A bytes32 value of the expiration timestamp.
     * @param _amountValue A bytes32 value of the amount value.
     *
     * @return _orderId The order ID as a `uint256`.
     * @return _dstAddress The destination address as an `address`.
     * @return _expirationTimestamp The expiration timestamp as a `uint256`.
     * @return _amount The amount as a `uint256`.
     */
    function convertBytes32toNative(
        bytes32 _orderIdValue,
        bytes32 _dstAddressValue,
        bytes32 _expirationTimestampValue,
        bytes32 _amountValue
    ) internal pure returns (uint256 _orderId, address _dstAddress, uint256 _expirationTimestamp, uint256 _amount) {
        // bytes32 to uint256
        _orderId = uint256(_orderIdValue);
        _amount = uint256(_amountValue);
        _expirationTimestamp = uint256(_expirationTimestampValue);

        // bytes32 to address
        _dstAddress = address(uint160(uint256(_dstAddressValue)));

        return (_orderId, _dstAddress, _expirationTimestamp, _amount);
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
        require(address(this).balance >= transferAmountAndFee, "Withdraw Proved: Insufficient balance to withdraw");

        // update status
        orderUpdates[_orderId].status = OrderStatus.COMPLETED;

        // payout MM
        (bool success,) = payable(allowedWithdrawalAddress).call{value: transferAmountAndFee}("");
        require(success, "Withdraw Proved: Transfer failed");

        emit WithdrawSuccess(_orderId);
    }

    /**
     * @dev Allows the market maker to batch unlock the funds for a transaction fulfilled by them.
     * @param _orderIds The ids of the orders to be withdrawn.
     */
    function withdrawProvedBatch(uint256[] memory _orderIds) external nonReentrant whenNotPaused {
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
        require(address(this).balance >= amountToWithdraw, "Escrow: Insufficient balance to withdraw");
        (bool success,) = payable(allowedWithdrawalAddress).call{value: amountToWithdraw}("");
        require(success, "Withdraw Proved Batch: Transfer failed");

        emit WithdrawSuccessBatch(_orderIds);
    }

    /**
     * @dev Allows the user to withdraw their order if it has not been fulfilled by the expiration date.
     * Note: this function should never be pausable.
     * @param _orderId The Id of the order to be refunded.
     */
    function refundOrder(uint256 _orderId) external payable nonReentrant {
        InitialOrderData memory _orderToRefund = orders[_orderId];
        OrderStatusUpdates memory _orderToRefundUpdates = orderUpdates[_orderId];
        require(
            msg.sender == _orderToRefund.usrSrcAddress,
            "Can only refund with the same address that was used to create the order."
        );
        require(_orderToRefundUpdates.status == OrderStatus.PENDING, "Cannot refund an order if it is not pending.");

        uint256 currentTimestamp = block.timestamp;
        require(currentTimestamp > _orderToRefund.expirationTimestamp, "Cannot refund an order that has not expired.");

        uint256 amountToRefund = _orderToRefund.amount + _orderToRefund.fee;
        require(address(this).balance >= amountToRefund, "Insufficient contract balance for refund");

        orderUpdates[_orderId].status = OrderStatus.RECLAIMED;

        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund Order: Transfer failed");

        emit OrderReclaimed(_orderId);
    }

    // Only owner functions

    /**
     * @dev Change the allowed relay address.
     */
    function setAllowedAddress(address _newAllowedAddress) external onlyOwner {
        allowedRelayAddress = _newAllowedAddress;
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function batchAddToWhitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
    }
}
