// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {PaymentRegistry} from "src/contracts/PaymentRegistry2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PaymentRegistry2Test is Test {
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

    MockERC20 public mockERC;

    address mmAddress = address(3);
    bytes32 mmSrcAddress = bytes32(uint256(4));

    address emptyMMAddress = address(0);
    bytes32 emptyMMBytes = 0x0000000000000000000000000000000000000000000000000000000000000000;
    address maliciousMMAddress = address(5);

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(mmAddress, 10 ether);
        vm.deal(userDstAddress, 1 ether);
        vm.deal(maliciousMMAddress, 10 ether);
        vm.prank(address(this));

        // deploy mock ERC20 token and mint it to MM
        mockERC = new MockERC20("MockToken", "MOCK");
        mockERC.mint(mmAddress, 10 ether);
    }

    /// @dev Creates a customizable array of orders for testing.
    function _createOrdersArray(
        address _dstToken,
        uint256 _dstAmount,
        uint256 _fulfillmentAmount,
        address _dstAddress,
        uint256 _expirationTimestamp
    ) internal view returns (PaymentRegistry.OrderFulfillmentData[] memory) {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](1);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: _dstAddress,
            expirationTimestamp: _expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: _fulfillmentAmount
        });
        return orders;
    }

    /// @dev Creates a default ETH order array.
    function _createDefaultEthOrdersArray() internal view returns (PaymentRegistry.OrderFulfillmentData[] memory) {
        return _createOrdersArray(dstTokenETH, dstAmount, dstAmount, userDstAddress, expirationTimestamp);
    }

    /// @dev Creates a default ERC20 order array.
    function _createDefaultErc20OrdersArray(uint256 _dstAmount)
        internal
        view
        returns (PaymentRegistry.OrderFulfillmentData[] memory)
    {
        return _createOrdersArray(address(mockERC), _dstAmount, _dstAmount, userDstAddress, expirationTimestamp);
    }

    function testFulfillmentSuccess() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(mmAddress); // mm calls
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);

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
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), mmSrcAddress, "Order was not marked as processed.");
        assertEq(address(userDstAddress).balance, 1.9 ether, "User destination address balance did not increase.");
        assertEq(address(mmAddress).balance, 9.1 ether, "MM balance did not decrease.");
    }

    function testFulfillmentFailsIfAlreadyProcessed() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.startPrank(mmAddress);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);

        vm.expectRevert("Order already fully fulfilled");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
        vm.stopPrank();
    }

    function testFulfillmentFailsIfNoValue() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(mmAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testFulfillmentFailsIfWrongValue() public {
        // Increase order dstAmount and fulfillmentAmount by 1 ether, but send only dstAmount
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createOrdersArray(
            dstTokenETH, dstAmount + 1 ether, dstAmount + 1 ether, userDstAddress, expirationTimestamp
        );
        vm.prank(mmAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testFulfillmentFailsOnExpiredOrder() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(mmAddress);
        vm.expectRevert("Cannot fulfill an expired order.");
        // warping time to expire order
        vm.warp(block.timestamp + 2 days);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testMMFulfillsWithLowerBalance() public {
        // 10 ether order
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, 10 ether, 10 ether, userDstAddress, expirationTimestamp);

        vm.prank(mmAddress);
        assertEq(address(mmAddress).balance, 10 ether, "MM should have 10 ether");

        // try to fulfill with 5 ether, then contract will try to send 10 to the user, and thus fail
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: 5 ether}(orders);
    }

    function testFulfillmentPassesOnERC20() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        // send a good erc20 transfer
        vm.startPrank(mmAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(mmAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
    }

    function testFulfillmentPassesWithEthSentOnERC20() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        // attach eth while doing an erc20 transfer
        vm.startPrank(mmAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(mmAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
        assertEq(address(paymentRegistry).balance, dstAmount, "PaymentRegistry should have received the ETH");
    }

    function testFulfillmentFailsOnERCAmountZero() public {
        // dstAmount = 0 and fulfillmentAmount = 0 triggers amount > 0 check
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(address(mockERC), 0, 0, userDstAddress, expirationTimestamp);
        vm.prank(mmAddress);
        vm.expectRevert("Fulfillment: amount must be > 0");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testSendingMoreERCThanInBalance() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(100 ether);
        vm.startPrank(mmAddress);
        mockERC.approve(address(paymentRegistry), 100 ether);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();
    }

    function testRevertTransferToNonPayableContract() public {
        // Deploy a contract that cannot receive ETH
        NonPayableReceiver nonPayable = new NonPayableReceiver();
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, dstAmount, dstAmount, address(nonPayable), expirationTimestamp);
        vm.prank(mmAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testERC20FailsWithoutApproval() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        vm.prank(mmAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testRevertTransferWithBrokenERC20() public {
        BrokenERC20 broken = new BrokenERC20("FailToken", "FAIL");
        broken.mint(mmAddress, 10 ether);

        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(address(broken), dstAmount, dstAmount, userDstAddress, expirationTimestamp);
        vm.startPrank(mmAddress);
        broken.approve(address(paymentRegistry), dstAmount);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();
    }

    function testFulfillmentFailsOnEthAmountZero() public {
        // dstAmount = 0 and fulfillmentAmount = 0 triggers amount > 0 check
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, 0, 0, userDstAddress, expirationTimestamp);
        vm.prank(mmAddress);
        vm.expectRevert("Fulfillment: amount must be > 0");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testFulfillmentOnTwoOrders() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](2);

        // First order - standard ETH transfer
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount,
            dstToken: dstTokenETH,
            dstAmount: dstAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: dstAmount
        });

        // Second order - different orderId and amount
        uint256 secondOrderAmount = dstAmount / 2;
        orders[1] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId + 1,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount / 2,
            dstToken: dstTokenETH,
            dstAmount: secondOrderAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: secondOrderAmount
        });

        uint256 totalEthRequired = dstAmount + secondOrderAmount;
        vm.prank(mmAddress);
        paymentRegistry.mostFulfillOrders{value: totalEthRequired}(orders);

        // Verify first order hash
        bytes32 orderHash1 = keccak256(
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
                block.chainid
            )
        );

        // Verify second order hash
        bytes32 orderHash2 = keccak256(
            abi.encode(
                orderId + 1,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                srcAmount / 2,
                dstTokenETH,
                secondOrderAmount,
                srcChainId,
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash1), mmSrcAddress, "First order was not marked as processed.");
        assertEq(paymentRegistry.fulfillments(orderHash2), mmSrcAddress, "Second order was not marked as processed.");

        // Verify user received the total amount
        uint256 expectedUserBalance = 1 ether + totalEthRequired; // initial 1 ether + both transfers
        assertEq(address(userDstAddress).balance, expectedUserBalance, "User did not receive correct total amount.");

        // Verify MM balance decreased correctly
        uint256 expectedMMBalance = 10 ether - totalEthRequired;
        assertEq(address(mmAddress).balance, expectedMMBalance, "MM balance did not decrease correctly.");
    }

    // 1. full fulfillment goes through and there is is a entry in the fulfillments mapping, and not in the partials mapping
    function testFullFulfillment() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(mmAddress);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);

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
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), mmSrcAddress, "Order was not marked as processed.");
        assertEq(paymentRegistry.partialFillBalance(orderHash), 0, "Partial fill balance was not cleared");
        assertEq(paymentRegistry.lockPartialFillTo(orderHash), emptyMMAddress, "MM source address was not cleared");
    }
    // 2. partial fulfillment, first time, check that the fulfillments mapping is empty, and that the partials mapping has the partial amount saved, and that the MMSrc address is saved also

    function testPartialFulfillment1of3() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](1);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        vm.prank(mmAddress);
        // first time, fulfill 1/3 of the order
        paymentRegistry.mostFulfillOrders{value: 0.1 ether}(orders);

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                0.4 ether,
                dstTokenETH,
                0.3 ether,
                srcChainId,
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), emptyMMBytes, "Order was not marked as processed.");
        assertEq(paymentRegistry.partialFillBalance(orderHash), 0.1 ether, "Partial fill balance was not saved");
        assertEq(paymentRegistry.lockPartialFillTo(orderHash), mmAddress, "MM source address was not saved");
    }
    // 3. they fulfill 2/3 of the way, the full fullfillments is still empty, and the rest is as it should be

    function testPartialFulfillment2of3() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](2);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        orders[1] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        vm.prank(mmAddress);
        // first time, fulfill 1/3 of the order
        paymentRegistry.mostFulfillOrders{value: 0.2 ether}(orders);

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                0.4 ether,
                dstTokenETH,
                0.3 ether,
                srcChainId,
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), emptyMMBytes, "Order was not marked as processed.");
        assertEq(paymentRegistry.partialFillBalance(orderHash), 0.2 ether, "Partial fill balance was not saved");
        assertEq(paymentRegistry.lockPartialFillTo(orderHash), mmAddress, "MM source address was not saved");
    }
    // 4. they did 3/3 fulfillments and now the fullfilments mapping should have the MM address registered, therefore the order has been fully fulfilled.

    function testFullFulfillment3of3() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](3);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        orders[1] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        orders[2] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        vm.prank(mmAddress);
        // first time, fulfill 1/3 of the order
        paymentRegistry.mostFulfillOrders{value: 0.3 ether}(orders);

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                0.4 ether,
                dstTokenETH,
                0.3 ether,
                srcChainId,
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), mmSrcAddress, "Order was not marked as processed.");
        assertEq(paymentRegistry.partialFillBalance(orderHash), 0, "Partial fill balance was not saved");
        assertEq(paymentRegistry.lockPartialFillTo(orderHash), emptyMMAddress, "MM source address was not saved");
    }
    // 5. one mm does the first fulfillment, then another one tries to fulfill the rest of the amount

    function testPartialFulfillment1of3ByAnotherMM() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](1);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });
        vm.prank(mmAddress);
        // first time, fulfill 1/3 of the order
        paymentRegistry.mostFulfillOrders{value: 0.1 ether}(orders);

        bytes32 orderHash = keccak256(
            abi.encode(
                orderId,
                srcEscrow,
                userSrcAddress,
                userDstAddress,
                expirationTimestamp,
                srcToken,
                0.4 ether,
                dstTokenETH,
                0.3 ether,
                srcChainId,
                block.chainid
            )
        );

        assertEq(paymentRegistry.fulfillments(orderHash), emptyMMBytes, "Order was not marked as processed.");
        assertEq(paymentRegistry.partialFillBalance(orderHash), 0.1 ether, "Partial fill balance was not saved");
        assertEq(paymentRegistry.lockPartialFillTo(orderHash), mmAddress, "MM source address was not saved");

        PaymentRegistry.OrderFulfillmentData[] memory maliciousOrders = new PaymentRegistry.OrderFulfillmentData[](1);
        maliciousOrders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            srcAddress: userSrcAddress,
            dstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: 0.4 ether,
            dstToken: dstTokenETH,
            dstAmount: 0.3 ether,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress,
            fulfillmentAmount: 0.1 ether
        });

        // malicious tries to fulfill the rest of the amount
        vm.prank(maliciousMMAddress);
        vm.expectRevert("Fulfillment: different MM");
        paymentRegistry.mostFulfillOrders{value: 0.1 ether}(maliciousOrders);
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
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

contract NonPayableReceiver {
// No receive() or fallback() function — can't receive ETH
}
