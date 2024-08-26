// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockEscrow} from "../src/mock/MockEscrow.sol";

contract MockEscrowTest is Test {
    MockEscrow mockEscrow;
    MockFactsRegistry factsRegistry;
    address user = address(1);

    function setUp() public {
        factsRegistry = new MockFactsRegistry();
        mockEscrow = new MockEscrow();
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
        uint256 expectedOrderId = 111; 
        address expectedDstAddress = address(0x2222); 
        address expectedMmSrcAddress = address(0x3333); 
        uint256 expectedAmount = 4444; 

        // create order 
        mockEscrow.createOrder(expectedDstAddress, 100);

        // encode data 
        bytes32 orderIdValue = bytes32(expectedOrderId); 
        bytes32 dstAddressValue = bytes32(uint256(uint160(expectedDstAddress)));
        bytes32 mmSrcAddressValue = bytes32(uint256(uint160(expected)))
    }
}

contract MockFactsRegistry {
    mapping(address => mapping(uint256 => mapping(bytes32 => bytes32))) public accountStorageSlotValues;

    function setSlotValue(address _contract, uint256 _blockNumber, bytes32 _slot, bytes32 _value) public {
        accountStorageSlotValues[_contract][_blockNumber][_slot] = _value;
    }
}
