// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/openzeppelin-contracts/contracts/utils/Pausable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// src/contracts/Escrow.sol

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

    address public PAYMENT_REGISTRY_ADDRESS = 0xdA406E807424a8b49B4027dC5335304C00469821;
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

