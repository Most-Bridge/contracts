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
    uint256 public constant ONE_YEAR = 365 days;

    address[] public whitelistAddresses; // TODO: remove once done using whitelist

    function setUp() public {
        Escrow.HDPConnectionInitial[] memory initialHDPChainConnections = new Escrow.HDPConnectionInitial[](1);

        // For Ethereum Sepolia
        initialHDPChainConnections[0] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(111555111)),
            paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
            hdpProgramHash: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4))
        });

        whitelistAddresses.push(user); // TODO: remove once done using whitelist

        escrow = new Escrow(initialHDPChainConnections);
        vm.deal(user, 10 ether);
        sendAmount = 1 ether;
        feeAmount = 0.1 ether;
        owner = address(this);
        escrow.setAllowedAddress(owner);
        firstOrderId = 1;

        escrow.batchAddToWhitelist(whitelistAddresses);
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);

        bytes32 expectedOrderHash = keccak256(
            abi.encodePacked(
                firstOrderId,
                destinationAddress,
                block.timestamp + ONE_YEAR,
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
                block.timestamp + ONE_YEAR,
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
        uint256 expirationTimestamp = currentTimestamp + ONE_YEAR;
        uint256 bridgeAmount = sendAmount - feeAmount;

        vm.warp(block.timestamp + ONE_YEAR + 1 days); // order is now expired

        // Array with one order
        Escrow.Order[] memory ordersToRefund = new Escrow.Order[](1);
        ordersToRefund[0] = Escrow.Order({
            id: firstOrderId,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            bridgeAmount: bridgeAmount,
            fee: feeAmount,
            usrSrcAddress: user,
            dstChainId: dstChainId
        });

        // Call the batch refund function
        escrow.refundOrderBatch(ordersToRefund);

        assertEq(user.balance, 10 ether); // user balance went back up

        vm.stopPrank();
    }

    function testRefundOrderByWrongUser() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        uint256 expirationTimestamp = block.timestamp + ONE_YEAR;

        vm.warp(block.timestamp + ONE_YEAR + 2 days); // order expired

        vm.startPrank(maliciousActor);
        // Create array with one order
        Escrow.Order[] memory ordersToRefund = new Escrow.Order[](1);
        ordersToRefund[0] = Escrow.Order({
            id: firstOrderId,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            bridgeAmount: sendAmount - feeAmount,
            fee: feeAmount,
            usrSrcAddress: user, // Original user who created the order
            dstChainId: dstChainId
        });

        vm.expectRevert("Order hash mismatch");
        escrow.refundOrderBatch(ordersToRefund);
        vm.stopPrank();
    }

    function testRefundOrderBeforeExpiration() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        vm.startPrank(user);
        // Create array with one order
        Escrow.Order[] memory ordersToRefund = new Escrow.Order[](1);
        ordersToRefund[0] = Escrow.Order({
            id: firstOrderId, // Changed from 1 to firstOrderId
            usrDstAddress: destinationAddress,
            expirationTimestamp: block.timestamp + ONE_YEAR,
            bridgeAmount: sendAmount - feeAmount,
            fee: feeAmount,
            usrSrcAddress: user,
            dstChainId: dstChainId
        });

        vm.expectRevert("Cannot refund an order that has not expired.");
        escrow.refundOrderBatch(ordersToRefund);
        vm.stopPrank();
    }

    function testRefundOrderWithWrongDetails() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_YEAR + 1 days); // order expired

        vm.startPrank(user);
        // Create array with one order with wrong details
        Escrow.Order[] memory ordersToRefund = new Escrow.Order[](1);
        ordersToRefund[0] = Escrow.Order({
            id: firstOrderId,
            usrDstAddress: uint256(12345), // Wrong address
            expirationTimestamp: block.timestamp - 1 days, // Wrong timestamp
            bridgeAmount: 0.5 ether, // Wrong amount
            fee: feeAmount,
            usrSrcAddress: user,
            dstChainId: dstChainId
        });

        vm.expectRevert("Order hash mismatch");
        escrow.refundOrderBatch(ordersToRefund);
        vm.stopPrank();
    }

    function testSetHDPAddressSuccess() public {
        address newHDPExecutionStore = address(5);
        vm.prank(owner);
        escrow.setHDPAddress(newHDPExecutionStore);
        assertEq(escrow.HDP_EXECUTION_STORE_ADDRESS(), newHDPExecutionStore, "Execution store address mismatch");
    }

    function testSetHDPAddressRevertsIfNotOwner() public {
        address newHDPExecutionStore = address(5);
        vm.prank(maliciousActor);
        vm.expectRevert("Caller is not the owner");
        escrow.setHDPAddress(newHDPExecutionStore);
    }

    function testAddChain() public {
        bytes32 newHDPProgramHash = keccak256(abi.encodePacked("new-program-hash"));
        bytes32 newPaymentRegistryAddress = keccak256(abi.encodePacked("new-program-hash"));
        bytes32 destinationChain = bytes32(uint256(0x1));
        vm.prank(owner);
        escrow.addDestinationChain(destinationChain, newHDPProgramHash, newPaymentRegistryAddress);
        assertEq(
            escrow.getHDPDestinationChainConnectionDetails(destinationChain).hdpProgramHash,
            newHDPProgramHash,
            "Program hash mismatch"
        );
    }

    function testGas_createOrder() public {
        vm.prank(user);
        escrow.createOrder{value: sendAmount}(destinationAddress, feeAmount, dstChainId);
    }
}
