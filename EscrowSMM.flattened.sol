// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20 ^0.8.26 ^0.8.27;

// lib/herodotus-evm-v2/src/interfaces/external/IFactsRegistry.sol

interface IFactsRegistry {
    function isValid(bytes32 fact) external view returns (bool);
}

// lib/herodotus-evm-v2/src/interfaces/modules/common/IFactsRegistryCommon.sol

interface IFactsRegistryCommon {
    error InvalidFact();
}

// lib/herodotus-evm-v2/src/libraries/internal/data-processor/Task.sol

/// @notice Task type.
enum TaskCode {
    // Datalake,
    Module
}

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

// lib/herodotus-evm-v2/src/libraries/internal/data-processor/ModuleCodecs.sol

/// @dev A module task.
/// @param programHash The program hash of the module.
/// @param inputs The inputs to the module.
struct ModuleTask {
    bytes32 programHash;
    bytes32[] inputs;
}

/// @notice Codecs for ModuleTask.
/// @dev Represent module with a program hash and inputs.
library ModuleCodecs {
    /// @dev Get the commitment of a Module.
    /// @param module The Module to commit.
    function commit(ModuleTask memory module) internal pure returns (bytes32) {
        return keccak256(abi.encode(module.programHash, module.inputs));
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

// lib/herodotus-evm-v2/src/interfaces/modules/IDataProcessorModule.sol

interface IDataProcessorModule is IFactsRegistryCommon {
    /// @notice The status of a task
    enum TaskStatus {
        NONE,
        SCHEDULED,
        FINALIZED
    }

    /// @notice The struct representing a task result
    struct TaskResult {
        TaskStatus status;
        bytes32 result;
    }

    /// @notice Storage structure for the module
    struct DataProcessorModuleStorage {
        IFactsRegistry factsRegistry;
        mapping(bytes32 => TaskResult) cachedTasksResult;
        mapping(bytes32 => bool) authorizedProgramHashes;
    }

    struct MmrData {
        uint256 chainId;
        uint256 mmrId;
        uint256 mmrSize;
    }

    /// @param mmrData For each used MMR, its chain ID, ID and size
    /// @param taskResultLow The low part of the task result
    /// @param taskResultHigh The high part of the task result
    /// @param taskHashLow The low part of the task hash
    /// @param taskHashHigh The high part of the task hash
    /// @param moduleHash The module hash that was used to compute the task
    /// @param programHash The program hash that was used to compute the task
    struct TaskData {
        MmrData[] mmrData;
        uint256 taskResultLow;
        uint256 taskResultHigh;
        uint256 taskHashLow;
        uint256 taskHashHigh;
        bytes32 moduleHash;
        bytes32 programHash;
    }

    /// @notice emitted when a task already stored
    event TaskAlreadyStored(bytes32 result);

    /// @notice emitted when a new module task is scheduled
    event ModuleTaskScheduled(ModuleTask moduleTask);

    /// Task is already registered
    error DoubleRegistration();
    /// Element is not in the batch
    error NotInBatch();
    /// Task is not finalized
    error NotFinalized();
    /// Unauthorized or inactive program hash
    error UnauthorizedProgramHash();
    /// Invalid MMR root
    error InvalidMmrRoot();

    /// @notice Emitted when a program hash is enabled
    event ProgramHashEnabled(bytes32 enabledProgramHash);

    /// @notice Emitted when some program hashes are disabled
    event ProgramHashesDisabled(bytes32[] disabledProgramHashes);

    /// @notice Set the program hash for the HDP program
    function setDataProcessorProgramHash(bytes32 programHash) external;

    /// @notice Disable some program hashes
    function disableProgramHashes(bytes32[] calldata programHashes) external;

    /// @notice Set the facts registry contract
    function setDataProcessorFactsRegistry(IFactsRegistry factsRegistry) external;

    /// @notice Requests the execution of a task with a module
    /// @param moduleTask module task
    function requestDataProcessorExecutionOfTask(ModuleTask calldata moduleTask) external;

    /// @notice Authenticates the execution of a task is finalized
    ///         by verifying the locally computed fact with the FactsRegistry
    /// @param taskData The task data
    function authenticateDataProcessorTaskExecution(TaskData calldata taskData) external;

    /// @notice Returns the result of a finalized task
    function getDataProcessorFinalizedTaskResult(bytes32 taskCommitment) external view returns (bytes32);

    /// @notice Returns the status of a task
    function getDataProcessorTaskStatus(bytes32 taskCommitment) external view returns (TaskStatus);

    /// @notice Checks if a program hash is currently authorized
    function isProgramHashAuthorized(bytes32 programHash) external view returns (bool);
}

// src/contracts/SMM/EscrowSMM.sol

/// @title Escrow SMM (Single Market Maker)
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Handles the bridging of assets between a src chain and a dst chain, in conjunction with Payment Registry and a
///         facilitator service.
contract Escrow is ReentrancyGuard, Pausable {
    using ModuleCodecs for ModuleTask;

    // State variables
    uint256 private orderId = 1;
    address public owner;
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying fulfilled orders
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    uint256 public constant ONE_DAY = 1 days;
    bytes32 public constant SRC_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000AA36A7;

    // HDP
    address public HDP_EXECUTION_STORE_ADDRESS = 0x59c0B3D09151aA2C0201808fEC0860f1168A4173;

    // Interfaces
    IDataProcessorModule hdpExecutionStore = IDataProcessorModule(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(uint256 => bytes32) public orders;
    mapping(uint256 => OrderState) public orderStatus;
    mapping(bytes32 => HDPConnection) public hdpConnections; // mapping chainId -> HdpConnection
    mapping(address => bool) public supportedSrcTokens;
    mapping(bytes32 => mapping(address => bool)) supportedDstTokensByChain; // mapping chainId -> token address -> is token supported?

    /// Events
    /// @param usrDstAddress Stored as a uint256 to allow for starknet addresses to be stored
    /// @param dstChainId    Stored as a hex in bytes32 to allow for longer chain ids
    /// @param fee           Calculated using the sourceToken
    event OrderPlaced(
        uint256 orderId,
        address usrSrcAddress,
        uint256 usrDstAddress,
        uint256 expirationTimestamp,
        address srcToken,
        uint256 srcAmount,
        address dstToken,
        uint256 dstAmount,
        uint256 fee,
        bytes32 dstChainId
    );
    event ProveBridgeAggregatedSuccess(uint256[] orderIds);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrdersReclaimed(uint256[] orderIds);

    /// Enums
    enum OrderState {
        PENDING,
        COMPLETED,
        RECLAIMED,
        DROPPED
    }

    enum HDPProvingStatus {
        NOT_PROVEN,
        PROVEN
    }

    /// Structs
    struct Order {
        uint256 id;
        address usrSrcAddress;
        uint256 usrDstAddress;
        uint256 expirationTimestamp;
        address srcToken;
        uint256 srcAmount;
        address dstToken;
        uint256 dstAmount;
        uint256 fee;
        bytes32 dstChainId;
    }

    struct HDPConnection {
        bytes32 hdpProgramHash;
        bytes32 paymentRegistryAddress;
    }

    struct HDPConnectionInitial {
        bytes32 destinationChainId;
        bytes32 hdpProgramHash;
        bytes32 paymentRegistryAddress;
    }

    /// Constructor
    constructor(HDPConnectionInitial[] memory initialHDPChainConnections) {
        owner = msg.sender;

        // Initial destination chain connections added at the time of contract deployment
        for (uint256 i = 0; i < initialHDPChainConnections.length; i++) {
            HDPConnectionInitial memory hdpConnectionInitial = initialHDPChainConnections[i];
            hdpConnections[hdpConnectionInitial.destinationChainId] = HDPConnection({
                paymentRegistryAddress: hdpConnectionInitial.paymentRegistryAddress,
                hdpProgramHash: hdpConnectionInitial.hdpProgramHash
            });
        }
    }

    /// Functions
    ///
    /// @notice Allows the user to create an order
    ///
    /// @param _usrDstAddress The destination address of the user
    /// @param _fee           The fee for the market maker
    /// @param _dstChainId    Destination Chain Id as a hex
    function createOrder(
        uint256 _usrDstAddress,
        uint256 _fee,
        bytes32 _dstChainId,
        address _srcToken,
        uint256 _srcAmount,
        address _dstToken,
        uint256 _dstAmount
    ) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value == _srcAmount, "The amount sent must match the msg.value");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        require(supportedSrcTokens[_srcToken] == true, "The source token is not supported.");
        require(supportedDstTokensByChain[_dstChainId][_dstToken] == true, "The destination token is not supported.");

        // The order expires 24 hours after placement. If not proven by then, the user can withdraw funds.
        uint256 _expirationTimestamp = block.timestamp + ONE_DAY;

        // Store order data in a struct to avoid stack too deep issues
        Order memory orderData = Order({
            id: orderId,
            usrSrcAddress: msg.sender,
            usrDstAddress: _usrDstAddress,
            expirationTimestamp: _expirationTimestamp,
            srcToken: _srcToken,
            srcAmount: _srcAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            fee: _fee,
            dstChainId: _dstChainId
        });

        // Calculate and store order hash
        bytes32 orderHash = _createOrderHash(orderData);
        orders[orderId] = orderHash;
        orderStatus[orderId] = OrderState.PENDING;

        emit OrderPlaced(
            orderData.id,
            orderData.usrSrcAddress,
            orderData.usrDstAddress,
            orderData.expirationTimestamp,
            orderData.srcToken,
            orderData.srcAmount,
            orderData.dstToken,
            orderData.dstAmount,
            orderData.fee,
            orderData.dstChainId
        );

        orderId += 1;
    }

    /// @notice Allows a MM to prove order fulfillment by submitting the order details
    ///
    /// @param calldataOrders      Array containing the data of the orders to be proven
    /// @param _blockNumber        The point in time when all the submitted orders have been fulfilled
    /// @param _destinationChainId The chain on which the order was fulfilled
    function proveAndWithdrawBatch(Order[] calldata calldataOrders, uint256 _blockNumber, bytes32 _destinationChainId)
        public
        onlyRelayAddress
    {
        // For proving in aggregated mode using HDP
        bytes32[] memory taskInputs = new bytes32[](calldataOrders.length + 3);
        taskInputs[0] = bytes32(_destinationChainId); // The bridging destination chain, where PaymentRegistry is located
        taskInputs[1] = bytes32(hdpConnections[_destinationChainId].paymentRegistryAddress); // The address which contains the order fulfillment
        taskInputs[2] = bytes32(_blockNumber); // The point in time at which to prove the orders

        uint256 amountToWithdraw = 0;
        uint256[] memory validOrderIds = new uint256[](calldataOrders.length);

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            // validate the call data
            Order memory order = calldataOrders[i];
            bytes32 orderHash = _createOrderHash(order);

            require(orders[order.id] == orderHash, "Order hash mismatch");
            require(orderStatus[order.id] == OrderState.PENDING, "Order not in PENDING state");

            taskInputs[i + 3] = orderHash; // offset because first 3 arguments are destination chain id, payment registry address and block number
            amountToWithdraw += order.srcAmount; // srcAmount includes the fee
            validOrderIds[i] = order.id;
        }

        // Prove the HDP task
        ModuleTask memory hdpModuleTask =
            ModuleTask({programHash: bytes32(hdpConnections[_destinationChainId].hdpProgramHash), inputs: taskInputs});

        bytes32 taskCommitment = hdpModuleTask.commit(); // Calculate task commitment hash based on program hash and program inputs

        require(
            hdpExecutionStore.getDataProcessorTaskStatus(taskCommitment) == IDataProcessorModule.TaskStatus.FINALIZED,
            "HDP Task is not finalized"
        );
        require(
            hdpExecutionStore.getDataProcessorFinalizedTaskResult(taskCommitment)
                == bytes32(uint256(HDPProvingStatus.PROVEN)),
            "Unable to prove PaymentRegistry transfer execution"
        );

        // Once validated, update the status of all the orders
        for (uint256 i = 0; i < calldataOrders.length; i++) {
            orderStatus[calldataOrders[i].id] = OrderState.COMPLETED;
        }

        require(address(this).balance >= amountToWithdraw, "Escrow: Insufficient balance to withdraw");
        (bool success,) = payable(allowedWithdrawalAddress).call{value: amountToWithdraw}("");
        require(success, "Withdraw transfer failed");

        emit ProveBridgeAggregatedSuccess(validOrderIds);
    }

    /// @notice Allows the user to refund their order if it has not been fulfilled by the expiration date
    ///
    /// @custom:security This function should never be pausable
    function refundOrderBatch(Order[] calldata calldataOrders) external payable nonReentrant {
        uint256 amountToRefund = 0;
        uint256[] memory refundedOrderIds = new uint256[](calldataOrders.length);

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            Order memory order = calldataOrders[i];
            require(msg.sender == order.usrSrcAddress, "Only the original address can refund an intent.");
            bytes32 orderHash = _createOrderHash(order);

            require(orders[order.id] == orderHash, "Order hash mismatch");
            require(orderStatus[order.id] == OrderState.PENDING, "Cannot refund an order if it is not pending.");
            require(block.timestamp > order.expirationTimestamp, "Cannot refund an order that has not expired.");

            amountToRefund += order.srcAmount; // srcAmount includes the fee
            orderStatus[order.id] = OrderState.RECLAIMED;
            refundedOrderIds[i] = order.id;
        }
        require(address(this).balance >= amountToRefund, "Insufficient contract balance for refund");
        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund Order: Transfer failed");
        emit OrdersReclaimed(refundedOrderIds);
    }

    function _createOrderHash(Order memory orderDetails) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                orderDetails.id,
                orderDetails.usrSrcAddress,
                orderDetails.usrDstAddress,
                orderDetails.expirationTimestamp,
                orderDetails.srcToken,
                orderDetails.srcAmount,
                orderDetails.dstToken,
                orderDetails.dstAmount,
                orderDetails.fee,
                SRC_CHAIN_ID,
                orderDetails.dstChainId
            )
        );
    }

    /// Restricted functions
    /// @notice Pause the contract in case of an error, or contract upgrade
    function pauseContract() external onlyRelayAddress {
        _pause();
    }

    /// @notice Unpause the contract
    function unpauseContract() external onlyRelayAddress {
        _unpause();
    }

    /// @notice Change the allowed relay address
    function setAllowedAddress(address _newAllowedAddress) external onlyOwner {
        allowedRelayAddress = _newAllowedAddress;
    }

    /// @notice Check if given bridging destination chain exist
    function isHDPConnectionAvailable(bytes32 _destinationChain) public view returns (bool) {
        HDPConnection storage connection = hdpConnections[_destinationChain];
        return connection.hdpProgramHash != bytes32(0) && connection.paymentRegistryAddress != bytes32(0);
    }

    /// @notice Function called when adding a new destination chain, in Single Market Maker mode. onlyOwner modifier is used,
    ///         and the program hash cannot be modified or deleted once added
    function addDestinationChain(bytes32 _destinationChain, bytes32 _hdpProgramHash, bytes32 _paymentRegistryAddress)
        external
        onlyOwner
    {
        require(isHDPConnectionAvailable(_destinationChain) == false, "Destination chain already added");
        HDPConnection memory hdpConnection =
            HDPConnection({paymentRegistryAddress: _paymentRegistryAddress, hdpProgramHash: _hdpProgramHash});

        hdpConnections[_destinationChain] = hdpConnection;
    }

    /// @notice Add a new supported token that is able to be locked up on the source chain
    function addSupportForNewSrcToken(address _srcTokenToAdd) external onlyOwner {
        supportedSrcTokens[_srcTokenToAdd] = true;
    }

    // @notice Add a new destination token, based on the destination chain
    function addSupportForNewDstToken(bytes32 chainId, address _dstTokenToAdd) external onlyOwner {
        supportedDstTokensByChain[chainId][_dstTokenToAdd] = true;
    }

    // This is only temporary
    function setHDPAddress(address _newHDPExecutionStore) external onlyOwner {
        HDP_EXECUTION_STORE_ADDRESS = _newHDPExecutionStore;
    }

    // Public functions
    function getHDPDestinationChainConnectionDetails(bytes32 destinationChainId)
        public
        view
        returns (HDPConnection memory)
    {
        return hdpConnections[destinationChainId];
    }

    // Modifiers
    modifier onlyRelayAddress() {
        require(msg.sender == allowedRelayAddress, "Caller is not allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
}

