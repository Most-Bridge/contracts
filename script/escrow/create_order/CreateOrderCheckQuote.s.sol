// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {HookExecutor} from "src/contracts/HookExecutor.sol";

contract CreateOrder is Script {
    function run() external {
        vm.startBroadcast();

        // Escrow contract address
        address escrowAddress = 0x40b4e42e300f141DF8b1163A3bdC22AEbeCCdCF9;
        Escrow escrow = Escrow(payable(escrowAddress));

        // === Order Parameters (FROM API RESPONSE) ===
        bytes32 usrDstAddress = bytes32(uint256(uint160(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8))); // Updated to your address

        address srcToken = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003; // WLD on Worldchain
        uint256 srcAmount = 100000000000000000; // 0.1 WLD in wei

        // Convert destination token address to bytes32 (Optimism USDC)
        bytes32 dstToken = bytes32(uint256(uint160(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85))); // USDC on Optimism

        // Use calculated destination amount from API (after bridge fee)
        // API returned: "0.10550912400000001" USDC
        // Convert to USDC units (6 decimals): 0.105509 * 10^6 = 105509
        uint256 dstAmount = 105509; // Calculated destination amount in USDC units

        // Convert chain ID to bytes32 (Optimism = 10)
        bytes32 dstChainId = bytes32(uint256(10)); // Optimism mainnet

        uint256 expiryWindow = 86400; // 1 day

        address expectedOutToken = 0x79A02482A880bCE3F13e09Da970dC34db4CD24d1; // USDC on Worldchain

        // Use hookExecutorSalt from API response (note: API returned "0xfe" not "0x01a4")
        bytes32 hookExecutorSalt = bytes32(uint256(0xfe)); // From API response

        // === Hook parameters (FROM API RESPONSE) ===
        // Hook 1: Permit2 Approval
        address approveHookTarget = 0x000000000022D473030F116dDEE9F6B43aC78BA3; //
        bytes memory approveHookCallData =
            hex"87517c450000000000000000000000002cfc85d8e48f8eab294be644d9e25c30308630030000000000000000000000008ac7bee993bb44dab564ea4bc9ea67bf9eb5e743000000000000000000000000000000000013426172c74d822b878fe800000000000000000000000000000000000000000000000000000000000000006fa05a28"; // From API

        // Hook 2: Universal Router Swap
        address swapHookTarget = 0x8ac7bEE993bb44dAb564Ea4bc9EA67Bf9Eb5e743; //
        bytes memory swapHookCallData =
            hex"3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000688a6be50000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000012000000000000000000000000060b94f5e1f88b6ccb8976d93439ceddc6bdc6577000000000000000000000000000000000013426172c74d822b878fe800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000422cfc85d8e48f8eab294be644d9e25c3030863003000bb84200000000000000000000000000000000000006000bb879a02482a880bce3f13e09da970dc34db4cd24d1000000000000000000000000000000000000000000000000000000000000"; // From API

        // Create hooks array with API data
        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](2);
        hooks[0] = HookExecutor.Hook({target: approveHookTarget, callData: approveHookCallData});
        hooks[1] = HookExecutor.Hook({target: swapHookTarget, callData: swapHookCallData});

        // === Call the swapAndCreateOrder function ===
        escrow.swapAndCreateOrder(
            usrDstAddress,
            srcToken,
            srcAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            expectedOutToken,
            hookExecutorSalt,
            hooks
        );

        vm.stopBroadcast();
    }
}

// forge script script/escrow/create_order/CreateOrderCheckQuote.s.sol:CreateOrder \
//   --rpc-url $WLD_MAINNET_RPC \
//   --broadcast \
//   --private-key $DEPLOY_PRIVATE_KEY
