// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {EscrowWhitelist} from "../../src/contracts/whitelist/EscrowWhitelist.sol";

contract EscrowTest is Test {
    EscrowWhitelist escrow;
    address user = address(1);
    uint256 destinationAddress = uint256(2);
    address mmAddress = address(3);
    address maliciousActor = address(4);

    bytes32 destinationChainId = bytes32(uint256(1));

    uint256 sendAmount;
    uint256 feeAmount;

    address[] public whitelistAddresses;

    function setUp() public {
        whitelistAddresses.push(user);
        escrow = new EscrowWhitelist(whitelistAddresses);

        vm.deal(user, 10 ether);
        vm.deal(maliciousActor, 10 ether);

        sendAmount = 0.00001 ether;
        feeAmount = 0.000001 ether;

        escrow.setAllowedAddress(address(this));
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId);

        (
            uint256 orderId,
            uint256 usrDstAddress,
            uint256 expirationTimestamp,
            uint256 amount,
            uint256 fee,
            address usrSrcAddress,
            bytes32 _destinationChainId
        ) = escrow.orders(1);

        assertEq(orderId, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assertEq(usrSrcAddress, user);
        assertEq(_destinationChainId, destinationChainId);
        assert(expirationTimestamp > block.timestamp);

        vm.stopPrank();
    }

    function testCreateOrderWithNoValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder(destinationAddress, feeAmount, destinationChainId); // calling with no value
        vm.stopPrank();
    }

    function testCreateOrderWithZeroValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder{value: 0}(destinationAddress, feeAmount, destinationChainId); // calling with no value
        vm.stopPrank();
    }

    function testCreateOrderWithFeeBiggerThanValueSent() public {
        vm.startPrank(user);
        vm.expectRevert("Fee must be less than the total value sent");
        escrow.createOrder{value: sendAmount}(destinationAddress, 5 ether, destinationChainId);
        vm.stopPrank();
    }

    function testPauseContract() public {
        vm.startPrank(address(this)); // this contract is the owner
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Expect revert due to paused contract
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId);
        vm.stopPrank();
    }

    function testPauseAndUnpauseContract() public {
        vm.prank(address(this)); // this contract is the owner
        escrow.pauseContract();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Expect revert due to paused contract
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId);
        vm.stopPrank();

        vm.prank(address(this)); // this contract is the owner
        escrow.unpauseContract();

        vm.prank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId);

        // Assertions to check the order details
        (
            uint256 id,
            uint256 usrDstAddress,
            uint256 expirationTimestamp,
            uint256 amount,
            uint256 fee,
            address usrSrcAddress,
            bytes32 _destinationChainId
        ) = escrow.orders(1);

        assertEq(id, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assertEq(usrSrcAddress, user);
        assertEq(_destinationChainId, destinationChainId);
        assert(expirationTimestamp > block.timestamp);
    }

    function testExpirationTimestamp() public {
        vm.startPrank(user);
        uint256 currentTimestamp = block.timestamp;
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId);

        (
            uint256 orderId,
            uint256 usrDstAddress,
            uint256 expirationTimestamp,
            uint256 amount,
            uint256 fee,
            address usrSrcAddress,
            bytes32 _destinationChainId
        ) = escrow.orders(1);

        assertEq(orderId, 1);
        assertEq(usrDstAddress, destinationAddress);
        assertEq(amount, sendAmount - feeAmount);
        assertEq(fee, feeAmount);
        assertEq(usrSrcAddress, user);
        assertEq(_destinationChainId, destinationChainId);
        assert(expirationTimestamp > block.timestamp);
        assert(expirationTimestamp == currentTimestamp + 1 days);

        vm.stopPrank();
    }

    // test the refundOrder expired function
    function testRefundOrder() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId); // has an expiry date of 1 day
        // balance of user should be 9 ether
        assertEq(user.balance, 9.99999 ether); // balance goes down after making an order
        vm.warp(block.timestamp + 2 days); // order should now be expired
        // call the refund order
        escrow.refundOrder(1);
        vm.stopPrank();
        // balance should be 10 ether
        assertEq(user.balance, 10 ether);
    }

    function testUserNotWhitelisted() public {
        vm.startPrank(maliciousActor);
        vm.expectRevert("Caller is not on the whitelist");
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, destinationChainId); // has an expiry date of 1 day
        vm.stopPrank();
    }

    function testAmountExceedsWhitelistLimit() public {
        vm.startPrank(user);
        vm.expectRevert("Amount exceeds whitelist limit");
        escrow.createOrder{value: 1 ether}(destinationAddress, feeAmount, destinationChainId); // amount is too high
        vm.stopPrank();
    }
}
