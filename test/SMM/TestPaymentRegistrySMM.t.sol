// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "../../src/contracts/SMM/PaymentRegistrySMM.sol";

contract PaymentRegistryTest is Test {
    PaymentRegistry public paymentRegistry;
    address destinationAddress = address(1);
    address mmDstAddress = address(2);
    address mmSrcAddress = address(3);
    uint256 orderId = 1;
    uint256 expirationTimestamp = block.timestamp + 7 days;

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(mmDstAddress, 10 ether);
        vm.deal(destinationAddress, 1 ether);
        vm.prank(address(this));
        paymentRegistry.setAllowedAddress(mmDstAddress);
    }

    function testTransferTo() public {
        uint256 sendAmount = 1 ether;
        vm.prank(mmDstAddress);
        paymentRegistry.transferTo{value: sendAmount}(orderId, destinationAddress, expirationTimestamp);

        bytes32 index = keccak256(abi.encodePacked(orderId, destinationAddress, sendAmount));
        assertTrue(paymentRegistry.getTransfers(index).isUsed); // check that isUsed is true

        assertEq(address(destinationAddress).balance, 2 ether); // user balance up
        assertEq(address(mmDstAddress).balance, 9 ether); // mm balance down
    }

    function testTransferToFailsIfAlreadyProcessed() public {
        vm.startPrank(mmDstAddress);
        paymentRegistry.transferTo{value: 1 ether}(orderId, destinationAddress, expirationTimestamp);

        vm.expectRevert("Transfer already processed.");
        paymentRegistry.transferTo{value: 1 ether}(orderId, destinationAddress, expirationTimestamp);
        vm.stopPrank();
    }

    function testTransferToFailsIfNoValue() public {
        vm.prank(mmDstAddress);
        vm.expectRevert("Funds being sent must exceed 0.");
        paymentRegistry.transferTo{value: 0}(orderId, destinationAddress, expirationTimestamp);
    }

    function testTransferToFailsOnExpiredOrder() public {
        vm.prank(mmDstAddress);
        vm.expectRevert("Cannot fulifll an expired order.");
        // sending the current time, while it expects a greater time
        paymentRegistry.transferTo{value: 1 ether}(orderId, destinationAddress, block.timestamp);
    }
}
