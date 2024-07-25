// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PaymentRegistry {
    // MVP of a unilateral bridge from sepolia to sepolia

    struct TransferInfo {
        uint256 orderId;
        address destAddress;
        uint256 amount;
        address mmSrcAddress;
        address mmDstAddress;
        bool isUsed;
    }

    event Transfer(uint256 indexed orderId, address srcAddress, TransferInfo transferInfo);

    mapping(bytes32 => TransferInfo) public transfers;

    // called by the MM to transfer funds to the user on the destination chain
    function transferTo(uint256 _orderId, address _destinationAddress, address _mmSrcAddress) external payable {
        require(msg.value > 0, "Funds being sent must exceed 0.");

        // TODO: just use the order id as the key for this mapping
        bytes32 index = keccak256(abi.encodePacked(_orderId, _destinationAddress, msg.value));

        require(transfers[index].isUsed == false, "Transfer already processed.");
        transfers[index] = TransferInfo({
            orderId: _orderId,
            destAddress: _destinationAddress,
            amount: msg.value,
            mmSrcAddress: _mmSrcAddress,
            mmDstAddress: msg.sender,
            isUsed: true
        });

        (bool success,) = payable(_destinationAddress).call{value: msg.value}(""); // transfer to user

        require(success, "Transfer failed.");
        emit Transfer(_orderId, msg.sender, transfers[index]); // this needs to be pickedup and turned into a proof now
    }

    // getters
    function getTransfers(bytes32 _index) public view returns (TransferInfo memory) {
        return transfers[_index];
    }
}
