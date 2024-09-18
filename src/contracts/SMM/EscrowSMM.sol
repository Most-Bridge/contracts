// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // TODO: add proper address

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
        address tokenAddress;
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
     * @dev Allows the user to create an order, if sending native ETH, it can be done through the msg.value,
     * with an empty _tokenAddress and _amount otherwise when using erc20 _tokenAddress and _amount must be passed.
     * @param _usrDstAddress The destination address of the user.
     * @param _fee The fee for the market maker.
     * @param _tokenAddress If using an erc20, here the address of the erc20 can be specified.
     * @param _amount If using an erc20, here the amount can be specified.
     */
    function createOrder(address _usrDstAddress, uint256 _fee, address _tokenAddress, uint256 _amount)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        uint256 currentTimestamp = block.timestamp;
        uint256 _expirationTimestamp = currentTimestamp + 1 days;

        uint256 bridgeAmount = 0;

        if (_tokenAddress == address(0)) {
            // native eth
            bridgeAmount = msg.value;
        } else {
            // ERC20
            bridgeAmount = _amount;
        }

        // checks
        require(bridgeAmount > 0, "Funds being sent must be greater than 0.");
        require(bridgeAmount > _fee, "Fee must be less than the total value sent.");
        require(_tokenAddress == USDC_ADDRESS, "Only USDC supported at this moment.");
        uint256 receivedAmount = bridgeAmount - _fee; // subtract the fee from the amount received on the destination chain

        // for erc20 - make the transfer
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        }

        orders[orderId] = InitialOrderData({
            orderId: orderId,
            usrDstAddress: _usrDstAddress,
            expirationTimestamp: _expirationTimestamp,
            amount: receivedAmount,
            fee: _fee,
            tokenAddress: _tokenAddress
        });

        orderUpdates[orderId] = OrderStatusUpdates({orderId: orderId, status: OrderStatus.PENDING});

        emit OrderPlaced(orderId, _usrDstAddress, bridgeAmount, _fee);

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
     * @param _tokenAddress The address of the erc20 which was locked, empty if native ETH.
     */
    function withdrawProved(uint256 _orderId, address _tokenAddress) external nonReentrant whenNotPaused {
        // get order from this contract's state
        InitialOrderData memory _order = orders[_orderId];
        OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

        // validate
        // for a non-existing order a 0 will be returned as the orderId
        // also covers edge case where a orderId 0 passed will return a 0 also
        require(_order.orderId != 0, "The following order doesn't exist");
        require(_orderUpdates.status == OrderStatus.PROVED, "Cannot withdraw from an order that has not been proved.");
        require(msg.sender == allowedRelayAddress, "Only the approved MM address can call to withdraw.");
        require(_order.tokenAddress == _tokenAddress, "Can only withdraw the same type of asset that was locked."); // empty for native eth transfer

        // calculate payout
        uint256 transferAmountAndFee = _order.amount + _order.fee;

        // update status
        orderUpdates[_orderId].status = OrderStatus.COMPLETED;

        // payout MM
        if (_tokenAddress == address(0)) {
            // native ETH
            require(address(this).balance >= transferAmountAndFee, "Escrow: Insufficient ETH balance to withdraw.");
            payable(allowedWithdrawalAddress).transfer(transferAmountAndFee);
        } else {
            // ERC20
            require(
                IERC20(_tokenAddress).balanceOf(address(this)) >= transferAmountAndFee,
                "Escrow: Insufficient ERC20 balance to withdraw."
            );
            IERC20(_tokenAddress).transfer(allowedWithdrawalAddress, transferAmountAndFee);
        }
        emit WithdrawSuccess(_orderId);
    }

    /**
     * @dev Allows the market maker to batch unlock the funds for a transaction fulfilled by them.
     * @param _orderIds The ids of the orders to be withdrawn.
     * @param _tokenAddresses The addresses of the tokens to be withdrawn, empty if native ETH.
     */
    function batchWithdrawProved(uint256[] memory _orderIds, address[] memory _tokenAddresses)
        external
        nonReentrant
        whenNotPaused
    {
        require(_orderIds.length == _tokenAddresses.length, "Mismatched input lengths.");

        // Arrays to track unique token addresses and their total amounts
        address[] memory uniqueTokenAddresses = new address[](_tokenAddresses.length);
        uint256[] memory totalAmountPerToken = new uint256[](_tokenAddresses.length);
        uint256 uniqueCount = 0;

        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 _orderId = _orderIds[i];

            // Get order from this contract's state
            InitialOrderData memory _order = orders[_orderId];
            OrderStatusUpdates memory _orderUpdates = orderUpdates[_orderId];

            // Validate
            require(_order.orderId != 0, "The following order doesn't exist");
            require(_orderUpdates.status == OrderStatus.PROVED, "This order has not been proved yet.");
            require(msg.sender == allowedRelayAddress, "Only the MM can withdraw.");
            require(
                _order.tokenAddress == _tokenAddresses[i], "Can only withdraw the same type of asset that was locked."
            ); // empty for native ETH transfer

            // Calculate payout
            uint256 payout = _order.amount + _order.fee;

            // Check if the token address is already in uniqueTokenAddresses
            bool found = false;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (uniqueTokenAddresses[j] == _tokenAddresses[i]) {
                    totalAmountPerToken[j] += payout;
                    found = true;
                    break;
                }
            }

            // If this token address hasn't been found yet, add it to the list
            if (!found) {
                uniqueTokenAddresses[uniqueCount] = _tokenAddresses[i];
                totalAmountPerToken[uniqueCount] = payout;
                uniqueCount++;
            }

            // Update order status
            orderUpdates[_orderId].status = OrderStatus.COMPLETED;
        }

        // Payout MM by looping through all the unique token addresses
        for (uint256 i = 0; i < uniqueCount; i++) {
            address tokenAddress = uniqueTokenAddresses[i];
            uint256 totalAmount = totalAmountPerToken[i];

            if (tokenAddress == address(0)) {
                // Native ETH transfer
                require(address(this).balance >= totalAmount, "Escrow: Insufficient ETH balance for withdrawal.");
                payable(allowedWithdrawalAddress).transfer(totalAmount);
            } else {
                // ERC20 transfer
                require(
                    IERC20(tokenAddress).balanceOf(address(this)) >= totalAmount, "Escrow: Insufficient ERC20 balance."
                );
                IERC20(tokenAddress).transfer(allowedWithdrawalAddress, totalAmount);
            }
        }

        emit WithdrawSuccessBatch(_orderIds);
    }
    /**
     * @dev Allows the user to withdraw their order if it has not been fulfilled by the exipration date.
     * @param _orderId The Id of the order to be refunded.
     * @param _tokenAddress The address of the token that was locked, empty if native ETH.
     */

    function refundOrder(uint256 _orderId, address _tokenAddress) external payable nonReentrant whenNotPaused {
        InitialOrderData memory _orderToRefund = orders[_orderId];
        OrderStatusUpdates memory _orderToRefundUpdates = orderUpdates[_orderId];
        require(
            msg.sender == _orderToRefund.usrDstAddress, "Must cancel order with the same address used to create order"
        );
        require(_orderToRefundUpdates.status == OrderStatus.PENDING, "Cannot refund an order if it is not pending.");

        uint256 currentTimestamp = block.timestamp;
        require(currentTimestamp > _orderToRefund.expirationTimestamp, "Cannot refund an order that has not expired.");

        orderUpdates[_orderId].status = OrderStatus.RECLAIMED;

        uint256 amountToRefund = _orderToRefund.amount + _orderToRefund.fee;
        payable(msg.sender).transfer(amountToRefund);
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
