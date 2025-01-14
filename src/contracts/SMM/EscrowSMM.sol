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
 * @dev Handles the bridging of assets between a src chain and a dst chain, in conjunction with Payment Registry and a 3rd party
 * facilitator service.
 */
interface IFactsRegistry {
    function accountStorageSlotValues(address account, uint256 blockNumber, bytes32 slot)
        external
        view
        returns (bytes32);
}

contract Escrow is ReentrancyGuard, Pausable {
    using ModuleCodecs for ModuleTask;

    // State variables
    address public owner;
    uint256 private orderId = 1;
    address public allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address relaying fulfilled orders
    address public allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;

    // Ethereum
    address public PAYMENT_REGISTRY_ADDRESS = 0x6B911a94ee908BF9503143863A52Ea6c1f38b50A;
    address public FACTS_REGISTRY_ADDRESS = 0xFE8911D762819803a9dC6Eb2dcE9c831EF7647Cd;
    bytes32 public ETHEREUM_MAINNET_NETWORK_ID = bytes32(uint256(0x1));
    bytes32 public ETHEREUM_SEPOLIA_NETWORK_ID = bytes32(uint256(0xAA36A7));

    // Starknet
    address public HDP_EXECUTION_STORE_ADDRESS = 0x68a011d3790e7F9038C9B9A4Da7CD60889EECa70;
    uint256 public HDP_PROGRAM_HASH = 0x62c37715e000abfc6f931ee05a4ff1be9d7832390b31e5de29d197814db8156;
    bytes32 public STARKNET_MAINNET_NETWORK_ID = bytes32(uint256(0x534e5f4d41494e));
    bytes32 public STARKNET_SEPOLIA_NETWORK_ID = bytes32(uint256(0x534e5f5345504f4c4941));

    // Interfaces
    IFactsRegistry factsRegistry = IFactsRegistry(FACTS_REGISTRY_ADDRESS);
    IHdpExecutionStore hdpExecutionStore = IHdpExecutionStore(HDP_EXECUTION_STORE_ADDRESS);

    // Storage
    mapping(uint256 => bytes32) public orders;
    mapping(uint256 => OrderState) public orderStatus;

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
    event ProveBridgeSuccess(uint256 orderId);
    event ProveBridgeAggregatedSuccess(uint256[] orderIds);
    event WithdrawSuccess(uint256 orderId);
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

    // Constructor
    constructor() {
        owner = msg.sender;
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
        uint256 _expirationTimestamp = currentTimestamp + 1 days;
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

    /**
     * @dev Proves the fulfillment of an order by verifying order data stored on the Payment Registry contract at a specific block.
     *
     * This function calculates the storage slot associated with the order fulfillment in the Payment Registry, retrieves the bool value
     * from the slot in a bytes32 type, converts it back to a bool, and checks if it's true to signify order fulfillment.
     */
    function proveEvmOrderFulfillment(
        uint256 _orderId,
        uint256 _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _bridgeAmount,
        uint256 _fee,
        address _usrSrcAddress,
        bytes32 _dstChainId,
        uint256 _blockNumber
    ) public onlyRelayAddress whenNotPaused {
        // validate the call data
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                _orderId, _usrDstAddress, _expirationTimestamp, _bridgeAmount, _fee, _usrSrcAddress, _dstChainId
            )
        );
        require(orders[_orderId] == orderHash, "Order hash mismatch");
        require(
            orderStatus[_orderId] == OrderState.PENDING,
            "The order can only be in the PENDING status; any other status is invalid."
        );
        uint256 currentTimestamp = block.timestamp;
        require(_expirationTimestamp > currentTimestamp, "Cannot prove an order that has expired.");

        uint256 transfersMappingSlot = 2; // Retrieved from PaymentRegistry storage layout
        bytes32 _isFulfilledSlot = keccak256(abi.encodePacked(orderHash, transfersMappingSlot));
        bytes32 _isFulfilledValue =
            factsRegistry.accountStorageSlotValues(PAYMENT_REGISTRY_ADDRESS, _blockNumber, _isFulfilledSlot);
        bool orderIsFulfilled = _isFulfilledValue != bytes32(0); //convert to bool

        if (orderIsFulfilled) {
            orderStatus[_orderId] = OrderState.PROVED;

            emit ProveBridgeSuccess(_orderId);
        }
    }

    /**
     * @dev In a batch format, calculates the slots which will be proven for the given orderIds, at the given blockNumber.
     */
    function proveOrderFulfillmentBatch(Order[] memory calldataOrders, uint256 _blockNumber) public onlyRelayAddress {
        // batch call proveOrderFulfillment
        for (uint256 i = 0; i < calldataOrders.length; i++) {
            Order memory order = calldataOrders[i];
            proveEvmOrderFulfillment(
                order.id,
                order.usrDstAddress,
                order.expirationTimestamp,
                order.bridgeAmount,
                order.fee,
                order.usrSrcAddress,
                order.dstChainId,
                _blockNumber
            );
        }
    }

    function proveOrderFulfillmentBatchAggregated_HDP(Order[] memory calldataOrders, uint256 _blockNumber)
        public
        onlyRelayAddress
    {
        // For proving in aggregated mode using HDP - now for Starknet
        bytes32[] memory taskInputs;
        taskInputs[0] = bytes32(_blockNumber); // The point in time at which to prove the orders

        for (uint256 i = 1; i < calldataOrders.length; i++) {
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
            taskInputs[i] = orderHash;
        }

        ModuleTask memory hdpModuleTask = ModuleTask({programHash: bytes32(HDP_PROGRAM_HASH), inputs: taskInputs});
        bytes32 taskCommitment = hdpModuleTask.commit(); // Calculate task commitment hash based on program hash and program inputs
        require(
            hdpExecutionStore.cachedTasksResult(taskCommitment).status == IHdpExecutionStore.TaskStatus.FINALIZED,
            "HDP Task is not finalized"
        );
        require(
            hdpExecutionStore.getFinalizedTaskResult(taskCommitment) != 0,
            "Unable to prove PaymentRegistry transfer execution"
        );

        uint256[] memory provedOrderIds;
        for (uint256 i = 0; i < calldataOrders.length; i++) {
            orderStatus[calldataOrders[i].id] = OrderState.PROVED;
            provedOrderIds[i] = calldataOrders[i].id;
        }
        emit ProveBridgeAggregatedSuccess(provedOrderIds);
    }

    /**
     * @dev Allows the market maker to unlock the funds for a transaction fulfilled by them.
     */
    function withdrawProved(
        uint256 _orderId,
        uint256 _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _bridgeAmount,
        uint256 _fee,
        address _usrSrcAddress,
        bytes32 _dstChainId
    ) external nonReentrant whenNotPaused onlyRelayAddress {
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                orderId, _usrDstAddress, _expirationTimestamp, _bridgeAmount, _fee, _usrSrcAddress, _dstChainId
            )
        );
        require(orders[_orderId] == orderHash, "Order hash mismatch");
        require(orderStatus[_orderId] == OrderState.PROVED);
        uint256 transferAmountAndFee = _bridgeAmount + _fee;
        require(address(this).balance >= transferAmountAndFee, "Withdraw Proved: Insufficient balance to withdraw");

        orderStatus[_orderId] = OrderState.COMPLETED;

        (bool success,) = payable(allowedWithdrawalAddress).call{value: transferAmountAndFee}("");
        require(success, "Withdraw Proved: Transfer failed");
        emit WithdrawSuccess(_orderId);
    }

    /**
     * @dev Allows the market maker to batch unlock the funds for transactions fulfilled by them.
     */
    function withdrawProvedBatch(
        uint256[] memory _orderIds,
        uint256[] memory _usrDstAddresses,
        uint256[] memory _expirationTimestamps,
        uint256[] memory _bridgeAmounts,
        uint256[] memory _fees,
        address[] memory _usrSrcAddresses,
        bytes32[] memory _dstChainIds
    ) external nonReentrant whenNotPaused onlyRelayAddress {
        uint256 amountToWithdraw = 0;
        for (uint256 i = 0; i < _orderIds.length; i++) {
            bytes32 orderHash = keccak256(
                abi.encodePacked(
                    _orderIds[i],
                    _usrDstAddresses[i],
                    _expirationTimestamps[i],
                    _bridgeAmounts[i],
                    _fees[i],
                    _usrSrcAddresses[i],
                    _dstChainIds[i]
                )
            );
            require(orders[_orderIds[i]] == orderHash);
            require(orderStatus[_orderIds[i]] == OrderState.PROVED);

            amountToWithdraw += _bridgeAmounts[i] + _fees[i];
            orderStatus[_orderIds[i]] = OrderState.COMPLETED;
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

    function setHDPAddress(address _newHDPExecutionStore, uint256 _newHDPProgramHash) external onlyOwner {
        HDP_EXECUTION_STORE_ADDRESS = _newHDPExecutionStore;
        HDP_PROGRAM_HASH = _newHDPProgramHash;
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
