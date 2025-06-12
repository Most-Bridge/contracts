// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "src/contracts/PaymentRegistry.sol";
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
    bytes32 srcChainId = bytes32(uint256(2));
    bytes32 srcEscrow = bytes32(uint256(3));
    bytes32 constant DST_CHAIN_ID = 0x0000000000000000000000000000000000000000000000000000000000000001;

    MockERC20 public mockERC;

    address MMAddress = address(3);
    bytes32 mmSrcAddress = bytes32(uint256(4));

    function setUp() public {
        paymentRegistry = new PaymentRegistry(DST_CHAIN_ID, MMAddress);
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
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                srcAmount,
                dstTokenETH,
                dstAmount,
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
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );

        vm.expectRevert("Transfer already processed");
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
        vm.stopPrank();
    }

    function testFulfillmentFailsIfNoValue() public {
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: msg.value mismatch with destination amount");
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testFulfillmentFailsIfWrongValue() public {
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: msg.value mismatch with destination amount");
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount + 1 ether,
            srcChainId,
            mmSrcAddress
        );
    }

    function testFulfillmentFailsOnExpiredOrder() public {
        vm.prank(MMAddress);
        vm.expectRevert("Cannot fulfill an expired order.");
        // warping time to expire order
        vm.warp(block.timestamp + 2 days);
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testMMSendsMoreThanBalance() public {
        vm.prank(MMAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrder{value: 20 ether}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testFulfillmentPassesOnERC20() public {
        // send a good erc20 transfer
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(MMAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
    }

    function testFulfillmentFailsOnEthSentOnERC20() public {
        // attach eth while doing an erc20 transfer
        vm.prank(MMAddress);
        vm.expectRevert("ERC20: msg.value must be 0");
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testFulfillmentFailsOnERCAmountZero() public {
        // the dst amount is zero
        vm.prank(MMAddress);
        vm.expectRevert("ERC20: Amount must be > 0");
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            0,
            srcChainId,
            mmSrcAddress
        );
    }

    function testSendingMoreERCThanInBalance() public {
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), 100 ether);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            100 ether,
            srcChainId,
            mmSrcAddress
        );
        vm.stopPrank();
    }

    function testRevertIfNotAllowedMM() public {
        vm.expectRevert("Caller is not the allowed MM");
        vm.deal(address(99), 99 ether);
        vm.prank(address(99));
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testRevertTransferToNonPayableContract() public {
        // Deploy a contract that cannot receive ETH
        NonPayableReceiver nonPayable = new NonPayableReceiver();
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrder{value: dstAmount}(
            orderId,
            srcEscrow,
            userSrcAddress,
            address(nonPayable),
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testERC20FailsWithoutApproval() public {
        vm.prank(MMAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(mockERC),
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
    }

    function testRevertTransferWithBrokenERC20() public {
        BrokenERC20 broken = new BrokenERC20("FailToken", "FAIL");
        broken.mint(MMAddress, 10 ether);

        vm.startPrank(MMAddress);
        broken.approve(address(paymentRegistry), dstAmount);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            address(broken),
            dstAmount,
            srcChainId,
            mmSrcAddress
        );
        vm.stopPrank();
    }

    function testFulfillmentFailsOnEthAmountZero() public {
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Amount must be > 0");
        paymentRegistry.mostFulfillOrder{value: 0}(
            orderId,
            srcEscrow,
            userSrcAddress,
            userDstAddress,
            expirationTimestamp,
            srcToken,
            srcAmount,
            dstTokenETH,
            0, // dstAmount = 0
            srcChainId,
            mmSrcAddress
        );
    }
}

contract NonPayableReceiver {
// No receive() or fallback() function — can't receive ETH
}

contract BrokenERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("Broken ERC20: transferFrom always fails");
    }
}
