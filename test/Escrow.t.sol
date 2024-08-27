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

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether);
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

}
