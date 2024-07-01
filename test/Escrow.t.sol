// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Escrow.sol"; 

contract EscrowTest is Test {
    Escrow escrow;
    address user = address(1);
    address destinationAddress = address(2);
    address mmAddress = address(3);

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether); 
    }

    function testCreateOrder() public {
        vm.startPrank(user);
        uint256 initialBalance = user.balance;
        uint256 sendAmount = 1 ether;
        uint256 fee = 0.1 ether;

        (bool success, ) = address(escrow).call{value: sendAmount}(abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, fee));
        assertTrue(success, "createOrder transaction failed");

        Escrow.InitialOrderData memory order = escrow.getInitialOrderData(1);
        Escrow.OrderStatusUpdates memory log = escrow.getOrderUpdates(1);

        assertEq(order.amount, sendAmount - fee, "Incorrect bridge amount calculated");
        assertEq(uint(log.status), uint(Escrow.OrderStatus.PENDING), "Order status should be PENDING");
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
        (bool success, ) = address(escrow).call{value: 1 ether}(abi.encodeWithSelector(escrow.createOrder.selector, destinationAddress, 5 ether));
        assertTrue(success, "Function did not revert as expected");
        vm.stopPrank();
    }

    // try to withdrawProven on an order that doesn't exist, should return a 0 instead of id
    // test withdrawing an order that has not been marked as Proved yet 
    // test that only the market can call the function for the orderId they are marked under
    // fail if contract has insuffienct funds 
}
