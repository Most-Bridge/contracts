// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "../src/PaymentRegistry.sol";

contract PaymentRegistryTest is Test {
    PaymentRegistry public paymentRegistry;
    address destinationAddress = address(1);
    address mmAddress = address(2);
    uint256 orderId = 1;

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(mmAddress, 10 ether);
        vm.deal(destinationAddress, 1 ether);
    }

    function testTransferTo() public {
        uint256 sendAmount = 1 ether;
        vm.prank(mmAddress);
        paymentRegistry.transferTo{value: sendAmount}(orderId, destinationAddress);

        bytes32 index = keccak256(abi.encodePacked(orderId, destinationAddress, sendAmount));
        assertTrue(paymentRegistry.getTransfers(index).isUsed); // check that isUsed is true

        assertEq(address(destinationAddress).balance, 2 ether); // user balance up
        assertEq(address(mmAddress).balance, 9 ether); // mm balance down
    }

    function testTransferToFailsIfAlreadyProcessed() public {
        vm.startPrank(mmAddress);
        paymentRegistry.transferTo{value: 1 ether}(orderId, destinationAddress);

        vm.expectRevert("Transfer already processed.");
        paymentRegistry.transferTo{value: 1 ether}(orderId, destinationAddress);
        vm.stopPrank();
    }

    function testTransferToFailsIfNoValue() public {
        vm.prank(mmAddress);
        vm.expectRevert("Funds being sent must exceed 0.");
        paymentRegistry.transferTo{value: 0}(orderId, destinationAddress);
    }
}
