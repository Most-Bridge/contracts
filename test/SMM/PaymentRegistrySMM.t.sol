// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "../../src/contracts/SMM/PaymentRegistrySMM.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PaymentRegistryTest is Test {
    PaymentRegistry public paymentRegistry;
    uint256 orderId = 1;
    bytes32 userSrcAddress = bytes32(uint256(1));
    address userDstAddress = address(1);
    uint256 expirationTimestamp = block.timestamp + 1 days;
    bytes32 srcToken = bytes32(uint256(11));
    uint256 srcAmount = 1 ether;
    address dstTokenETH = address(0);
    uint256 dstAmount = 0.9 ether;
    uint256 fee = 0.1 ether;
    bytes32 srcChainId = bytes32(uint256(2));
    // TODO: must match whatever is in the payment registry contract.
    bytes32 constant DST_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000000001;

    MockERC20 public mockERC;

    address MMAddress = address(3);

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(MMAddress, 10 ether);
        vm.deal(userDstAddress, 1 ether);
        vm.prank(address(this));
        paymentRegistry.setAllowedMMAddress(MMAddress);

        // deploy mock ERC20 token and mint it to MM
        mockERC = new MockERC20("MockToken", "MOCK");
        mockERC.mint(MMAddress, 10 ether);
    }

    function testFulfillmentSuccess() public {
        vm.prank(MMAddress); // mm calls
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                srcAmount,
                dstTokenETH,
                dstAmount,
                fee,
                srcChainId,
                DST_CHAIN_ID
            )
        );

        assertTrue(paymentRegistry.fulfillments(orderHash), "Order was not marked as processed.");
        assertEq(address(userDstAddress).balance, 1.9 ether, "User destination address balance did not increase.");
        assertEq(address(MMAddress).balance, 9.1 ether, "MM balance did not decrease.");
    }

    function testFulfillmentFailsIfAlreadyProcessed() public {
        vm.startPrank(MMAddress);
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );

        vm.expectRevert("Transfer already processed");
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );
        vm.stopPrank();
    }

    function testFulfillmentFailsIfNoValue() public {
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: msg.value mismatch with destination amount");
        paymentRegistry.mostFulfillment{value: 0}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );
    }

    function testFulfillmentFailsIfWrongValue() public {
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: msg.value mismatch with destination amount");
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount + 1 ether,
            fee,
            srcChainId
        );
    }

    function testFulfillmentFailsOnExpiredOrder() public {
        vm.prank(MMAddress);
        vm.expectRevert("Cannot fulfill an expired order.");
        // warping time to expire order
        vm.warp(block.timestamp + 2 days);
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );
    }

    function testMMSendsMoreThanBalance() public {
        vm.prank(MMAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillment{value: 20 ether}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );
    }

    function testFulfillmentPassesOnERC20() public {
        // send a good erc20 transfer
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillment{value: 0}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            dstAmount,
            fee,
            srcChainId
        );
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(MMAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
    }

    function testFulfillmentFailsOnEthSentOnERC20() public {
        // attach eth while doing an erc20 transfer
        vm.prank(MMAddress);
        vm.expectRevert("ERC20: msg.value must be 0");
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            dstAmount,
            fee,
            srcChainId
        );
    }

    function testFulfillmentFailsOnERCAmountZero() public {
        // the dst amount is zero
        vm.prank(MMAddress);
        vm.expectRevert("ERC20: Amount must be > 0");
        paymentRegistry.mostFulfillment{value: 0}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            0,
            fee,
            srcChainId
        );
    }

    function testSendingMoreERCThanInBalance() public {
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), 100 ether);
        vm.expectRevert();
        paymentRegistry.mostFulfillment{value: 0}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            100 ether,
            fee,
            srcChainId
        );
        vm.stopPrank();
    }

    function testRevertIfNotAllowedMM() public {
        vm.expectRevert("Caller is not the allowed MM");
        vm.deal(address(99), 99 ether);
        vm.prank(address(99));
        paymentRegistry.mostFulfillment{value: dstAmount}(
            orderId,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            fee,
            srcChainId
        );
    }
}
