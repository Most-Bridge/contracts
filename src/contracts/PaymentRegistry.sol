// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract PaymentRegistry {
    // MVP of a unilateral bridge from sepolia to sepolia

    struct TransferInfo {
        uint256 orderId;
        address usrDstAddress;
        address mmSrcAddress;
        uint256 amount;
        bool isUsed;
    }

    event Transfer(TransferInfo transferInfo);

    mapping(bytes32 => TransferInfo) public transfers;

    // called by the MM to transfer funds to the user on the destination chain
    function transferTo(uint256 _orderId, address _usrDstAddress, address _mmSrcAddress) external payable {
        require(msg.value > 0, "Funds being sent must exceed 0.");

        // TODO: just use the order id as the key for this mapping
        bytes32 index = keccak256(abi.encodePacked(_orderId, _usrDstAddress, msg.value));

        require(transfers[index].isUsed == false, "Transfer already processed.");

        transfers[index] = TransferInfo({
            orderId: _orderId,
            usrDstAddress: _usrDstAddress,
            mmSrcAddress: _mmSrcAddress,
            amount: msg.value,
            isUsed: true
        });

        (bool success,) = payable(_usrDstAddress).call{value: msg.value}(""); // transfer to user

        require(success, "Transfer failed.");
        // to be picked up by listener and turned into a proof
        emit Transfer(transfers[index]);
    }

    // getters
    function getTransfers(bytes32 _index) public view returns (TransferInfo memory) {
        return transfers[_index];
    }
}
