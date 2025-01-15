// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../../src/contracts/SMM/EscrowSMM.sol";

contract EscrowTest is Test {
    Escrow escrow;
    address user = address(1);
    uint256 destinationAddress = uint256(2);
    address mmAddress = address(3);
    address maliciousActor = address(4);

    bytes32 dstChainId = bytes32(uint256(1));

    uint256 sendAmount;
    uint256 feeAmount;
    address owner;
    uint256 firstOrderId;

    function setUp() public {
        escrow = new Escrow();
        vm.deal(user, 10 ether);
        sendAmount = 1 ether;
        feeAmount = 0.1 ether;
        owner = address(this);
        escrow.setAllowedAddress(owner);
        firstOrderId = 1;
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);

        bytes32 expectedOrderHash = keccak256(
            abi.encodePacked(
                firstOrderId,
                destinationAddress,
                block.timestamp + 6 weeks,
                sendAmount - feeAmount,
                feeAmount,
                user,
                dstChainId
            )
        );

        assertEq(escrow.orders(1), expectedOrderHash);
        assertEq(uint256(escrow.orderStatus(1)), uint256(Escrow.OrderState.PENDING));
        vm.stopPrank();
    }

    function testCreateOrderWithNoValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0.");
        escrow.createOrder(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();
    }

    function testCreateOrderWithFeeBiggerThanValueSent() public {
        vm.startPrank(user);
        vm.expectRevert("Fee must be less than the total value sent");
        escrow.createOrder{value: sendAmount}(destinationAddress, 5 ether, dstChainId);
        vm.stopPrank();
    }

    function testPauseContract() public {
        vm.startPrank(owner);
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();
    }

    function testPauseAndUnpauseContract() public {
        vm.startPrank(owner);
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        vm.startPrank(owner);
        escrow.unpauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);

        bytes32 expectedOrderHash = keccak256(
            abi.encodePacked(
                firstOrderId,
                destinationAddress,
                block.timestamp + 6 weeks,
                sendAmount - feeAmount,
                feeAmount,
                user,
                dstChainId
            )
        );

        assertEq(escrow.orders(1), expectedOrderHash);
        assertEq(uint256(escrow.orderStatus(1)), uint256(Escrow.OrderState.PENDING));
        vm.stopPrank();
    }

    function testRefundOrder() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);

        assertEq(user.balance, 9 ether); // user balance decreased by 1 eth

        uint256 currentTimestamp = block.timestamp;
        uint256 expirationTimestamp = currentTimestamp + 6 weeks;
        uint256 bridgeAmount = sendAmount - feeAmount;

        vm.warp(block.timestamp + 7 weeks); // order is now expired

        escrow.refundOrder(firstOrderId, destinationAddress, expirationTimestamp, bridgeAmount, feeAmount, dstChainId);

        assertEq(user.balance, 10 ether); // user balance went back up

        vm.stopPrank();
    }

    function testRefundOrderByWrongUser() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        uint256 expirationTimestamp = block.timestamp + 6 weeks;

        vm.warp(block.timestamp + 2 days); // order expired

        vm.startPrank(maliciousActor); //
        vm.expectRevert("Order hash mismatch");
        escrow.refundOrder(
            firstOrderId, destinationAddress, expirationTimestamp, sendAmount - feeAmount, feeAmount, dstChainId
        );
        vm.stopPrank();
    }

    function testRefundOrderBeforeExpiration() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("Cannot refund an order that has not expired.");
        escrow.refundOrder(
            1, destinationAddress, block.timestamp + 6 weeks, sendAmount - feeAmount, feeAmount, dstChainId
        );
        vm.stopPrank();
    }

    function testRefundOrderWithWrongDetails() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        vm.startPrank(user);
        vm.expectRevert("Order hash mismatch");
        escrow.refundOrder(1, 12345, block.timestamp - 1 days, 0.5 ether, feeAmount, dstChainId);
        vm.stopPrank();
    }

    function testSetHDPAddressSuccess() public {
        address newHDPExecutionStore = address(5);
        uint256 newHDPProgramHash = uint256(keccak256(abi.encodePacked("new-program-hash")));
        vm.prank(owner);
        escrow.setHDPAddress(newHDPExecutionStore, newHDPProgramHash);

        assertEq(escrow.HDP_EXECUTION_STORE_ADDRESS(), newHDPExecutionStore, "Execution store address mismatch");
        assertEq(escrow.HDP_PROGRAM_HASH(), newHDPProgramHash, "Program hash mismatch");
    }

    function testSetHDPAddressRevertsIfNotOwner() public {
        address newHDPExecutionStore = address(5);
        uint256 newHDPProgramHash = uint256(keccak256(abi.encodePacked("new-program-hash")));
        vm.prank(maliciousActor);
        vm.expectRevert("Caller is not the owner");
        escrow.setHDPAddress(newHDPExecutionStore, newHDPProgramHash);
    }
}
