// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Payment Registry
 * @dev Handles the throughput of transactions from the Market Maker to a user, and saves the data
 * to be used to prove the transaction.
 */
contract PaymentRegistry is Pausable {
    // State varaibles
    address public owner;
    address public allowedMarketMakerAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6; // address which will be fulfilling orders

    // Storage
    mapping(bytes32 => TransferInfo) public transfers;

    // Structs
    struct TransferInfo {
        uint256 orderId;
        address usrDstAddress;
        // address mmSrcAddress;
        uint256 amount;
        uint256 expiryTimestamp;
        bool isUsed;
    }

    // Events
    event Transfer(TransferInfo transferInfo);

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
     * The `transfer` mapping which is updated in this function, is what is used to prove the tx occured.
     * @param _orderId The order ID associated with the order being fulfilled.
     * @param _usrDstAddress The user's destination address to receive the funds.
     * @param _mmSrcAddress The market maker's source chain address, with which they will be able to claim
     * the funds on the source chain.
     */
    // TODO: add expiry timestamp

    function transferTo(uint256 _orderId, address _usrDstAddress, uint256 _expiryTimestamp)
        external
        payable
        onlyAllowedAddress
        whenNotPaused
    {
        require(msg.value > 0, "Funds being sent must exceed 0.");
        // require that the order is not expired.
        uint256 currentTimestamp = block.timestamp;
        require(_expiryTimestamp > currentTimestamp, "Cannot fulifll an expired order.");

        bytes32 index = keccak256(abi.encodePacked(_orderId, _usrDstAddress, msg.value));

        require(transfers[index].isUsed == false, "Transfer already processed.");

        transfers[index] = TransferInfo({
            orderId: _orderId,
            usrDstAddress: _usrDstAddress,
            amount: msg.value,
            expiryTimestamp: _expiryTimestamp,
            isUsed: true
        });

        (bool success,) = payable(_usrDstAddress).call{value: msg.value}(""); // transfer to user
        require(success, "Transfer failed.");

        emit Transfer(transfers[index]);
    }

    // public functions

    /**
     * @dev Returns the transfer information for a given index.
     * @param _index The index to look up transfer info.
     * @return TransferInfo The transfer information associated with the index.
     */
    function getTransfers(bytes32 _index) public view returns (TransferInfo memory) {
        return transfers[_index];
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
