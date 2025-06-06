// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {ModuleTask, ModuleCodecs} from "lib/herodotus-evm-v2/src/libraries/internal/data-processor/ModuleCodecs.sol";
import {IDataProcessorModule} from "lib/herodotus-evm-v2/src/interfaces/modules/IDataProcessorModule.sol";
import {MerkleHelper} from "src/contracts/libraries/MerkleHelper.sol";

/// @title Escrow SMM (Single Market Maker)
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Handles the bridging of assets between a src chain and a dst chain, in conjunction with Payment Registry and a
///         facilitator service.
contract Escrow is ReentrancyGuard, Pausable {
    using ModuleCodecs for ModuleTask;
    using SafeERC20 for IERC20;

    // State variables
    uint256 private orderId = 1;
    address public owner;
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying fulfilled orders
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    uint256 public constant ONE_DAY = 1 days;
    bytes32 public constant SRC_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000AA36A7; // THIS SHOULD BE ETH MAINNET
    // bytes32 public constant SRC_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000000001;

    // HDP
    address public HDP_EXECUTION_STORE_ADDRESS = 0x59c0B3D09151aA2C0201808fEC0860f1168A4173;
    bytes32 private constant HDP_EMPTY_OUTPUT_TREE_HASH =
        0x6612f7b477d66591ff96a9e064bcc98abc36789e7a1e281436464229828f817d;

    // Interfaces
    IDataProcessorModule hdpExecutionStore = IDataProcessorModule(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(uint256 => bytes32) public orders;
    mapping(uint256 => OrderState) public orderStatus;
    mapping(bytes32 => HDPConnection) public hdpConnections; // mapping chainId -> HdpConnection

    /// Events
    /// @param usrDstAddress Stored as a bytes32 to allow for Starknet addresses to be stored
    /// @param dstToken      Stored as a bytes32 to allow for Starknet addresses to be stored
    event OrderPlaced(
        uint256 orderId,
        address usrSrcAddress,
        bytes32 usrDstAddress,
        uint256 expirationTimestamp,
        address srcToken,
        uint256 srcAmount,
        bytes32 dstToken,
        uint256 dstAmount,
        bytes32 srcChainId,
        bytes32 dstChainId
    );
    event ProveBridgeAggregatedSuccess(uint256[] orderIds);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrdersReclaimed(uint256 orderId);

    /// Enums
    enum OrderState {
        PENDING,
        COMPLETED,
        RECLAIMED,
        DROPPED // TODO: this does not get used

    }

    enum HDPProvingStatus {
        NOT_PROVEN,
        PROVEN
    }

    /// Structs
    struct Order {
        uint256 id;
        address usrSrcAddress;
        bytes32 usrDstAddress;
        uint256 expirationTimestamp;
        address srcToken;
        uint256 srcAmount;
        bytes32 dstToken;
        uint256 dstAmount;
        bytes32 srcChainId;
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
    /// @param _dstChainId    Destination Chain Id as a hex
    /// @notice srcToken and usrSrcAddress are native to this chain (EVM), so stored as `address`
    /// @notice dstToken and usrDstAddress are for a foreign chain (e.g., Starknet), so stored as `bytes32`
    function createOrder(
        bytes32 _usrDstAddress,
        address _srcToken,
        uint256 _srcAmount,
        bytes32 _dstToken,
        uint256 _dstAmount,
        bytes32 _dstChainId
    ) external payable nonReentrant whenNotPaused {
        bool isNativeToken = _srcToken == address(0);
        // require(_dstChainId != SRC_CHAIN_ID, "Cannot create order for the source chain"); // this would actually disable pure swaps on the same chain, which is not something that we want to do
        // require(isHDPConnectionAvailable(_dstChainId), "Destination chain is not available");

        if (isNativeToken) {
            // Native ETH logic
            require(msg.value > 0, "Funds being sent must be greater than 0");
            require(msg.value == _srcAmount, "The amount sent must match the msg.value");
            // todo: maybe add a dst amount check that it's > 0
        } else {
            // ERC20 logic
            require(msg.value == 0, "ERC20: msg.value must be 0");
            require(_srcAmount > 0, "ERC20: _srcAmount must be greater than 0");

            IERC20(_srcToken).safeTransferFrom(msg.sender, address(this), _srcAmount);
        }

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
            srcChainId: SRC_CHAIN_ID,
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
            orderData.srcChainId,
            orderData.dstChainId
        );

        orderId += 1;
    }

    /// @notice Allows a MM to prove order fulfillment by submitting the order details
    ///
    /// @param calldataOrders      Array containing the data of the orders to be proven
    /// @param _blockNumber        The point in time when all the submitted orders have been fulfilled
    /// @param _destinationChainId The chain on which the order was fulfilled
    /// @param _balancesToWithdraw Summarized amounts of each token to withdraw - token address and amount pair
    function proveAndWithdrawBatch(
        Order[] calldata calldataOrders,
        uint256 _blockNumber,
        bytes32 _destinationChainId,
        MerkleHelper.BalanceToWithdraw[] memory _balancesToWithdraw
    ) public onlyRelayAddress {
        // For proving in aggregated mode using HDP
        bytes32[] memory taskInputs = new bytes32[](calldataOrders.length + 3);
        taskInputs[0] = bytes32(_destinationChainId);
        taskInputs[1] = bytes32(hdpConnections[_destinationChainId].paymentRegistryAddress);
        taskInputs[2] = bytes32(_blockNumber);

        uint256[] memory validOrderIds = new uint256[](calldataOrders.length);

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            // validate the call data
            Order memory order = calldataOrders[i];
            bytes32 orderHash = _createOrderHash(order);

            require(orders[order.id] == orderHash, "Order hash mismatch");
            require(orderStatus[order.id] == OrderState.PENDING, "Order not in PENDING state");

            taskInputs[i + 3] = orderHash; // offset because first 3 arguments are destination chain id, payment registry address and block number

            validOrderIds[i] = order.id;
        }

        // HDP verification code
        ModuleTask memory hdpModuleTask =
            ModuleTask({programHash: bytes32(hdpConnections[_destinationChainId].hdpProgramHash), inputs: taskInputs});

        bytes32 taskCommitment = hdpModuleTask.commit(); // Calculate task commitment hash based on program hash and program inputs

        require(
            hdpExecutionStore.getDataProcessorTaskStatus(taskCommitment) == IDataProcessorModule.TaskStatus.FINALIZED,
            "HDP Task is not finalized"
        );

        MerkleHelper.HDPTaskOutput memory expectedHdpTaskOutput = MerkleHelper.HDPTaskOutput({
            isOrdersFulfillmentVerified: bytes32(uint256(1)),
            tokensBalancesArrayLength: _balancesToWithdraw.length,
            tokensBalancesArray: _balancesToWithdraw
        });

        bytes32 computedMerkleRoot = MerkleHelper.computeTaskOutputMerkleRoot(expectedHdpTaskOutput);

        require(
            hdpExecutionStore.getDataProcessorFinalizedTaskResult(taskCommitment) == computedMerkleRoot,
            "Unable to prove: merkle root mismatch"
        );

        // Once validated, update the status of all the orders
        for (uint256 i = 0; i < calldataOrders.length; i++) {
            orderStatus[calldataOrders[i].id] = OrderState.COMPLETED;
        }

        // Withdraw all tokens (including ETH if tokenAddress == address(0))
        for (uint256 i = 0; i < _balancesToWithdraw.length; i++) {
            address token = _balancesToWithdraw[i].tokenAddress;
            uint256 amount = _balancesToWithdraw[i].summarizedAmount;
            if (amount > 0) {
                if (token == address(0)) {
                    require(address(this).balance >= amount, "Insufficient ETH balance");
                    (bool success,) = payable(allowedWithdrawalAddress).call{value: amount}("");
                    require(success, "ETH transfer failed");
                } else {
                    require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");
                    IERC20(token).safeTransfer(allowedWithdrawalAddress, amount);
                }
            }
        }

        emit ProveBridgeAggregatedSuccess(validOrderIds);
    }

    /// @notice Allows the user to refund their order if it has not been fulfilled by the expiration date
    ///
    /// @custom:security This function should never be pausable
    function refundOrder(Order calldata order) external payable nonReentrant {
        require(msg.sender == order.usrSrcAddress, "Only the original address can refund an intent");

        bytes32 orderHash = _createOrderHash(order);
        require(orders[order.id] == orderHash, "Order hash mismatch");
        require(orderStatus[order.id] == OrderState.PENDING, "Cannot refund a non-pending order");
        require(block.timestamp > order.expirationTimestamp, "Order has not expired yet");
        require(order.srcChainId == SRC_CHAIN_ID, "Order is not from the source chain");

        orderStatus[order.id] = OrderState.RECLAIMED;

        if (order.srcToken == address(0)) {
            // Native ETH refund
            require(address(this).balance >= order.srcAmount, "Insufficient ETH balance");
            (bool success,) = payable(msg.sender).call{value: order.srcAmount}("");
            require(success, "ETH refund failed");
        } else {
            // ERC20 token refund
            require(IERC20(order.srcToken).balanceOf(address(this)) >= order.srcAmount, "Insufficient ERC20 balance");
            IERC20(order.srcToken).safeTransfer(msg.sender, order.srcAmount);
        }

        emit OrdersReclaimed(order.id);
    }

    function _createOrderHash(Order memory orderDetails) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                orderDetails.id, // uint256
                orderDetails.usrSrcAddress, // address
                orderDetails.usrDstAddress, // bytes32
                orderDetails.expirationTimestamp, // uint256
                orderDetails.srcToken, // address
                orderDetails.srcAmount, // uint256
                orderDetails.dstToken, // bytes32
                orderDetails.dstAmount, // uint256
                orderDetails.srcChainId, // bytes32
                orderDetails.dstChainId // bytes32
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
