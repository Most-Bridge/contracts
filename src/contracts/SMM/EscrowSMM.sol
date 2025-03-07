// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ModuleTask} from "lib/hdp-solidity/src/datatypes/module/ModuleCodecs.sol";
import {ModuleCodecs} from "lib/hdp-solidity/src/datatypes/module/ModuleCodecs.sol";
import {TaskCode} from "lib/hdp-solidity/src/datatypes/Task.sol";
import {IHdpExecutionStore} from "src/interface/IHdpExecutionStore.sol";

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

    // HDP
    address public HDP_EXECUTION_STORE_ADDRESS = 0xE321b311d860fA58a110fC93b756138678e0d00d;

    // Interfaces
    IHdpExecutionStore hdpExecutionStore = IHdpExecutionStore(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(uint256 => bytes32) public orders;
    mapping(uint256 => OrderState) public orderStatus;
    mapping(bytes32 => HDPConnection) public hdpConnections; // mapping chainId -> HdpConnection
    mapping(address => bool) public supportedSrcTokens;
    mapping(address => mapping(address => bool)) supportedDstTokensByChain; // mapping chainId -> token address -> is supported?

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
        PROVED,
        COMPLETED,
        RECLAIMED,
        DROPPED
    }

    enum HDPProvingStatus {
        NOT_PROVEN,
        PROVEN
    }

    // Structs
    struct Order {
        uint256 orderId;
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

    // address srcToken +
    //     uint256 srcAmount
    //     address dstToken,
    //     uint256 dstAmount,

    // should i do a separate logic for native eth vs non native eth?

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
        require(msg.value > _fee, "Fee must be less than the total value sent");

        require(supportedSrcTokens[_srcToken] == true, "The source token is not supported.");
        require(supportedDstTokensByChain[_dstChainId][_dstToken] == true, "The destination token is not supported.");

        require(supportedSrcTokens[_srcToken] == true, "The source token is not supported.");
        require(supportedDstTokensByChain[_dstChainId][_dstToken] == true, "The destination token is not supported.");

        // The order expires 24 hours after placement. If not proven by then, the user can withdraw funds.
        uint256 currentTimestamp = block.timestamp;
        uint256 _expirationTimestamp = currentTimestamp + ONE_DAY;
        address _usrSrcAddress = msg.sender;
        uint256 _bridgeAmount = msg.value - _fee; //no underflow since previous check is made

        bytes32 orderHash = keccak256(
            abi.encodePacked(
                orderId,
                _usrSrcAddress,
                _usrDstAddress,
                _expirationTimestamp,
                _srcToken,
                _srcAmount,
                _dstToken,
                _dstAmount,
                _fee,
                _dstChainId
            )
        );

        orders[orderId] = orderHash;
        orderStatus[orderId] = OrderState.PENDING;

        emit OrderPlaced(
            orderId,
            _usrSrcAddress,
            _usrDstAddress,
            _expirationTimestamp,
            _srcToken,
            _srcAmount,
            _dstToken,
            _dstAmount,
            _fee,
            _dstChainId
        );

        orderId += 1;
    }

    /// @notice Allows a MM to prove order fulfillment by submitting the order details
    ///
    /// @param calldataOrders      Array containing the data of the orders to be proven
    /// @param _blockNumber        The point in time when all the submitted orders have been fulfilled
    /// @param _destinationChainId The chain on which the order was fulfilled
    function proveHDPFulfillmentBatch(
        Order[] calldata calldataOrders,
        uint256 _blockNumber,
        bytes32 _destinationChainId
    ) public onlyRelayAddress {
        // For proving in aggregated mode using HDP
        bytes32[] memory taskInputs = new bytes32[](calldataOrders.length + 3);
        taskInputs[0] = bytes32(_destinationChainId); // The bridging destination chain, where PaymentRegistry is located
        taskInputs[1] = bytes32(hdpConnections[_destinationChainId].paymentRegistryAddress); // The address which contains the order fulfillment
        taskInputs[2] = bytes32(_blockNumber); // The point in time at which to prove the orders

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            // validate the call data
            Order memory order = calldataOrders[i];
            bytes32 orderHash = keccak256(
                abi.encodePacked(
                    order.id,
                    order.usrSrcAddress,
                    order.usrDstAddress,
                    order.expirationTimestamp,
                    order.srcToken,
                    order.srcAmount,
                    order.dstToken,
                    order.dstAmount,
                    order.fee,
                    order.dstChainId
                )
            );
            require(orders[order.id] == orderHash, "Order hash mismatch");
            taskInputs[i + 3] = orderHash; // offset because first 3 arguments are destination chain id, payment registry address and block number
        }

        ModuleTask memory hdpModuleTask =
            ModuleTask({programHash: bytes32(hdpConnections[_destinationChainId].hdpProgramHash), inputs: taskInputs});
        bytes32 taskCommitment = hdpModuleTask.commit(); // Calculate task commitment hash based on program hash and program inputs
        require(
            hdpExecutionStore.cachedTasksResult(taskCommitment).status == IHdpExecutionStore.TaskStatus.FINALIZED,
            "HDP Task is not finalized"
        );
        require(
            hdpExecutionStore.getFinalizedTaskResult(taskCommitment) == bytes32(uint256(HDPProvingStatus.PROVEN)),
            "Unable to prove PaymentRegistry transfer execution"
        );

        uint256[] memory provedOrderIds = new uint256[](calldataOrders.length);
        for (uint256 i = 0; i < calldataOrders.length; i++) {
            orderStatus[calldataOrders[i].id] = OrderState.PROVED;
            provedOrderIds[i] = calldataOrders[i].id;
        }
        emit ProveBridgeAggregatedSuccess(provedOrderIds);
    }

    /// @notice Allows the market maker to batch unlock the funds for transactions fulfilled by them
    ///
    /// @param calldataOrders Order info of the orders to be withdrawn
    function withdrawProvedBatch(Order[] calldata calldataOrders)
        external
        nonReentrant
        whenNotPaused
        onlyRelayAddress
    {
        uint256 amountToWithdraw = 0;
        uint256[] memory withdrawnOrderIds = new uint256[](calldataOrders.length);

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            Order memory order = calldataOrders[i];
            bytes32 orderHash = keccak256(
                abi.encodePacked(
                    order.id,
                    order.usrSrcAddress,
                    order.usrDstAddress,
                    order.expirationTimestamp,
                    order.srcToken,
                    order.srcAmount,
                    order.dstToken,
                    order.dstAmount,
                    order.fee,
                    order.dstChainId
                )
            );
            require(orders[order.id] == orderHash, "Order hash mismatch");
            require(orderStatus[order.id] == OrderState.PROVED, "Order has not been proved");

            amountToWithdraw += order.bridgeAmount + order.fee;
            orderStatus[order.id] = OrderState.COMPLETED;
            withdrawnOrderIds[i] = order.id;
        }
        // payout MM
        require(address(this).balance >= amountToWithdraw, "Escrow: Insufficient balance to withdraw");
        (bool success,) = payable(allowedWithdrawalAddress).call{value: amountToWithdraw}("");
        require(success, "Withdraw Proved Batch: Transfer failed");
        emit WithdrawSuccessBatch(withdrawnOrderIds);
    }

    /// @notice Allows the user to refund their order if it has not been fulfilled by the expiration date
    ///
    /// @custom:security This function should never be pausable
    function refundOrderBatch(Order[] calldata calldataOrders) external payable nonReentrant {
        uint256 amountToRefund = 0;
        uint256[] memory refundedOrderIds = new uint256[](calldataOrders.length);
        address _usrSrcAddress = msg.sender;

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            Order memory order = calldataOrders[i];
            bytes32 orderHash = keccak256(
                abi.encodePacked(
                    order.id,
                    _usrSrcAddress,
                    order.usrDstAddress,
                    order.expirationTimestamp,
                    order.srcToken,
                    order.srcAmount,
                    order.dstToken,
                    order.dstAmount,
                    order.fee,
                    order.dstChainId
                )
            );

            require(orders[order.id] == orderHash, "Order hash mismatch");
            require(orderStatus[order.id] == OrderState.PENDING, "Cannot refund an order if it is not pending.");
            require(block.timestamp > order.expirationTimestamp, "Cannot refund an order that has not expired.");

            amountToRefund += order.bridgeAmount + order.fee;
            orderStatus[order.id] = OrderState.RECLAIMED;
            refundedOrderIds[i] = order.id;
        }
        require(address(this).balance >= amountToRefund, "Insufficient contract balance for refund");
        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund Order: Transfer failed");
        emit OrdersReclaimed(refundedOrderIds);
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

    /// @notice Function called when adding a new destination chain, in Single Market Maker mode. onlyOwner modifier is used,
    ///         and the program hash cannot be modified or deleted once added
    function addDestinationChain(bytes32 _destinationChain, bytes32 _hdpProgramHash, bytes32 _paymentRegistryAddress)
        external
        onlyOwner
    {
        HDPConnection memory hdpConnection =
            HDPConnection({paymentRegistryAddress: _paymentRegistryAddress, hdpProgramHash: _hdpProgramHash});

        hdpConnections[_destinationChain] = hdpConnection;
    }

    function addSupportForNewSrcToken(address _srcTokenToAdd) external onlyOwner {
        supportedSrcTokens[_tokenToAdd] == true;
    }

    function addSupportForNewDstToken(bytes32 chainId, address _dstTokenToAdd) external onlyOwner {
        supportedDstTokensByChain[chainId][_dstTokenToAdd] == true;
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
