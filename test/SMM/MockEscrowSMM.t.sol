// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockEscrow} from "../../src/mock/MockEscrow.sol";

contract MockEscrowTest is Test {
    MockEscrow mockEscrow;
    MockFactsRegistry factsRegistry;

    address user = address(1);
    address destinationAddress = address(2);
    address mmSrcAddress = address(3);
    address maliciousActor = address(4);
    address allowedRelayAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
    address allowedWithdrawalAddress = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;

    uint256 sendAmount = 1 ether;
    uint256 fee = 0.1 ether;

    function setUp() public {
        factsRegistry = new MockFactsRegistry();
        mockEscrow = new MockEscrow();
        vm.deal(user, 10 ether);
    }

    function testCreateOrder() public {
        vm.startPrank(user);
        uint256 initialBalance = user.balance;

        (bool success,) = address(mockEscrow).call{value: sendAmount}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, fee)
        );
        assertTrue(success, "createOrder transaction failed");

        MockEscrow.InitialOrderData memory order = mockEscrow.getInitialOrderData(1);
        MockEscrow.OrderStatusUpdates memory orderUpdates = mockEscrow.getOrderUpdates(1);

        assertEq(order.amount, sendAmount - fee, "Incorrect bridge amount calculated");
        assertEq(
            uint256(orderUpdates.status), uint256(MockEscrow.OrderStatus.PENDING), "Order status should be PENDING"
        );
        assertEq(user.balance, initialBalance - sendAmount, "Ether not correctly transferred from user");

        vm.stopPrank();
    }

    function testWithdrawProvedOnPendingStatus() public {
        vm.prank(user);
        (bool success,) = address(mockEscrow).call{value: 5 ether}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, 0.1 ether)
        );
        assertTrue(success, "Order was not placed successfully");

        MockEscrow.OrderStatusUpdates memory orderUpdates = mockEscrow.getOrderUpdates(1);
        assertEq(
            uint256(orderUpdates.status), uint256(MockEscrow.OrderStatus.PENDING), "Order status should be PENDING"
        );

        vm.prank(mmSrcAddress);
        vm.expectRevert("This order has not been proved yet.");
        mockEscrow.withdrawProved(1);
    }

    function testWithdrawProvedOnOrderThatDoesNotExist() public {
        vm.startPrank(user);
        vm.expectRevert("The following order doesn't exist");
        mockEscrow.withdrawProved(100);
    }

    function testConvertBytes32ToNative() public {
        // arrange
        uint256 expectedOrderId = 1;
        address expectedDstAddress = destinationAddress;
        uint256 expectedExpirationTimestamp = block.timestamp;
        uint256 expectedAmount = 4444;

        // create order
        (bool success,) = address(mockEscrow).call{value: sendAmount}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, fee)
        );

        assertTrue(success, "createOrder transaction failed");

        // encode data
        bytes32 orderIdValue = bytes32(expectedOrderId);
        bytes32 dstAddressValue = bytes32(uint256(uint160(expectedDstAddress)));
        bytes32 expirationTimestampValue = bytes32(expectedExpirationTimestamp);
        bytes32 amountValue = bytes32(expectedAmount);

        // get results
        (uint256 orderId, address dstAddress, uint256 expirationTimestamp, uint256 amount) =
            mockEscrow.convertBytes32toNative(orderIdValue, dstAddressValue, expirationTimestampValue, amountValue);

        // assert
        assertEq(orderId, expectedOrderId);
        assertEq(dstAddress, expectedDstAddress);
        assertEq(expirationTimestamp, expectedExpirationTimestamp);
        assertEq(amount, expectedAmount);
    }

    // TODO: test that the allowed withdraw address gets its balance increased for a batch successful withdrawal
    // TODO: compareStorageValues slots pass
    // TODO: compareStorageValues slots fail

    function testSuccessfulWithdrawalBalanceIncrease() public {
        assertEq(allowedWithdrawalAddress.balance, 0 ether);

        vm.startPrank(user);
        (bool success,) = address(mockEscrow).call{value: sendAmount}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, fee)
        );
        assertTrue(success, "createOrder transaction failed");
        mockEscrow.updateOrderStatus(1, MockEscrow.OrderStatus.PROVED);
        vm.stopPrank();

        vm.prank(allowedRelayAddress);
        mockEscrow.withdrawProved(1);

        // MM balance increased by order amount
        assertEq(allowedWithdrawalAddress.balance, sendAmount);
    }

    function testSuccessfulWithdrawalBalanceIncreaseBatch() public {
        uint256 counter = 0;

        // creating and proving 3 orders
        while (counter < 3) {
            vm.startPrank(user);
            (bool success,) = address(mockEscrow).call{value: sendAmount}(
                abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, fee)
            );
            assertTrue(success, "createOrder transaction failed");
            mockEscrow.updateOrderStatus(1, MockEscrow.OrderStatus.PROVED);
            vm.stopPrank();
            counter++;
        }

        uint256[] calldata orderIds = [1, 2, 3];

        // Assign values to each index
        // orderIds[0] = 1;
        // orderIds[1] = 2;
        // orderIds[2] = 3;

        vm.prank(allowedRelayAddress);
        // mockEscrow.withdrawProvedBatch(orderIds);

        // assertEq(allowedWithdrawalAddress, 3 ether);
    }

    function testCalculateSlots() public {
        address testUser = address(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8);
        address testDstAddress = address(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8);
        uint256 testAmount = 1 ether;
        uint256 testFee = 0.1 ether;
        vm.deal(testUser, 10 ether);

        vm.startPrank(testUser);
        mockEscrow.createOrder{value: testAmount}(testDstAddress, testFee); // orderId #1

        (bytes32 _orderIdSlot, bytes32 _usrDstAddressSlot, bytes32 _expirationTimestampSlot, bytes32 _amountSlot) =
            mockEscrow.calculateStorageSlots(1);

        assertEq(_orderIdSlot, bytes32(0x48922ff644596f89525405cfb68628c719bd89b667d7df03231de924654e6b09));
        assertEq(_usrDstAddressSlot, bytes32(0x48922ff644596f89525405cfb68628c719bd89b667d7df03231de924654e6b0a));
        assertEq(_expirationTimestampSlot, bytes32(0x48922ff644596f89525405cfb68628c719bd89b667d7df03231de924654e6b0b));
        assertEq(_amountSlot, bytes32(0x48922ff644596f89525405cfb68628c719bd89b667d7df03231de924654e6b0c));
    }
}

contract MockFactsRegistry {
    mapping(address => mapping(uint256 => mapping(bytes32 => bytes32))) public accountStorageSlotValues;

    function setSlotValue(address _contract, uint256 _blockNumber, bytes32 _slot, bytes32 _value) public {
        accountStorageSlotValues[_contract][_blockNumber][_slot] = _value;
    }
}
