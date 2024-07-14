// SPDX-License-Identifier: MIT
// SUBMODULE TEST
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;
    address user = address(1);
    address destinationAddress = address(2);
    address mmAddress = address(3);
    address maliciousActor = address(4);

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether);
    }

    function testCreateOrder() public {
        vm.startPrank(user);
        uint256 initialBalance = user.balance;
        uint256 sendAmount = 1 ether;
        uint256 fee = 0.1 ether;

        (bool success,) = address(escrow).call{value: sendAmount}(
            abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, fee)
        );
        assertTrue(success, "createOrder transaction failed");

        Escrow.InitialOrderData memory order = escrow.getInitialOrderData(1);
        Escrow.OrderStatusUpdates memory orderUpdates = escrow.getOrderUpdates(1);

        assertEq(order.amount, sendAmount - fee, "Incorrect bridge amount calculated");
        assertEq(uint256(orderUpdates.status), uint256(Escrow.OrderStatus.PENDING), "Order status should be PENDING");
        assertEq(user.balance, initialBalance - sendAmount, "Ether not correctly transferred from user");

        vm.stopPrank();
    }

    function testCreateOrderWithNoFunds() public {
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder(destinationAddress, 0.1 ether); // calling with no value
    }

    function testCreateOrderWithInsufficientFee() public {
        vm.startPrank(user);
        vm.expectRevert("Fee must be less than the total value sent");
        (bool success,) = address(escrow).call{value: 1 ether}(
            abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, 5 ether)
        );
        assertTrue(success, "Function did not revert as expected");
        vm.stopPrank();
    }

    function testWithdrawProvedOnOrderThatDoesNotExist() public {
        vm.startPrank(user);
        vm.expectRevert("The following order doesn't exist");
        escrow.withdrawProved(100);
    }

    function testWithdrawProvedOnPendingStatus() public {
        vm.prank(user);
        (bool success,) = address(escrow).call{value: 5 ether}(
            abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, 0.1 ether)
        );
        assertTrue(success, "Order was not placed successfully");

        Escrow.OrderStatusUpdates memory orderUpdates = escrow.getOrderUpdates(1);
        assertEq(uint256(orderUpdates.status), uint256(Escrow.OrderStatus.PENDING), "Order status should be PENDING");

        vm.prank(mmAddress);
        vm.expectRevert("This order has not been proved yet.");
        escrow.withdrawProved(1);
    }

    function testWithdrawProvedOnMaliciousAddress() public {
        vm.prank(user);
        (bool success,) = address(escrow).call{value: 5 ether}(
            abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, 0.1 ether)
        );
        assertTrue(success, "Order was not placed successfully");

        escrow.updateOrderStatus(1, Escrow.OrderStatus.PROVED); // changing state not local reference
        assertEq(
            uint256((escrow.getOrderUpdates(1)).status),
            uint256(Escrow.OrderStatus.PROVED),
            "Order status should be PROVED"
        );

        escrow.updateMarketMakerSourceAddress(1, mmAddress);
        assertEq(escrow.getOrderUpdates(1).marketMakerSourceAddress, mmAddress);

        vm.prank(maliciousActor);
        vm.expectRevert("Only the MM can withdraw.");
        escrow.withdrawProved(1);
    }
    // fail if contract has insuffienct funds
}
