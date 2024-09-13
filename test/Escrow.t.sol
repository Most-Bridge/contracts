// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/contracts/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;
    address user = address(1);
    address destinationAddress = address(2);
    address mmAddress = address(3);
    address maliciousActor = address(4);

    uint256 sendAmount;
    uint256 feeAmount;

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether);
        sendAmount = 1 ether;
        feeAmount = 0.1 ether;
        escrow.setAllowedAddress(address(this));
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount);

        (uint256 orderId, address usrDstAddress, uint256 amount, uint256 fee, uint256 expiryTimestamp) =
            escrow.orders(1);

        assertEq(orderId, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assert(expiryTimestamp > block.timestamp);

        vm.stopPrank();
    }

    function testCreateOrderWithNoValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder(destinationAddress, feeAmount); // calling with no value
        vm.stopPrank();
    }

    function testCreateOrderWithZeroValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder{value: 0}(destinationAddress, feeAmount); // calling with no value
        vm.stopPrank();
    }

    function testCreateOrderWithFeeBiggerThanValueSent() public {
        vm.startPrank(user);
        vm.expectRevert("Fee must be less than the total value sent");
        escrow.createOrder{value: sendAmount}(destinationAddress, 5 ether);
        vm.stopPrank();
    }

    function testPauseContract() public {
        vm.startPrank(address(this)); // this contract is the owner
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Expect revert due to paused contract
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount);
        vm.stopPrank();
    }

    function testPauseAndUnpauseContract() public {
        vm.prank(address(this)); // this contract is the owner
        escrow.pauseContract();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Expect revert due to paused contract
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount);
        vm.stopPrank();

        vm.prank(address(this)); // this contract is the owner
        escrow.unpauseContract();

        vm.prank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount);

        // Assertions to check the order details
        (uint256 id, address usrDstAddress, uint256 amount, uint256 fee, uint256 expiryTimestamp) = escrow.orders(1);

        assertEq(id, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assert(expiryTimestamp > block.timestamp);
    }

    // TODO: test expiry timestamp

    function testExpiryTimestamp() public {
        vm.startPrank(user);
        uint256 currentTimestamp = block.timestamp;
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount);

        (uint256 orderId, address usrDstAddress, uint256 amount, uint256 fee, uint256 expiryTimestamp) =
            escrow.orders(1);

        assertEq(orderId, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assert(expiryTimestamp > block.timestamp);
        assert(expiryTimestamp == currentTimestamp + 7 days);

        vm.stopPrank();
    }
}
