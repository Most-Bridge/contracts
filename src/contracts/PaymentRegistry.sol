// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  Payment Registry
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Handles the throughput of transactions from the Market Maker to a user, and saves the data
///         to be used to prove the transaction.
contract PaymentRegistry is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// Storage
    /// @notice Mapping to track if an order has been fulfilled.
    ///         The key is the order hash, and the value is the address of the market maker (in bytes32) that fulfilled it.
    mapping(bytes32 => bytes32) public fulfillments;

    /// State variables
    address public immutable owner;

    /// Constructor
    constructor() {
        owner = msg.sender;
    }

    /// Events
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
        bytes32 marketMakerSourceAddress
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
        uint256 dstAmount;
        bytes32 srcChainId;
        bytes32 marketMakerSourceAddress;
    }

    /// @notice Batch version - Called by the market maker to transfer funds (native ETH or ERC20) to the user on the destination chain.
    ///         The fulfillment record is what is used to prove the transaction occurred.
    ///
    /// @param orders An array of OrderFulfillmentData structs containing the details of each order to be fulfilled.
    function mostFulfillOrders(OrderFulfillmentData[] memory orders) external payable whenNotPaused nonReentrant {
        for (uint256 i = 0; i < orders.length; i++) {
            uint256 currentTimestamp = block.timestamp;
            require(orders[i].expirationTimestamp > currentTimestamp, "Cannot fulfill an expired order.");
            require(orders[i].marketMakerSourceAddress != bytes32(0), "Invalid MM address: zero address");

            bytes32 orderHash = _createFulfillmentOrderHash(orders[i]);

            require(fulfillments[orderHash] == bytes32(0), "Transfer already processed");
            fulfillments[orderHash] = orders[i].marketMakerSourceAddress;

            if (orders[i].dstToken == address(0)) {
                // Native ETH transfer
                require(orders[i].dstAmount > 0, "Native ETH: Amount must be > 0");
                (bool success,) = payable(orders[i].usrDstAddress).call{value: orders[i].dstAmount}("");
                require(success, "Native ETH: Transfer failed");
            } else {
                // ERC20 token transfer
                require(orders[i].dstAmount > 0, "ERC20: Amount must be > 0");
                IERC20(orders[i].dstToken).safeTransferFrom(msg.sender, orders[i].usrDstAddress, orders[i].dstAmount);
            }

            emit FulfillmentReceipt(
                orders[i].orderId,
                orders[i].srcEscrow,
                orders[i].usrSrcAddress,
                orders[i].usrDstAddress,
                orders[i].expirationTimestamp,
                orders[i].srcToken,
                orders[i].srcAmount,
                orders[i].dstToken,
                orders[i].dstAmount,
                orders[i].srcChainId,
                block.chainid,
                orders[i].marketMakerSourceAddress
            );
        }
    }

    /// @notice Creates a hash of the fulfillment order details (used as the key in fulfillments mapping)
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
                order.dstAmount,
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
