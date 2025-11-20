// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  Payment Registry
/// @author Most Bridge (https://github.com/Most-Bridge)
/// @notice Handles the throughput of transactions from the Market Maker to a user, and saves the data
///         to be used to prove the transaction.

//     /$$      /$$  /$$$$$$   /$$$$$$  /$$$$$$$$
//    | $$$    /$$$ /$$__  $$ /$$__  $$|__  $$__/
//    | $$$$  /$$$$| $$  \ $$| $$  \__/   | $$
//    | $$ $$/$$ $$| $$  | $$|  $$$$$$    | $$
//    | $$  $$$| $$| $$  | $$ \____  $$   | $$
//    | $$\  $ | $$| $$  | $$ /$$  \ $$   | $$
//    | $$ \/  | $$|  $$$$$$/|  $$$$$$/   | $$
//    |__/     |__/ \______/  \______/    |__/
contract PaymentRegistry is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Mapping to track if an order has been fully fulfilled.
    ///         The key is the order hash, and the value is the address of the market maker (in bytes32) that fulfilled it.
    mapping(bytes32 => bytes32) public fulfillments; // orderHash => marketMakerSourceAddress

    /// @notice Mapping to track cumulative partial fulfillment for an order.
    ///         The key is the order hash, and the value is the total amount fulfilled so far on dstChain.
    mapping(bytes32 => uint256) public partialFillBalance; // orderHash => total fulfilled amount

    ///  mapping to bind an order to a single MM after first fill
    mapping(bytes32 => address) public lockPartialFillTo; // orderHash => address that first filled the order, and only they can keep filling the order

    /// State variables
    address public immutable owner;

    /// Constructor
    constructor() {
        owner = msg.sender;
    }

    /// Events
    /// @dev `dstAmount` here is the amount sent in *this* transaction (not the total order dstAmount).
    event FulfillmentReceipt(
        uint256 indexed orderId,
        bytes32 srcEscrow,
        bytes32 indexed usrSrcAddress,
        address indexed usrDstAddress,
        uint256 expirationTimestamp,
        bytes32 srcToken,
        uint256 srcAmount,
        address dstToken,
        uint256 dstAmount,
        bytes32 srcChainId,
        uint256 dstChainId,
        bytes32 marketMakerSourceAddress,
        bool isFullyFulfilled
    );

    /// Structs
    struct OrderFulfillmentData {
        uint256 orderId;
        bytes32 srcEscrow;
        bytes32 usrSrcAddress;
        address usrDstAddress;
        uint256 expirationTimestamp;
        bytes32 srcToken;
        uint256 srcAmount;
        address dstToken;
        uint256 dstAmount; // total amount that should eventually be received on dst chain
        bytes32 srcChainId;
        bytes32 marketMakerSourceAddress;
        uint256 fulfillmentAmount; // amount being fulfilled in THIS tx (<= dstAmount)
    }

    /// @notice Called by the market maker to transfer funds (native ETH or ERC20) to the user on the destination chain.
    ///         Can be used to fulfill single orders or batches of orders (partial or full).
    ///
    /// @param orders An array of OrderFulfillmentData structs containing the details of each order to be fulfilled.
    function mostFulfillOrders(OrderFulfillmentData[] memory orders) external payable whenNotPaused nonReentrant {
        for (uint256 i = 0; i < orders.length; i++) {
            _fulfillOrder(orders[i]);
        }
    }

    function _fulfillOrder(OrderFulfillmentData memory order) internal {
        uint256 currentTimestamp = block.timestamp;
        require(order.expirationTimestamp > currentTimestamp, "Cannot fulfill an expired order.");
        require(order.marketMakerSourceAddress != bytes32(0), "Invalid MM address: zero address");

        bytes32 orderHash = _createFulfillmentOrderHash(order);

        // Block any fills after we consider the order fully done
        require(fulfillments[orderHash] == bytes32(0), "Order already fully fulfilled");

        uint256 amount = order.fulfillmentAmount;
        require(amount > 0, "Fulfillment: amount must be > 0");
        require(amount <= order.dstAmount, "Fulfillment: amount > total order");

        uint256 alreadyFilled = partialFillBalance[orderHash]; // 0 if first fill
        uint256 newFilled = alreadyFilled + amount;
        require(newFilled <= order.dstAmount, "Fulfillment: overfill");

        // Bind order to a single MM on first fill
        if (alreadyFilled == 0) {
            // First fill (could be full or partial) claims the order
            lockPartialFillTo[orderHash] = msg.sender;
        } else {
            // Subsequent fills must come from the same MM
            require(lockPartialFillTo[orderHash] == msg.sender, "Fulfillment: different MM");
        }

        // Do the transfer for THIS tx's amount
        if (order.dstToken == address(0)) {
            (bool success,) = payable(order.usrDstAddress).call{value: amount}("");
            require(success, "Native ETH: Transfer failed");
        } else {
            IERC20(order.dstToken).safeTransferFrom(msg.sender, order.usrDstAddress, amount);
        }

        // Update state
        // Accounts for first fill == full fill
        bool isFullyFilled = newFilled == order.dstAmount;
        if (isFullyFilled) {
            // This call completes the order
            fulfillments[orderHash] = order.marketMakerSourceAddress;

            if (alreadyFilled != 0) {
                delete partialFillBalance[orderHash];
            }
            delete lockPartialFillTo[orderHash];
        } else {
            // Still partial
            partialFillBalance[orderHash] = newFilled;
        }

        // Emit receipt for THIS tx's amount
        emit FulfillmentReceipt(
            order.orderId,
            order.srcEscrow,
            order.usrSrcAddress,
            order.usrDstAddress,
            order.expirationTimestamp,
            order.srcToken,
            order.srcAmount,
            order.dstToken,
            amount, // amount fulfilled in this tx
            order.srcChainId,
            block.chainid,
            order.marketMakerSourceAddress,
            isFullyFilled
        );
    }

    /// @notice Creates a hash of the fulfillment order details (used as the key in fulfillments / partialFillBalance)
    ///
    /// @param order The details of the order to be hashed
    /// @return bytes32 The hash of the order details
    function _createFulfillmentOrderHash(OrderFulfillmentData memory order) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                order.orderId,
                order.srcEscrow,
                order.usrSrcAddress,
                order.usrDstAddress,
                order.expirationTimestamp,
                order.srcToken,
                order.srcAmount,
                order.dstToken,
                order.dstAmount, // total destination amount
                order.srcChainId,
                block.chainid
            )
        );
    }

    /// Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /// onlyOwner functions
    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }
}
