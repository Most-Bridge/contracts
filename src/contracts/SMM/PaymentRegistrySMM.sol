// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Payment Registry
 * @dev Handles the throughput of transactions from the Market Maker to a user, and saves the data
 * to be used to prove the transaction.
 */
contract PaymentRegistry is Pausable {
    // State variables
    address public owner;
    address public allowedMarketMakerAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;

    // Storage
    mapping(bytes32 => bool) public transfers;

    // Structs
    // struct TransferInfo {
    //     uint256 orderId;
    // }

    // Events
    event Transfer(
        uint256 _orderId,
        address _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _fee,
        address _usrSrcAddress,
        bytes32 _destinationChainId
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyAllowedAddress() {
        require(msg.sender == allowedMarketMakerAddress, "Caller is not allowed");
        _;
    }

    // Constructor
    constructor() {
        owner = msg.sender;
    }

    // External functions
    /**
     * @dev Allows the owner to change the allowed market maker address, who will be fulfilling the orders.
     * @param _newAllowedAddress The address that will fulfill the orders.
     */
    function setAllowedAddress(address _newAllowedAddress) public onlyOwner {
        allowedMarketMakerAddress = _newAllowedAddress;
    }

    /**
     * @dev Called by the allowed market maker to transfer funds to the user on the destination chain.
     * The `transfer` mapping which is updated in this function, is what is used to prove the tx occurred.
     * @param _orderId The order ID associated with the order being fulfilled.
     * @param _usrDstAddress The user's destination address to receive the funds.
     * @param _expirationTimestamp The order’s expiration time. If an expired timestamp is mistakenly passed,
     * the funds in Escrow remain locked.
     */
    function transferTo(
        uint256 _orderId,
        address _usrDstAddress,
        uint256 _expirationTimestamp,
        uint256 _fee,
        address _usrSrcAddress,
        bytes32 _destinationChainId
    ) external payable onlyAllowedAddress whenNotPaused {
        require(msg.value > 0, "Funds being sent must exceed 0.");
        // require that the order is not expired.
        uint256 currentTimestamp = block.timestamp;
        require(_expirationTimestamp > currentTimestamp, "Cannot fulfill an expired order.");

        bytes32 orderHash = keccak256(
            abi.encodePacked(
                _orderId, _usrDstAddress, _expirationTimestamp, msg.value, _fee, _usrSrcAddress, _destinationChainId
            )
        );

        require(transfers[orderHash] == false, "Transfer already processed.");

        transfers[orderHash] = true;

        (bool success,) = payable(_usrDstAddress).call{value: msg.value}(""); // transfer to user
        require(success, "Transfer failed.");

        emit Transfer(_orderId, _usrDstAddress, _expirationTimestamp, _fee, _usrSrcAddress, _destinationChainId);
    }

    // public functions

    /**
     * @dev Returns the transfer information for a given index.
     * @param _orderHash The index to look up transfer info.
     * @return TransferInfo The transfer information associated with the index.
     */
    function getTransfers(bytes32 _orderHash) public view returns (bool) {
        return transfers[_orderHash];
    }

    // onlyAllowedAddress functions
    function pauseContract() external onlyAllowedAddress {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpauseContract() external onlyAllowedAddress {
        _unpause();
    }
}
