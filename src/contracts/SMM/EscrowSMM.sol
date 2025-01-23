// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ModuleTask} from "lib/hdp-solidity/src/datatypes/module/ModuleCodecs.sol";
import {ModuleCodecs} from "lib/hdp-solidity/src/datatypes/module/ModuleCodecs.sol";
import {TaskCode} from "lib/hdp-solidity/src/datatypes/Task.sol";
import {IHdpExecutionStore} from "src/interface/IHdpExecutionStore.sol";

/**
 * @title Escrow Contract SMM (Single Market Maker)
 * @dev Handles the bridging of assets between a src chain and a dst chain, in conjunction with Payment Registry and a
 * facilitator service.
 */
contract Escrow is ReentrancyGuard, Pausable {
    using ModuleCodecs for ModuleTask;

    // State variables
    address public owner;
    uint256 private orderId = 1;
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying fulfilled orders
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;

    // HDP
    address public HDP_EXECUTION_STORE_ADDRESS = 0x68a011d3790e7F9038C9B9A4Da7CD60889EECa70;

    // Interfaces
    IHdpExecutionStore hdpExecutionStore = IHdpExecutionStore(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(uint256 => bytes32) public orders;
    mapping(uint256 => OrderState) public orderStatus;
    mapping(bytes32 => HDPConnection) public hdpConnections; // mapping chainId -> HdpConnection

    // Events
    /**
     * @param usrDstAddress stored as a uint256 to allow for starknet addresses to be stored
     * @param dstChainId stored passed as a hex
     */
    event OrderPlaced(
        uint256 orderId,
        uint256 usrDstAddress,
        uint256 expirationTimestamp,
        uint256 amount,
        uint256 fee,
        address usrSrcAddress,
        bytes32 dstChainId
    );
    event ProveBridgeAggregatedSuccess(uint256[] orderIds);
    event WithdrawSuccessBatch(uint256[] orderIds);
    event OrderReclaimed(uint256 orderId);

    //Enums
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
        uint256 id;
        uint256 usrDstAddress;
        uint256 expirationTimestamp;
        uint256 bridgeAmount;
        uint256 fee;
        address usrSrcAddress;
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

    // Constructor
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

    // Functions
    /**
     * @dev Allows the user to create an order.
     * @param _usrDstAddress The destination address of the user.
     * @param _fee The fee for the market maker.
     * @param _dstChainId Destination Chain Id as a hex.
     */
    function createOrder(uint256 _usrDstAddress, uint256 _fee, bytes32 _dstChainId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(msg.value > 0, "Funds being sent must be greater than 0.");
        require(msg.value > _fee, "Fee must be less than the total value sent");

        uint256 currentTimestamp = block.timestamp;
        uint256 _expirationTimestamp = currentTimestamp + 6 weeks;
        address _usrSrcAddress = msg.sender;
        uint256 bridgeAmount = msg.value - _fee; //no underflow since previous check is made

        bytes32 orderHash = keccak256(
            abi.encodePacked(
                orderId, _usrDstAddress, _expirationTimestamp, bridgeAmount, _fee, _usrSrcAddress, _dstChainId
            )
        );

        orders[orderId] = orderHash;
        orderStatus[orderId] = OrderState.PENDING;

        emit OrderPlaced(orderId, _usrDstAddress, _expirationTimestamp, bridgeAmount, _fee, _usrSrcAddress, _dstChainId);

        orderId += 1;
    }

    function proveHDPFulfillmentBatch(
        Order[] calldata calldataOrders,
        uint256 _blockNumber,
        bytes32 _destinationChainId
    ) public onlyRelayAddress {
        // For proving in aggregated mode using HDP
        bytes32[] memory taskInputs = new bytes32[](calldataOrders.length + 3);
        taskInputs[0] = bytes32(_destinationChainId); // The bridging destination chain, where PaymentRegistry is located
        taskInputs[1] = bytes32(hdpConnections[_destinationChainId].paymentRegistryAddress); // The point in time at which to prove the orders
        taskInputs[2] = bytes32(_blockNumber); // The point in time at which to prove the orders

        for (uint256 i = 0; i < calldataOrders.length; i++) {
            // validate the call data
            Order memory order = calldataOrders[i];
            bytes32 orderHash = keccak256(
                abi.encodePacked(
                    order.id,
                    order.usrDstAddress,
                    order.expirationTimestamp,
                    order.bridgeAmount,
                    order.fee,
                    order.usrSrcAddress,
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

    /**
     * @dev Allows the market maker to batch unlock the funds for transactions fulfilled by them.
     */
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
                    order.usrDstAddress,
                    order.expirationTimestamp,
                    order.bridgeAmount,
                    order.fee,
                    order.usrSrcAddress,
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

    /**
     * @dev Allows the user to withdraw their order if it has not been fulfilled by the expiration date.
     * Note: this function should never be pausable.
     */
    function refundOrder(
        uint256 _orderId,
        uint256 _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _bridgeAmount,
        uint256 _fee,
        bytes32 _dstChainId
    ) external payable nonReentrant {
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                _orderId, _usrDstAddress, _expirationTimestamp, _bridgeAmount, _fee, msg.sender, _dstChainId
            )
        );
        require(orders[_orderId] == orderHash, "Order hash mismatch");
        require(orderStatus[_orderId] == OrderState.PENDING, "Cannot refund an order if it is not pending.");
        uint256 currentTimestamp = block.timestamp;
        require(currentTimestamp > _expirationTimestamp, "Cannot refund an order that has not expired.");

        uint256 amountToRefund = _bridgeAmount + _fee;
        require(address(this).balance >= amountToRefund, "Insufficient contract balance for refund");

        orderStatus[_orderId] = OrderState.RECLAIMED;

        (bool success,) = payable(msg.sender).call{value: amountToRefund}("");
        require(success, "Refund Order: Transfer failed");
        emit OrderReclaimed(_orderId);
    }

    // Restricted functions
    /**
     * @dev Pause the contract in case of an error.
     */
    function pauseContract() external onlyRelayAddress {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpauseContract() external onlyRelayAddress {
        _unpause();
    }

    /**
     * @dev Change the allowed relay address.
     */
    function setAllowedAddress(address _newAllowedAddress) external onlyOwner {
        allowedRelayAddress = _newAllowedAddress;
    }

    // Function called when we adding new destination chain, in Single Market Maker mode onlyOwner modifier is used, and the program hash cannot be modified or deleted once added
    function addDestinationChain(bytes32 _destinationChain, bytes32 _hdpProgramHash, bytes32 _paymentRegistryAddress)
        external
        onlyOwner
    {
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
