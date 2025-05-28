// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "../../src/contracts/SMM/PaymentRegistrySMM.sol";

contract PaymentRegistryTest is Test {
    PaymentRegistry public paymentRegistry;
    uint256 orderId = 1;
    bytes32 userSrcAddress = bytes32(uint256(1));
    address userDstAddress = address(1);
    uint256 expirationTimestamp = block.timestamp + 1 days;
    bytes32 srcToken = bytes32(uint256(11));
    uint256 srcAmount = 1 ether;
    address dstToken = address(2);
    uint256 dstAmount = 0.9 ether;
    uint256 fee = 0.1 ether;
    bytes32 srcChainId = bytes32(uint256(2));
    bytes32 constant DST_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000000001; // TODO

    address MMAddress = address(3);

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(MMAddress, 10 ether);
        vm.deal(userDstAddress, 1 ether);
        vm.prank(address(this));
        paymentRegistry.setAllowedMMAddress(MMAddress);
    }

    function testFulfillmentSuccess() public {
        vm.prank(MMAddress); // mm calls
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstToken,
            dstAmount,
            fee,
            srcChainId
        );

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                srcAmount,
                dstToken,
                dstAmount,
                fee,
                srcChainId,
                DST_CHAIN_ID
            )
        );

        assertTrue(paymentRegistry.fulfillments(orderHash), "Order was not marked as processed.");
        assertEq(address(userDstAddress).balance, 1.9 ether, "User destination address balance did not increase.");
        assertEq(address(MMAddress).balance, 9.1 ether, "MM balance did not decrease.");
    }

    // function testFulfillmentFailsIfAlreadyProcessed() public {
    //     vm.startPrank(MMAddress);
    //     paymentRegistry.mostFulfillment{value: 1 ether}(
    //         orderId, userDstAddress, expirationTimestamp, fee, MMAddress, dstChainId
    //     );

    //     vm.expectRevert("Transfer already processed.");
    //     paymentRegistry.mostFulfillment{value: 1 ether}(
    //         orderId, userDstAddress, expirationTimestamp, fee, MMAddress, dstChainId
    //     );
    //     vm.stopPrank();
    // }

    // function testFulfillmentFailsIfNoValue() public {
    //     vm.prank(MMAddress);
    //     vm.expectRevert("Funds being sent must exceed 0.");
    //     paymentRegistry.mostFulfillment{value: 0}(
    //         orderId, userDstAddress, expirationTimestamp, fee, MMAddress, dstChainId
    //     );
    // }

    // function testFulfillmentFailsOnExpiredOrder() public {
    //     vm.prank(MMAddress);
    //     vm.expectRevert("Cannot fulfill an expired order.");
    //     // warping time to expire order
    //     vm.warp(block.timestamp + 2 days);
    //     paymentRegistry.mostFulfillment{value: 1 ether}(
    //         orderId, userDstAddress, expirationTimestamp, fee, MMAddress, dstChainId
    //     );
    // }
}
