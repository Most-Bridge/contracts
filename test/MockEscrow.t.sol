// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockEscrow} from "../src/mock/MockEscrow.sol";

contract MockEscrowTest is Test {
    MockEscrow mockEscrow;
    MockFactsRegistry factsRegistry;

    address user = address(1);
    address destinationAddress = address(2);
    address mmSrcAddress = address(3);
    address maliciousActor = address(4);

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

    function testWithdrawProvedOnMaliciousAddress() public {
        vm.prank(user);
        (bool success,) = address(mockEscrow).call{value: 5 ether}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, 0.1 ether)
        );
        assertTrue(success, "Order was not placed successfully");

        mockEscrow.updateOrderStatus(1, MockEscrow.OrderStatus.PROVED); // changing state not local reference
        assertEq(
            uint256((mockEscrow.getOrderUpdates(1)).status),
            uint256(MockEscrow.OrderStatus.PROVED),
            "Order status should be PROVED"
        );

        mockEscrow.updatemmSrcAddress(1, mmSrcAddress);
        assertEq(mockEscrow.getOrderUpdates(1).mmSrcAddress, mmSrcAddress);

        vm.prank(maliciousActor);
        vm.expectRevert("Only the MM can withdraw.");
        mockEscrow.withdrawProved(1);
    }

    function testWithdrawProvedOnOrderThatDoesNotExist() public {
        vm.startPrank(user);
        vm.expectRevert("The following order doesn't exist");
        mockEscrow.withdrawProved(100);
    }

    function testGetValuesFromSlots() public {
        // bytes32 orderIdSlot = bytes32(uint256(0x1));
        // bytes32 dstAddressSlot = bytes32(uint256(0x2));
        // bytes32 mmSrcAddressSlot = bytes32(uint256(0x3));
        // bytes32 amountSlot = bytes32(uint256(0x4));
        // uint256 blockNumber = 5;

        // // Mock data
        // uint256 expectedOrderId = 1111;
        // address expectedDstAddress = address(0x2222);
        // address expectedMmSrcAddress = address(0x3333);
        // uint256 expectedAmount = 4444;

        // factsRegistry.setSlotValue(address(mockEscrow), blockNumber, orderIdSlot, bytes32(uint256(expectedOrderId)));
        // factsRegistry.setSlotValue(
        //     address(mockEscrow), blockNumber, dstAddressSlot, bytes32(uint256(uint160(expectedDstAddress)))
        // );
        // factsRegistry.setSlotValue(
        //     address(mockEscrow), blockNumber, mmSrcAddressSlot, bytes32(uint256(uint160(expectedMmSrcAddress)))
        // );
        // factsRegistry.setSlotValue(address(mockEscrow), blockNumber, amountSlot, bytes32(expectedAmount));

        // // Expect SlotsReceived event to be emitted
        // // vm.expectEmit(true, true, true, true);
        // // emit mockEscrow.SlotsReceived(orderIdSlot, dstAddressSlot, mmSrcAddressSlot, amountSlot, blockNumber);  // Reference mockEscrow instance

        // // get return values
        // (bytes32 returnedOrderId, bytes32 returnedDstAddress, bytes32 returnedMmSrcAddress, bytes32 returnedAmount) =
        //     mockEscrow.getValuesFromSlots(orderIdSlot, dstAddressSlot, mmSrcAddressSlot, amountSlot, blockNumber);

        // // assert correct values
        // assertEq(returnedOrderId, bytes32(uint256(expectedOrderId)));
        // assertEq(returnedDstAddress, bytes32(uint256(uint160(expectedDstAddress))));
        // assertEq(returnedMmSrcAddress, bytes32(uint256(uint160(expectedMmSrcAddress))));
        // assertEq(returnedAmount, bytes32(expectedAmount));

        // NOTE: doesn't work as expected...
        // need a better way to mock the facts registry contract
        // and test that it gets back proper values
    }

    function testConvertBytes32ToNative() public {
        // arrange
        uint256 expectedOrderId = 1;
        address expectedDstAddress = destinationAddress;
        address expectedMmSrcAddress = address(0x3333);
        uint256 expectedAmount = 4444;

        // create order
        (bool success,) = address(mockEscrow).call{value: sendAmount}(
            abi.encodeWithSelector(mockEscrow.createOrder.selector, destinationAddress, fee)
        );

        assertTrue(success, "createOrder transaction failed");

        // encode data
        bytes32 orderIdValue = bytes32(expectedOrderId);
        bytes32 dstAddressValue = bytes32(uint256(uint160(expectedDstAddress)));
        bytes32 mmSrcAddressValue = bytes32(uint256(uint160(expectedMmSrcAddress)));
        bytes32 amountValue = bytes32(expectedAmount);

        // get results
        (uint256 orderId, address dstAddress, address _mmSrcAddress, uint256 amount) =
            mockEscrow.convertBytes32toNative(orderIdValue, dstAddressValue, mmSrcAddressValue, amountValue);

        // assert
        assertEq(orderId, expectedOrderId);
        assertEq(dstAddress, expectedDstAddress);
        assertEq(_mmSrcAddress, expectedMmSrcAddress);
        assertEq(amount, expectedAmount);
    }

    function testProveBridgeTransactionSuccess() public {
        // set up order
        uint256 orderId = 1;

        // create order
        mockEscrow.createOrder{value: sendAmount + fee}(destinationAddress, fee);

        // prove bridge tx with correct data
        mockEscrow.proveBridgeTransaction(orderId, destinationAddress, mmSrcAddress, sendAmount);

        // fetch updated data
        MockEscrow.OrderStatusUpdates memory updates = mockEscrow.getOrderUpdates(orderId);

        // assert correct status and mmSrcAddress
        assertEq(uint256(updates.status), uint256(MockEscrow.OrderStatus.PROVED));
        assertEq(updates.mmSrcAddress, mmSrcAddress);
    }

    function testProveBridgeTransactionFailure() public {
        // set up order
        uint256 orderId = 1;

        // create an order
        mockEscrow.createOrder{value: sendAmount + fee}(destinationAddress, fee);

        bytes32 orderIdValue = bytes32(orderId);
        bytes32 dstAddressValue = bytes32(uint256(uint160(destinationAddress)));
        bytes32 mmSrcAddressValue = bytes32(uint256(uint160(mmSrcAddress)));
        bytes32 amountValue = bytes32(sendAmount);

        mockEscrow.convertBytes32toNative(orderIdValue, dstAddressValue, mmSrcAddressValue, amountValue);

        // order status should now be PROVING
        MockEscrow.OrderStatusUpdates memory updates = mockEscrow.getOrderUpdates(orderId);
        assertEq(uint256(updates.status), uint256(MockEscrow.OrderStatus.PROVING));

        // call prove bridgeTransaction with incorrect data
        address badDstAddress = address(0x9999);
        mockEscrow.proveBridgeTransaction(orderId, badDstAddress, mmSrcAddress, sendAmount);

        // check that the status is now back to pending
        updates = mockEscrow.getOrderUpdates(orderId);
        assertEq(uint256(updates.status), uint256(MockEscrow.OrderStatus.PENDING));
    }

    function testBatchWithdrawProvedSuccess() public {
        uint256[] memory orderIds;

        for (uint256 i = 0; i < orderIds.length; i++) {
            // create order
            mockEscrow.createOrder{value: sendAmount + fee}(destinationAddress, fee);

            // set order Ids
            orderIds[i] = i + 1;

            // prove order
            mockEscrow.proveBridgeTransaction(orderIds[i], destinationAddress, mmSrcAddress, sendAmount);
        }

        // TODO: check that balance of this contract is now worth two orders
        uint256 expectedBalance = (sendAmount + fee) * orderIds.length;
        assertEq(address(mockEscrow).balance, expectedBalance, "Contract balance does not match");

        // call from the mm persepctive
        vm.prank(mmSrcAddress);

        // call the batch withdraw proved
        mockEscrow.batchWithdrawProved(orderIds);

        // verify orders are makred as COMPLETED
        for (uint256 i = 0; i < orderIds.length; i++) {
            MockEscrow.OrderStatusUpdates memory updates = mockEscrow.getOrderUpdates(orderIds[i]);
            assertEq(uint256(updates.status), uint256(MockEscrow.OrderStatus.COMPLETED));
        }

        // verify that the correct amount was sent to MM
        assertEq(mmSrcAddress.balance, (sendAmount + fee) * orderIds.length);
    }
}

contract MockFactsRegistry {
    mapping(address => mapping(uint256 => mapping(bytes32 => bytes32))) public accountStorageSlotValues;

    function setSlotValue(address _contract, uint256 _blockNumber, bytes32 _slot, bytes32 _value) public {
        accountStorageSlotValues[_contract][_blockNumber][_slot] = _value;
    }
}
