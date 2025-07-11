// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ModuleTask, ModuleCodecs} from "lib/herodotus-evm-v2/src/libraries/internal/data-processor/ModuleCodecs.sol";
import {IDataProcessorModule} from "lib/herodotus-evm-v2/src/interfaces/modules/IDataProcessorModule.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {MerkleHelper} from "src/libraries/MerkleHelper.sol";

/// @title Escrow
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Handles the bridging and swapping of assets between a src chain and a dst chain, in conjunction with
///         Payment Registry and a facilitator service
///
contract Escrow is ReentrancyGuard, Pausable {
    using ModuleCodecs for ModuleTask;
    using SafeERC20 for IERC20;

    // State variables
    address public owner;
    uint256 private orderId = 1;

    // HDP
    address public HDP_EXECUTION_STORE_ADDRESS = 0x59c0B3D09151aA2C0201808fEC0860f1168A4173;
    bytes32 private constant HDP_EMPTY_OUTPUT_TREE_HASH =
        0x6612f7b477d66591ff96a9e064bcc98abc36789e7a1e281436464229828f817d;

    // Interfaces
    IDataProcessorModule hdpExecutionStore = IDataProcessorModule(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(bytes32 => OrderState) public orderStatus;
    mapping(bytes32 => HDPConnection) public hdpConnections; // mapping chainId -> HdpConnection
    mapping(bytes32 => Swap) public swaps; // mapping swapId -> Swap

    /// Events
    /// @param usrDstAddress Stored as a bytes32 to allow for foreign addresses to be stored
    /// @param dstToken      Stored as a bytes32 to allow for foreign addresses to be stored
    event OrderPlaced(
        uint256 orderId,
        address usrSrcAddress,
        bytes32 usrDstAddress,
        uint256 expirationTimestamp,
        address srcToken,
        uint256 srcAmount,
        bytes32 dstToken,
        uint256 dstAmount,
        bytes32 dstChainId
    );
    event ProveBridgeAggregatedSuccess(bytes32[] orderHashes);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrderReclaimed(uint256 orderId);
    event SwapCompleted(
        bytes32 indexed swapId, address user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut
    );

    /// Enums
    enum OrderState {
        DOES_NOT_EXIST,
        PENDING,
        COMPLETED,
        RECLAIMED
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
        bytes32 dstChainId;
    }

    struct Hook {
        address target;
        bytes callData;
    }

    struct Swap {
        address user;
        address originalToken;
        uint256 originalAmount;
        address swappedToken;
        uint256 swappedAmount;
        bool executorReturned;
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

    ///  Allow the contract to receive ETH from the self-destruct function
    receive() external payable {}

    /// Functions
    ///
    /// @notice Allows the user to create an order
    ///
    /// @param _usrDstAddress The destination address of the user
    /// @param _srcToken      The source token address, address(0) for native eth
    /// @param _srcAmount     The amount of the source token deposited by the user
    /// @param _dstToken      The destination token address, bytes32 for foreign chain tokens
    /// @param _dstAmount     The amount of the destination token to be received by the user
    /// @param _dstChainId    Destination Chain Id as a hex
    /// @param _expiryWindow  The time window in seconds after which the order expires
    /// @notice srcToken and usrSrcAddress are native to this chain (EVM), so stored as `address`
    /// @notice dstToken and usrDstAddress are for a foreign chain (e.g., Starknet), so stored as `bytes32`
    function createOrder(
        bytes32 _usrDstAddress,
        address _srcToken,
        uint256 _srcAmount,
        bytes32 _dstToken,
        uint256 _dstAmount,
        bytes32 _dstChainId,
        uint256 _expiryWindow,
        bool useSwap,
        Hook[] calldata hooks
    ) external payable nonReentrant whenNotPaused {
        uint256 finalSrcAmount = _srcAmount;
        address finalSrcToken = _srcToken;

        if (useSwap) {
            require(_srcToken != address(0), "Swaps require ERC20 tokens");
            require(msg.value == 0, "Swaps require msg.value to be 0");
            require(hooks.length > 0, "Swaps require at least one hook");

            bytes32 swapId = keccak256(abi.encodePacked(orderId, msg.sender, _srcToken, _srcAmount, block.timestamp));
            require(swaps[swapId].user == address(0), "Swap already exists for this ID"); //safety check

            swaps[swapId] = Swap({
                user: msg.sender,
                originalToken: _srcToken,
                originalAmount: _srcAmount,
                swappedToken: address(0),
                swappedAmount: 0,
                executorReturned: false
            });

            IERC20(_srcToken).safeTransferFrom(msg.sender, address(this), _srcAmount);

            // Deploy executor
            HookExecutor executor = new HookExecutor();
            IERC20(_srcToken).safeTransfer(address(executor), _srcAmount);

            // TODO: need to let the executor know what the swap out token is supposed to be
            executor.execute(swapId, hooks, _srcToken, SWAP_OUT_TOKEN_HERE, address(this));

            // verify that the executor was successful
            Swap storage swap = swaps[swapId];
            require(swap.executorReturned, "Executor failed to return");
            require(swap.swappedToken != address(0), "Executor did not swap token");

            finalSrcToken = swap.swappedToken;
            finalSrcAmount = swap.swappedAmount;
        } else {
            bool isNativeToken = _srcToken == address(0);
            if (isNativeToken) {
                // Native ETH logic
                require(msg.value > 0, "Funds being sent must be greater than 0");
                require(msg.value == _srcAmount, "The amount sent must match the msg.value");
            } else {
                // ERC20 logic
                require(msg.value == 0, "ERC20: msg.value must be 0");
                require(_srcAmount > 0, "ERC20: _srcAmount must be greater than 0");

                IERC20(_srcToken).safeTransferFrom(msg.sender, address(this), _srcAmount);
            }
        }
        // The order expires within the expiry window. If not proven by then, the user can withdraw funds
        uint256 _expirationTimestamp = block.timestamp + _expiryWindow;

        // Store order data in a struct to avoid stack too deep issues
        Order memory orderData = Order({
            id: orderId,
            usrSrcAddress: msg.sender,
            usrDstAddress: _usrDstAddress,
            expirationTimestamp: _expirationTimestamp,
            srcToken: finalSrcToken,
            srcAmount: finalSrcAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            dstChainId: _dstChainId
        });

        // Calculate and store order hash
        bytes32 orderHash = _createOrderHash(orderData);
        orderStatus[orderHash] = OrderState.PENDING;

        emit OrderPlaced(
            orderData.id,
            orderData.usrSrcAddress,
            orderData.usrDstAddress,
            orderData.expirationTimestamp,
            orderData.srcToken,
            orderData.srcAmount,
            orderData.dstToken,
            orderData.dstAmount,
            orderData.dstChainId
        );

        orderId += 1;
    }

    function onExecutorReturn(bytes32 swapId, address swappedToken, uint256 swappedAmount) external {
        Swap storage swap = swaps[swapId];
        require(swap.user != address(0), "Swap does not exist");
        require(swap.executorReturned == false, "Executor already returned");

        swap.swappedToken = swappedToken;
        swap.swappedAmount = swappedAmount;
        swap.executorReturned = true;

        emit SwapCompleted(swapId, swap.user, swap.srcToken, swap.srcAmount, swap.swappedToken, swap.swappedAmount);
    }

    /// @notice Allows a MM to prove order fulfillment by submitting the orders details and necessary proving info
    ///
    /// @param ordersHashes      Array containing the data of the orders to be proven
    /// @param _blockNumber        The point in time when all the submitted orders have been fulfilled
    /// @param _destinationChainId The chain on which the order was fulfilled
    /// @param _lowestExpirationTimestamp The lowest order expiration timestamp across this proving batch
    /// @param _ordersWithdrawals Summarized amounts for each market maker of each token to withdraw - token address and amount pair
    function proveAndWithdrawBatch(
        bytes32[] calldata ordersHashes,
        uint256 _blockNumber,
        bytes32 _destinationChainId,
        uint256 _lowestExpirationTimestamp,
        MerkleHelper.OrdersWithdrawal[] memory _ordersWithdrawals
    ) public nonReentrant {
        require(_lowestExpirationTimestamp >= block.timestamp, "At least one order has expired");

        // For proving in aggregated mode using HDP
        bytes32[] memory taskInputs = new bytes32[](ordersHashes.length + 3);
        taskInputs[0] = bytes32(_destinationChainId);
        taskInputs[1] = bytes32(hdpConnections[_destinationChainId].paymentRegistryAddress);
        taskInputs[2] = bytes32(_blockNumber);

        for (uint256 i = 0; i < ordersHashes.length; i++) {
            require(orderStatus[ordersHashes[i]] == OrderState.PENDING, "Order not in PENDING state");

            taskInputs[i + 3] = ordersHashes[i]; // offset because first 3 arguments are destination chain id, payment registry address and block number
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
            isOrdersFulfillmentVerified: true,
            lowestExpirationTimestamp: _lowestExpirationTimestamp,
            ordersWithdrawals: _ordersWithdrawals
        });

        bytes32 computedMerkleRoot = MerkleHelper.computeHDPTaskOutputMerkleRoot(expectedHdpTaskOutput);

        // Validate that the computed Merkle root matches the finalized HDP task result
        // This ensures that the output form HDP module is authentic
        // The merkle tree leaves are the data returned from HDP module - orders withdrawals amounts including the minimum expiration timestamp among orders
        // Then we check if the merkle root calculated here matches with the HDP task output
        //
        bytes32 hdpModuleOutputMerkleRoot = hdpExecutionStore.getDataProcessorFinalizedTaskResult(taskCommitment);
        require(hdpModuleOutputMerkleRoot == computedMerkleRoot, "Unable to prove: merkle root mismatch");

        // Once validated, update the status of all the orders
        for (uint256 i = 0; i < ordersHashes.length; i++) {
            orderStatus[ordersHashes[i]] = OrderState.COMPLETED;
        }

        // Withdraw all tokens (including ETH if tokenAddress == address(0))
        for (uint256 i = 0; i < _ordersWithdrawals.length; ++i) {
            for (uint256 j = 0; j < _ordersWithdrawals[i].balancesToWithdraw.length; j++) {
                address token = _ordersWithdrawals[i].balancesToWithdraw[j].tokenAddress;
                uint256 amount = _ordersWithdrawals[i].balancesToWithdraw[j].summarizedAmount;
                if (token == address(0)) {
                    require(address(this).balance >= amount, "Insufficient ETH balance");
                    (bool success,) = payable(_ordersWithdrawals[i].marketMakerAddress).call{value: amount}("");
                    require(success, "ETH transfer failed");
                } else {
                    IERC20(token).safeTransfer(_ordersWithdrawals[i].marketMakerAddress, amount);
                }
            }
        }

        emit ProveBridgeAggregatedSuccess(ordersHashes);
    }

    /// @notice Allows the user to refund their order if it has not been fulfilled by the expiration date
    ///
    /// @param order Data of the order to be refunded
    /// @custom:security This function should never be pausable
    function refundOrder(Order calldata order) external payable nonReentrant {
        bytes32 orderHash = _createOrderHash(order);

        require(msg.sender == order.usrSrcAddress, "Only the original address can refund an order");
        require(orderStatus[orderHash] == OrderState.PENDING, "Cannot refund a non-pending order");
        require(block.timestamp > order.expirationTimestamp, "Order has not expired yet");

        orderStatus[orderHash] = OrderState.RECLAIMED;

        if (order.srcToken == address(0)) {
            // Native ETH refund
            require(address(this).balance >= order.srcAmount, "Insufficient ETH balance");
            (bool success,) = payable(msg.sender).call{value: order.srcAmount}("");
            require(success, "ETH refund failed");
        } else {
            // ERC20 token refund
            IERC20(order.srcToken).safeTransfer(msg.sender, order.srcAmount);
        }

        emit OrderReclaimed(order.id);
    }

    /// @notice Creates a hash of the order details
    ///
    /// @param orderDetails The details of the order to be hashed
    /// @return bytes32 The hash of the order details
    function _createOrderHash(Order memory orderDetails) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                orderDetails.id, // uint256
                address(this), // address
                orderDetails.usrSrcAddress, // address
                orderDetails.usrDstAddress, // bytes32
                orderDetails.expirationTimestamp, // uint256
                orderDetails.srcToken, // address
                orderDetails.srcAmount, // uint256
                orderDetails.dstToken, // bytes32
                orderDetails.dstAmount, // uint256
                block.chainid, // uint256
                orderDetails.dstChainId // bytes32
            )
        );
    }

    /// Restricted functions
    /// @notice Pause the contract in case of an error, or contract upgrade
    function pauseContract() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpauseContract() external onlyOwner {
        _unpause();
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
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
}
