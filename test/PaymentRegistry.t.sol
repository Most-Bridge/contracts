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

    MockERC20 public mockERC;

    address MMAddress = address(3);
    bytes32 mmSrcAddress = bytes32(uint256(4));

    function setUp() public {
        paymentRegistry = new PaymentRegistry();
        vm.deal(MMAddress, 10 ether);
        vm.deal(userDstAddress, 1 ether);
        vm.prank(address(this));

        // deploy mock ERC20 token and mint it to MM
        mockERC = new MockERC20("MockToken", "MOCK");
        mockERC.mint(MMAddress, 10 ether);
    }

    /// @dev Creates a customizable array of orders for testing.
    function _createOrdersArray(
        address _dstToken,
        uint256 _dstAmount,
        address _usrDstAddress,
        uint256 _expirationTimestamp
    ) internal view returns (PaymentRegistry.OrderFulfillmentData[] memory) {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](1);
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            usrSrcAddress: userSrcAddress,
            usrDstAddress: _usrDstAddress,
            expirationTimestamp: _expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount,
            dstToken: _dstToken,
            dstAmount: _dstAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress
        });
        return orders;
    }

    /// @dev Creates a default ETH order array.
    function _createDefaultEthOrdersArray() internal view returns (PaymentRegistry.OrderFulfillmentData[] memory) {
        return _createOrdersArray(dstTokenETH, dstAmount, userDstAddress, expirationTimestamp);
    }

    /// @dev Creates a default ERC20 order array.
    function _createDefaultErc20OrdersArray(uint256 _dstAmount)
        internal
        view
        returns (PaymentRegistry.OrderFulfillmentData[] memory)
    {
        return _createOrdersArray(address(mockERC), _dstAmount, userDstAddress, expirationTimestamp);
    }

    function testFulfillmentSuccess() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(MMAddress); // mm calls
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
        assertEq(address(MMAddress).balance, 9.1 ether, "MM balance did not decrease.");
    }

    function testFulfillmentFailsIfAlreadyProcessed() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.startPrank(MMAddress);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);

        vm.expectRevert("Transfer already processed");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
        vm.stopPrank();
    }

    function testFulfillmentFailsIfNoValue() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testFulfillmentFailsIfWrongValue() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, dstAmount + 1 ether, userDstAddress, expirationTimestamp);
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testFulfillmentFailsOnExpiredOrder() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultEthOrdersArray();
        vm.prank(MMAddress);
        vm.expectRevert("Cannot fulfill an expired order.");
        // warping time to expire order
        vm.warp(block.timestamp + 2 days);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testMMSendsMoreThanBalance() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, 20 ether, userDstAddress, expirationTimestamp);
        vm.prank(MMAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 20 ether}(orders);
    }

    function testFulfillmentPassesOnERC20() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        // send a good erc20 transfer
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(MMAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
    }

    function testFulfillmentFailsOnEthSentOnERC20() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        // attach eth while doing an erc20 transfer
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), dstAmount);
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
        vm.stopPrank();

        assertEq(mockERC.balanceOf(userDstAddress), dstAmount, "User destination did not receive ERC20 tokens");
        assertEq(mockERC.balanceOf(MMAddress), 10 ether - dstAmount, "MM ERC20 balance did not decrease correctly");
        assertEq(address(paymentRegistry).balance, dstAmount, "PaymentRegistry should have received the ETH");
    }

    function testFulfillmentFailsOnERCAmountZero() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(0);
        // the dst amount is zero
        vm.prank(MMAddress);
        vm.expectRevert("ERC20: Amount must be > 0");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testSendingMoreERCThanInBalance() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(100 ether);
        vm.startPrank(MMAddress);
        mockERC.approve(address(paymentRegistry), 100 ether);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();
    }

    function testRevertTransferToNonPayableContract() public {
        // Deploy a contract that cannot receive ETH
        NonPayableReceiver nonPayable = new NonPayableReceiver();
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, dstAmount, address(nonPayable), expirationTimestamp);
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Transfer failed");
        paymentRegistry.mostFulfillOrders{value: dstAmount}(orders);
    }

    function testERC20FailsWithoutApproval() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = _createDefaultErc20OrdersArray(dstAmount);
        vm.prank(MMAddress);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testRevertTransferWithBrokenERC20() public {
        BrokenERC20 broken = new BrokenERC20("FailToken", "FAIL");
        broken.mint(MMAddress, 10 ether);

        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(address(broken), dstAmount, userDstAddress, expirationTimestamp);
        vm.startPrank(MMAddress);
        broken.approve(address(paymentRegistry), dstAmount);
        vm.expectRevert();
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
        vm.stopPrank();
    }

    function testFulfillmentFailsOnEthAmountZero() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders =
            _createOrdersArray(dstTokenETH, 0, userDstAddress, expirationTimestamp);
        vm.prank(MMAddress);
        vm.expectRevert("Native ETH: Amount must be > 0");
        paymentRegistry.mostFulfillOrders{value: 0}(orders);
    }

    function testFulfillmentOnTwoOrders() public {
        PaymentRegistry.OrderFulfillmentData[] memory orders = new PaymentRegistry.OrderFulfillmentData[](2);

        // First order - standard ETH transfer
        orders[0] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId,
            srcEscrow: srcEscrow,
            usrSrcAddress: userSrcAddress,
            usrDstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount,
            dstToken: dstTokenETH,
            dstAmount: dstAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress
        });

        // Second order - different orderId and amount
        uint256 secondOrderAmount = dstAmount / 2;
        orders[1] = PaymentRegistry.OrderFulfillmentData({
            orderId: orderId + 1,
            srcEscrow: srcEscrow,
            usrSrcAddress: userSrcAddress,
            usrDstAddress: userDstAddress,
            expirationTimestamp: expirationTimestamp,
            srcToken: srcToken,
            srcAmount: srcAmount / 2,
            dstToken: dstTokenETH,
            dstAmount: secondOrderAmount,
            srcChainId: srcChainId,
            marketMakerSourceAddress: mmSrcAddress
        });

        uint256 totalEthRequired = dstAmount + secondOrderAmount;
        vm.prank(MMAddress);
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
        assertEq(address(MMAddress).balance, expectedMMBalance, "MM balance did not decrease correctly.");
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
