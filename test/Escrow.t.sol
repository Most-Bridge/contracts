// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EscrowTest is Test {
    Escrow escrow;
    address owner;
    address user = address(1);
    bytes32 destinationAddress = bytes32(uint256(2));
    address mmAddress = address(3);
    address maliciousActor = address(4);
    address _srcTokenETH = address(0);
    bytes32 _dstToken = bytes32(uint256(69));

    bytes32 dstChainId = bytes32(uint256(1));
    bytes32 public constant SRC_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000AA36A7;

    uint256 firstOrderId = 1;
    uint256 public constant ONE_DAY = 1 days;

    uint256 sendAmount = 0.00001 ether;
    uint256 _dstAmount = 0.000009 ether;

    MockERC20 public mockERC;

    function setUp() public {
        Escrow.HDPConnectionInitial[] memory initialHDPChainConnections = new Escrow.HDPConnectionInitial[](1);

        // For Ethereum Sepolia
        initialHDPChainConnections[0] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(111555111)),
            paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
            hdpProgramHash: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4))
        });

        escrow = new Escrow(initialHDPChainConnections, mmAddress, mmAddress);
        vm.deal(user, 10 ether);
        owner = address(this);
        escrow.setAllowedAddress(owner);

        // deploy mock ERC20 token and mint it to user
        mockERC = new MockERC20("MockToken", "MOCK");
        mockERC.mint(user, 10 ether);
    }

    function testCreateOrderSuccess() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );

        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + ONE_DAY,
                _srcTokenETH,
                sendAmount,
                _dstToken,
                _dstAmount,
                SRC_CHAIN_ID,
                dstChainId
            )
        );

        assertEq(escrow.orders(1), expectedOrderHash);
        assertEq(uint256(escrow.orderStatus(1)), uint256(Escrow.OrderState.PENDING));
        vm.stopPrank();
    }

    function testCreateOrderWithNoValue() public {
        vm.startPrank(user);
        vm.expectRevert("Funds being sent must be greater than 0");
        escrow.createOrder(destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId);
        vm.stopPrank();
    }

    function testPauseContract() public {
        vm.startPrank(owner);
        escrow.pauseContract();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        vm.stopPrank();
    }

    function testPauseAndUnpauseContract() public {
        vm.prank(owner);
        escrow.pauseContract();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );

        vm.prank(owner);
        escrow.unpauseContract();

        vm.prank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + ONE_DAY,
                _srcTokenETH,
                sendAmount,
                _dstToken,
                _dstAmount,
                SRC_CHAIN_ID,
                dstChainId
            )
        );

        assertEq(escrow.orders(1), expectedOrderHash);
        assertEq(uint256(escrow.orderStatus(1)), uint256(Escrow.OrderState.PENDING));
    }

    function testRefundOrder() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        assertEq(user.balance, 9.99999 ether); // user balance decreased

        uint256 expirationTimestamp = block.timestamp + ONE_DAY;
        vm.warp(block.timestamp + ONE_DAY + 1 days); // order is now expired

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            srcEscrow: address(escrow),
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: _srcTokenETH,
            srcAmount: sendAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: SRC_CHAIN_ID,
            dstChainId: dstChainId
        });

        escrow.refundOrder(orderToRefund);

        assertEq(user.balance, 10 ether); // user balance restored
        vm.stopPrank();
    }

    function testRefundOrderByWrongUser() public {
        vm.prank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        uint256 expirationTimestamp = block.timestamp + ONE_DAY;

        vm.warp(block.timestamp + ONE_DAY + 2 days); // order expired

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            srcEscrow: address(escrow),
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: _srcTokenETH,
            srcAmount: sendAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: SRC_CHAIN_ID,
            dstChainId: dstChainId
        });

        vm.prank(maliciousActor);
        vm.expectRevert("Only the original address can refund an order");
        escrow.refundOrder(orderToRefund);
    }

    function testRefundOrderBeforeExpiration() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        uint256 expirationTimestamp = block.timestamp + ONE_DAY;

        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            srcEscrow: address(escrow),
            usrSrcAddress: user,
            usrDstAddress: destinationAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: _srcTokenETH,
            srcAmount: sendAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: SRC_CHAIN_ID,
            dstChainId: dstChainId
        });

        vm.expectRevert("Order has not expired yet");
        escrow.refundOrder(orderToRefund);
        vm.stopPrank();
    }

    function testRefundOrderWithWrongDetails() public {
        vm.startPrank(user);
        escrow.createOrder{value: sendAmount}(
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
        vm.stopPrank();

        vm.warp(block.timestamp + ONE_DAY + 1 days); // order expired

        vm.startPrank(user);
        Escrow.Order memory orderToRefund = Escrow.Order({
            id: firstOrderId,
            srcEscrow: address(escrow),
            usrSrcAddress: user,
            usrDstAddress: bytes32(uint256(12345)), // Wrong address
            expirationTimestamp: block.timestamp - 1 days, // Wrong timestamp
            srcToken: _srcTokenETH,
            srcAmount: 0.5 ether, // Wrong amount
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: SRC_CHAIN_ID,
            dstChainId: dstChainId
        });

        vm.expectRevert("Order hash mismatch");
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
            destinationAddress, _srcTokenETH, sendAmount, _dstToken, _dstAmount, dstChainId
        );
    }

    function testCreateOrderERC20Success() public {
        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.prank(user);
        escrow.createOrder(destinationAddress, address(mockERC), sendAmount, _dstToken, _dstAmount, dstChainId);

        bytes32 expectedOrderHash = keccak256(
            abi.encode(
                firstOrderId,
                address(escrow),
                user,
                destinationAddress,
                block.timestamp + ONE_DAY,
                address(mockERC),
                sendAmount,
                _dstToken,
                _dstAmount,
                SRC_CHAIN_ID,
                dstChainId
            )
        );

        assertEq(escrow.orders(1), expectedOrderHash);
        assertEq(uint256(escrow.orderStatus(1)), uint256(Escrow.OrderState.PENDING));
        assertEq(mockERC.balanceOf(user), 9.99999 ether, "User balance should decrease by sendAmount");
        assertEq(mockERC.allowance(user, address(escrow)), 0, "Allowance should be reset to 0 after order creation");
    }

    function testCreateOrderERC20FailsIfMsgValueNonZero() public {
        vm.prank(user);
        mockERC.approve(address(escrow), sendAmount);

        vm.prank(user);
        vm.expectRevert("ERC20: msg.value must be 0");
        escrow.createOrder{value: 1 ether}(
            destinationAddress, address(mockERC), sendAmount, _dstToken, _dstAmount, dstChainId
        );
    }

    function testCreateOrderERC20FailsIfAmountZero() public {
        vm.prank(user);
        mockERC.approve(address(escrow), 1 ether);

        vm.prank(user);
        vm.expectRevert("ERC20: _srcAmount must be greater than 0");
        escrow.createOrder(destinationAddress, address(mockERC), 0, _dstToken, 0, dstChainId);
    }
}
