// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

contract PaymentRegistry {
    // MVP of a unilateral bridge from sepolia to sepolia

    event Transfer(uint256 indexed orderId, address srcAddress, address destAddress, uint256 amount);

    mapping(bytes32 => bool) public transfers;

    function transferTo(uint256 _orderId, address _destinationAddress) external payable {
        require(msg.value > 0, "Funds being sent must exceed 0.");

        bytes32 index = keccak256(abi.encodePacked(_orderId, _destinationAddress, msg.value));

        require(transfers[index] == false, "Transfer already processed.");
        transfers[index] = true; // transfer now in progress

        (bool success,) = payable(_destinationAddress).call{value: msg.value}("");

        require(success, "Transfer failed.");
        emit Transfer(_orderId, msg.sender, _destinationAddress, msg.value); // this needs to be pickedup and turned into a proof now
    }
}
