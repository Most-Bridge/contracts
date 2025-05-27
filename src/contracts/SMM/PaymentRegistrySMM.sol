// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title  Payment Registry
///
/// @author Most Bridge (https://github.com/Most-Bridge)
///
/// @notice Handles the throughput of transactions from the Market Maker to a user, and saves the data
///         to be used to prove the transaction.
contract PaymentRegistry is Pausable {
    /// Storage
    mapping(bytes32 => bool) public fulfillments;

    /// State variables
    address public owner;
    address public allowedMMAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    bytes32 constant DST_CHAIN_ID = "THE (EVM) CHAIN ID WHERE THIS CONTRACT IS DEPLOYED"; // TODO

    /// Events
    event FulfillmentReceipt(
        uint256 _orderId,
        address _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _bridgeAmount,
        uint256 _fee,
        address _usrSrcAddress,
        bytes32 _destinationChainId
    );

    /// Constructor
    constructor() {
        owner = msg.sender;
    }

    /// External functions
    /// @notice Called by the allowed market maker to transfer funds to the user on the destination chain
    ///         The `transfer` mapping which is updated in this function, is what is used to prove the tx occurred
    ///
    /// @param _orderId             The order ID associated with the order being fulfilled
    /// @param _usrDstAddress       The user's destination address to receive the funds
    /// @param _expirationTimestamp The order’s expiration time. If an expired timestamp is mistakenly passed,
    ///                             the funds in Escrow remain locked
    /// @param _fee                 The fee paid to the MM
    /// @param _usrSrcAddress       The address of the user on the source chain
    /// @param _destinationChainId  The destination chain id in hex

    /// @notice srcToken and usrSrcAddress come from a foreign chain (e.g., Starknet), so passed as `bytes32`
    /// @notice dstToken and usrDstAddress are native to this chain (EVM), so stored as `address`
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
    ) external payable onlyAllowedAddress whenNotPaused {
        require(msg.value > 0, "Funds being sent must exceed 0.");
        uint256 currentTimestamp = block.timestamp;
        require(_expirationTimestamp > currentTimestamp, "Cannot fulfill an expired order.");

        bytes32 orderHash = keccak256(
            abi.encode(
                _orderId,
                _usrSrcAddress,
                bytes32(uint256(uint160(_usrDstAddress))),
                _expirationTimestamp,
                _srcToken,
                _srcAmount,
                bytes32(uint256(uint160(_dstToken))),
                msg.value,
                _fee,
                _srcChainId,
                DST_CHAIN_ID
            )
        );

        require(fulfillments[orderHash] == false, "Transfer already processed.");

        fulfillments[orderHash] = true;

        (bool success,) = payable(_usrDstAddress).call{value: msg.value}(""); // transfer to user
        require(success, "Transfer failed.");

        emit FulfillmentReceipt(
            //     _orderId, _usrDstAddress, _expirationTimestamp, msg.value, _fee, _usrSrcAddress, DST_CHAIN_ID
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

    function getFulfillment(bytes32 _orderHash) public view returns (bool) {
        return fulfillments[_orderHash];
    }

    /// onlyAllowedAddress functions
    function pauseContract() external onlyAllowedAddress {
        _pause();
    }

    function unpauseContract() external onlyAllowedAddress {
        _unpause();
    }
}
