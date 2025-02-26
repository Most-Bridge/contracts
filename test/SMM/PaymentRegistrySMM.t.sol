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
    uint256 expirationTimestamp = block.timestamp + 1 days;
    uint256 fee = 0.01 ether;
    bytes32 destinationChainId = bytes32(uint256(1)); // TODO: change to dstChainId

    uint256 sendAmount = 1 ether;

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(mmDstAddress, 10 ether);
        vm.deal(destinationAddress, 1 ether);
        vm.prank(address(this));
        paymentRegistry.setAllowedMMAddress(mmDstAddress);
    }

    function testFulfillOrder() public {
        vm.prank(mmDstAddress); // mm calls
        paymentRegistry.fulfillOrder{value: sendAmount}(
            orderId, destinationAddress, expirationTimestamp, fee, mmSrcAddress, destinationChainId
        );

        bytes32 orderHash = keccak256(
            abi.encodePacked(
                orderId, destinationAddress, expirationTimestamp, sendAmount, fee, mmSrcAddress, destinationChainId
            )
        );

        assertTrue(paymentRegistry.getFulfillment(orderHash), "Order was not marked as processed.");
        assertEq(address(destinationAddress).balance, 2 ether, "Destination address balance did not increase.");
        assertEq(address(mmDstAddress).balance, 9 ether, "Market maker balance did not decrease.");
    }

    function testFulfillOrderFailsIfAlreadyProcessed() public {
        vm.startPrank(mmDstAddress);
        paymentRegistry.fulfillOrder{value: 1 ether}(
            orderId, destinationAddress, expirationTimestamp, fee, mmSrcAddress, destinationChainId
        );

        vm.expectRevert("Transfer already processed.");
        paymentRegistry.fulfillOrder{value: 1 ether}(
            orderId, destinationAddress, expirationTimestamp, fee, mmSrcAddress, destinationChainId
        );
        vm.stopPrank();
    }

    function testFulfillOrderFailsIfNoValue() public {
        vm.prank(mmDstAddress);
        vm.expectRevert("Funds being sent must exceed 0.");
        paymentRegistry.fulfillOrder{value: 0}(
            orderId, destinationAddress, expirationTimestamp, fee, mmSrcAddress, destinationChainId
        );
    }

    function testFulfillOrderFailsOnExpiredOrder() public {
        vm.prank(mmDstAddress);
        vm.expectRevert("Cannot fulfill an expired order.");
        // warping time to expire order
        vm.warp(block.timestamp + 2 days);
        paymentRegistry.fulfillOrder{value: 1 ether}(
            orderId, destinationAddress, expirationTimestamp, fee, mmSrcAddress, destinationChainId
        );
    }
}
