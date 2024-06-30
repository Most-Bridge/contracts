// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Escrow.sol"; 

contract EscrowTest is Test {
    Escrow escrow;
    address user = address(1);

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether); 
    }

    function testCreateOrder() public {
        vm.startPrank(user);
        uint256 initialBalance = user.balance;
        uint256 sendAmount = 1 ether;
        uint256 fee = 0.1 ether;

        (bool success, ) = address(escrow).call{value: sendAmount}(abi.encodeWithSelector(escrow.createOrder.selector, 12345, fee));
        assertTrue(success, "createOrder transaction failed");

        Escrow.InitialOrderData memory order = escrow.getInitialOrderData(0);
        Escrow.OrderStatusUpdates memory log = escrow.getOrderUpdates(0);

        assertEq(order.amount, sendAmount - fee, "Incorrect bridge amount calculated");
        assertEq(uint(log.status), uint(Escrow.OrderStatus.PENDING), "Order status should be PENDING");
        assertEq(user.balance, initialBalance - sendAmount, "Ether not correctly transferred from user");

        vm.stopPrank();
    }

    // additional tests: 
    // order creation with zero funds
    // creating an order with not enough funds for fees

}
