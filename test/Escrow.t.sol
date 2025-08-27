// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {HookExecutor} from "src/contracts/HookExecutor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockSwapTarget {
    function swap(address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut) external {
        // mock swap: transfer tokenIn from caller and mint tokenOut to caller
        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).mint(msg.sender, amountOut);
    }
}

contract EscrowTest is Test {
    Escrow escrow;
    address owner;
    address user = address(1);
    bytes32 destinationAddress = bytes32(uint256(2));
    address mmAddress = address(3);
    address maliciousActor = address(4);
    address srcTokenETH = address(0);
    bytes32 dstToken = bytes32(uint256(69));

    bytes32 dstChainId = bytes32(uint256(1));

    uint256 firstOrderId = 1;
    uint256 public constant expiryWindow = 1 days;

    uint256 sendAmount = 0.00001 ether;
    uint256 dstAmount = 0.000009 ether;

    MockERC20 public mockERC;
    MockERC20 public mockERC2;
    MockSwapTarget public mockSwapTarget;

    // helper to create empty hooks array
    function createEmptyHooks() internal pure returns (HookExecutor.Hook[] memory) {
        return new HookExecutor.Hook[](0);
    }

    function setUp() public {
        Escrow.HDPConnectionInitial[] memory initialHDPChainConnections = new Escrow.HDPConnectionInitial[](1);

        // For Ethereum Sepolia
        initialHDPChainConnections[0] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(111555111)),
            paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
            hdpProgramHash: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4))
        });

        escrow = new Escrow(initialHDPChainConnections);
        vm.deal(user, 10 ether);
        owner = address(this);

        // deploy mock ERC20 tokens and mint them to user
        mockERC = new MockERC20("MockToken", "MOCK");
        mockERC.mint(user, 10 ether);

        mockERC2 = new MockERC20("MockToken2", "MOCK2");
        mockERC2.mint(address(this), 10 ether); // mint to test contract for swap target

        mockSwapTarget = new MockSwapTarget();
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );

        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + expiryWindow,
                srcTokenETH,
                sendAmount,
                dstToken,
                dstAmount,
                block.chainid,
                dstChainId
            )
        );

        assertEq(uint256(escrow.orderStatus(expectedOrderHash)), uint256(Escrow.OrderState.PENDING));
        vm.stopPrank();
    }

    function testCreateOrderWithNoValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0");
        escrow.createOrder(destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow);
        vm.stopPrank();
    }

    function testPauseContract() public {
        vm.startPrank(owner);
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        vm.stopPrank();
    }

    function testPauseAndUnpauseContract() public {
        vm.prank(owner);
        escrow.pauseContract();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );

        vm.prank(owner);
        escrow.unpauseContract();

        vm.prank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + expiryWindow,
                srcTokenETH,
                sendAmount,
                dstToken,
                dstAmount,
                block.chainid,
                dstChainId
            )
        );

        assertEq(uint256(escrow.orderStatus(expectedOrderHash)), uint256(Escrow.OrderState.PENDING));
    }

    function testRefundOrder() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        assertEq(user.balance, 9.99999 ether); // user balance decreased

        uint256 expirationTimestamp = block.timestamp + expiryWindow;
        vm.warp(block.timestamp + expiryWindow + 1 days); // order is now expired

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcTokenETH,
            srcAmount: sendAmount,
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        escrow.refundOrder(orderToRefund);

        assertEq(user.balance, 10 ether); // user balance restored
        vm.stopPrank();
    }

    function testRefundOrderByWrongUser() public {
        vm.prank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        uint256 expirationTimestamp = block.timestamp + expiryWindow;

        vm.warp(block.timestamp + expiryWindow + 2 days); // order expired

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcTokenETH,
            srcAmount: sendAmount,
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        vm.prank(maliciousActor);
        vm.expectRevert("Only the original address can refund an order");
        escrow.refundOrder(orderToRefund);
    }

    function testRefundOrderBeforeExpiration() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        uint256 expirationTimestamp = block.timestamp + expiryWindow;

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcTokenETH,
            srcAmount: sendAmount,
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        vm.expectRevert("Order has not expired yet");
        escrow.refundOrder(orderToRefund);
        vm.stopPrank();
    }

    function testRefundOrderWithWrongDetails() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        vm.stopPrank();
        uint256 expirationTimestamp = block.timestamp + expiryWindow;

        vm.warp(block.timestamp + expiryWindow + 1 days); // order expired

        vm.deal(address(this), 10 ether); // ensure the contract has enough ETH to refund the order

        vm.startPrank(user);
        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: bytes32(uint256(12345)), // Wrong address
            expirationTimestamp: expirationTimestamp,
            srcToken: srcTokenETH,
            srcAmount: sendAmount,
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        vm.expectRevert("Cannot refund a non-pending order");
        escrow.refundOrder(orderToRefund);
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
        bytes32 newHDPProgramHash = keccak256(abi.encode("new-program-hash"));
        bytes32 newPaymentRegistryAddress = keccak256(abi.encode("new-program-hash"));
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
        escrow.createOrder{value: sendAmount}(
            destinationAddress, srcTokenETH, sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
    }

    function testCreateOrderERC20Success() public {
        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.prank(user);
        escrow.createOrder(
            destinationAddress, address(mockERC), sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );

        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + expiryWindow,
                address(mockERC),
                sendAmount,
                dstToken,
                dstAmount,
                block.chainid,
                dstChainId
            )
        );

        assertEq(uint256(escrow.orderStatus(expectedOrderHash)), uint256(Escrow.OrderState.PENDING));
        assertEq(mockERC.balanceOf(user), 9.99999 ether, "User balance should decrease by sendAmount");
        assertEq(mockERC.allowance(user, address(escrow)), 0, "Allowance should be reset to 0 after order creation");
    }

    function testCreateOrderERC20FailsIfMsgValueNonZero() public {
        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.prank(user);
        vm.expectRevert("ERC20: msg.value must be 0");
        escrow.createOrder{value: 1 ether}(
            destinationAddress, address(mockERC), sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
    }

    function testCreateOrderERC20FailsIfAmountZero() public {
        vm.prank(user);
        mockERC.approve(address(escrow), 1 ether);

        vm.prank(user);
        vm.expectRevert("ERC20: _srcAmount must be greater than 0");
        escrow.createOrder(destinationAddress, address(mockERC), 0, dstToken, 0, dstChainId, expiryWindow);
    }

    function testCreateOrderWithERC20NoApproval() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)", address(escrow), 0, sendAmount
            )
        );
        escrow.createOrder(
            destinationAddress, address(mockERC), sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        vm.stopPrank();
    }

    function testCreateOrderWithERC20WithEth() public {
        vm.startPrank(user);
        mockERC.approve(address(escrow), sendAmount);
        vm.expectRevert("ERC20: msg.value must be 0");
        escrow.createOrder{value: sendAmount}(
            destinationAddress, address(mockERC), sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        vm.stopPrank();
    }

    function testRefundOrderERC20() public {
        vm.startPrank(user);
        mockERC.approve(address(escrow), sendAmount);
        escrow.createOrder(
            destinationAddress, address(mockERC), sendAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );
        assertEq(mockERC.balanceOf(user), 10 ether - sendAmount); // user balance decreased

        uint256 expirationTimestamp = block.timestamp + expiryWindow;
        vm.warp(block.timestamp + expiryWindow + 1 days); // order is now expired

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: address(mockERC),
            srcAmount: sendAmount,
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        escrow.refundOrder(orderToRefund);
        assertEq(mockERC.balanceOf(user), 10 ether);
        vm.stopPrank();
    }

    // New tests for swap functionality
    function testCreateOrderWithSwapRequiresERC20() public {
        vm.prank(user);
        vm.expectRevert("Swaps require ERC20 tokens");
        escrow.swapAndCreateOrder(
            destinationAddress,
            srcTokenETH,
            sendAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            address(mockERC2),
            bytes32(0),
            createEmptyHooks()
        );
    }

    function testCreateOrderWithSwapRequiresHooks() public {
        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.expectRevert("Swaps require at least one hook");
        escrow.swapAndCreateOrder(
            destinationAddress,
            address(mockERC),
            sendAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            address(mockERC2),
            bytes32(0),
            createEmptyHooks()
        );
    }

    function testCreateOrderWithSwapSuccess() public {
        // Create a hook that calls the mock swap target
        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](1);
        hooks[0] = HookExecutor.Hook({
            target: address(mockSwapTarget),
            callData: abi.encodeWithSignature(
                "swap(address,uint256,address,uint256)",
                address(mockERC),
                sendAmount,
                address(mockERC2),
                sendAmount * 2 // 2x output for testing
            )
        });

        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.prank(user);
        escrow.swapAndCreateOrder(
            destinationAddress,
            address(mockERC),
            sendAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            address(mockERC2),
            bytes32(0),
            hooks
        );

        // Check that the order was created with the swapped token
        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + expiryWindow,
                address(mockERC2), // finalSrcToken should be the output token
                sendAmount * 2, // finalSrcAmount should be the output amount
                dstToken,
                dstAmount,
                block.chainid,
                dstChainId
            )
        );

        assertEq(uint256(escrow.orderStatus(expectedOrderHash)), uint256(Escrow.OrderState.PENDING));

        // Check that the user's original token balance decreased
        assertEq(mockERC.balanceOf(user), 10 ether - sendAmount, "User balance should decrease by sendAmount");

        // Check that the escrow now holds the swapped tokens
        assertEq(mockERC2.balanceOf(address(escrow)), sendAmount * 2, "Escrow should hold the swapped tokens");
    }

    function testSwapCompletedEvent() public {
        // Create a hook that calls the mock swap target
        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](1);
        hooks[0] = HookExecutor.Hook({
            target: address(mockSwapTarget),
            callData: abi.encodeWithSignature(
                "swap(address,uint256,address,uint256)", address(mockERC), sendAmount, address(mockERC2), sendAmount * 2
            )
        });

        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        // Calculate expected swapId
        bytes32 expectedSwapId =
            keccak256(abi.encodePacked(firstOrderId, user, address(mockERC), sendAmount, block.timestamp));

        vm.expectEmit(true, true, true, true);
        emit Escrow.SwapCompleted(expectedSwapId, user, address(mockERC), sendAmount, address(mockERC2), sendAmount * 2);

        vm.prank(user);
        escrow.swapAndCreateOrder(
            destinationAddress,
            address(mockERC),
            sendAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            address(mockERC2),
            bytes32(0),
            hooks
        );
    }

    function testRefundOrderWithSwappedToken() public {
        // Create a hook that calls the mock swap target
        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](1);
        hooks[0] = HookExecutor.Hook({
            target: address(mockSwapTarget),
            callData: abi.encodeWithSignature(
                "swap(address,uint256,address,uint256)", address(mockERC), sendAmount, address(mockERC2), sendAmount * 2
            )
        });

        vm.startPrank(user);
        mockERC.approve(address(escrow), sendAmount);

        escrow.swapAndCreateOrder(
            destinationAddress,
            address(mockERC),
            sendAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            address(mockERC2),
            bytes32(0),
            hooks
        );

        uint256 expirationTimestamp = block.timestamp + expiryWindow;
        vm.warp(block.timestamp + expiryWindow + 1 days); // order is now expired

        // The refund should be in the swapped token (mockERC2) with the swapped amount
        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: address(mockERC2), // swapped token
            srcAmount: sendAmount * 2, // swapped amount
            dstToken: dstToken,
            dstAmount: dstAmount,
            dstChainId: dstChainId
        });

        uint256 userBalanceBefore = mockERC2.balanceOf(user);
        escrow.refundOrder(orderToRefund);
        assertEq(
            mockERC2.balanceOf(user), userBalanceBefore + sendAmount * 2, "User should receive refund in swapped token"
        );
        vm.stopPrank();
    }
}
