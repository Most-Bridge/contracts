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
    mapping(bytes32 => bool) public fulfillments;

    /// State variables
    address public owner;
    address public allowedMMAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    bytes32 constant DST_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000000001; // TODO

    /// Events
    event FulfillmentReceipt(
        uint256 orderId,
        bytes32 usrSrcAddress,
        address usrDstAddress,
        uint256 expirationTimestamp,
        bytes32 srcToken,
        uint256 srcAmount,
        address dstToken,
        uint256 dstAmount,
        uint256 fee,
        bytes32 srcChainId,
        bytes32 dstChainId
    );

    /// Constructor
    constructor() {
        owner = msg.sender;
    }

    /// External functions
    /// @notice Called by the allowed market maker to transfer funds (native ETH or ERC20) to the user on the destination chain.
    ///         The fulfillment record is what is used to prove the transaction occurred.
    ///
    /// @param _orderId             The order ID associated with the order being fulfilled.
    /// @param _usrSrcAddress       The address of the user on the source chain (format: bytes32).
    /// @param _usrDstAddress       The user's destination address (native EVM address) to receive the funds.
    /// @param _expirationTimestamp The order's expiration time. Must be in the future.
    /// @param _srcToken            The token address (identifier) on the source chain (format: bytes32).
    /// @param _srcAmount           The amount of tokens sent from the source chain.
    /// @param _dstToken            The token address on the destination (this) chain. For native ETH, use address(0).
    /// @param _dstAmount           The amount of tokens (native ETH or ERC20) to be received by the user on this chain.
    /// @param _fee                 The fee paid to the Market Maker for this fulfillment.
    /// @param _srcChainId          The chain ID of the source chain (format: bytes32).
    function mostFulfillment(
        uint256 _orderId,
        bytes32 _usrSrcAddress,
        address _usrDstAddress,
        uint256 _expirationTimestamp,
        bytes32 _srcToken,
        uint256 _srcAmount,
        address _dstToken,
        uint256 _dstAmount,
        uint256 _fee,
        bytes32 _srcChainId
    ) external payable onlyAllowedAddress whenNotPaused nonReentrant {
        uint256 currentTimestamp = block.timestamp;
        require(_expirationTimestamp > currentTimestamp, "Cannot fulfill an expired order.");

        bytes32 orderHash = keccak256(
            abi.encode(
                _orderId,
                _usrSrcAddress,
                _usrDstAddress,
                _expirationTimestamp,
                _srcToken,
                _srcAmount,
                _dstToken,
                _dstAmount,
                _fee,
                _srcChainId,
                DST_CHAIN_ID
            )
        );

        require(!fulfillments[orderHash], "Transfer already processed");
        fulfillments[orderHash] = true;

        if (_dstToken == address(0)) {
            // Native ETH transfer
            require(msg.value == _dstAmount, "Native ETH: msg.value mismatch with destination amount");
            require(_dstAmount > 0, "Native ETH: Amount must be > 0");
            (bool success,) = payable(_usrDstAddress).call{value: _dstAmount}("");
            require(success, "Native ETH: Transfer failed");
        } else {
            // ERC20 token transfer
            require(msg.value == 0, "ERC20: msg.value must be 0");
            require(_dstAmount > 0, "ERC20: Amount must be > 0");

            IERC20(_dstToken).safeTransferFrom(msg.sender, _usrDstAddress, _dstAmount);
        }

        emit FulfillmentReceipt(
            _orderId,
            _usrSrcAddress,
            _usrDstAddress,
            _expirationTimestamp,
            _srcToken,
            _srcAmount,
            _dstToken,
            _dstAmount,
            _fee,
            _srcChainId,
            DST_CHAIN_ID
        );
    }

    /// Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyAllowedAddress() {
        require(msg.sender == allowedMMAddress, "Caller is not allowed");
        _;
    }

    /// Public functions
    /// @notice Allows the owner to change the allowed market maker address, who will be fulfilling the orders
    /// @param _newAllowedMMAddress The new address that will fulfill the orders
    function setAllowedMMAddress(address _newAllowedMMAddress) public onlyOwner {
        allowedMMAddress = _newAllowedMMAddress;
    }

    /// onlyAllowedAddress functions
    function pauseContract() external onlyAllowedAddress {
        _pause();
    }

    function unpauseContract() external onlyAllowedAddress {
        _unpause();
    }
}
