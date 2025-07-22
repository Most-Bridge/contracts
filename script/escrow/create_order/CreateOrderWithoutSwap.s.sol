// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {HookExecutor} from "src/contracts/HookExecutor.sol";

contract CreateOrderWithoutSwap is Script {
    function run() external {
        vm.startBroadcast();

        // Escrow contract address
        address escrowAddress = 0x392A4B03AD7048557469f4DF7dB5706Ed2B33704;
        Escrow escrow = Escrow(payable(escrowAddress));

        // === Order Parameters ===
        bytes32 usrDstAddress = bytes32(uint256(uint160(0xe727dbADBB18c998e5DeE2faE72cBCFfF2e6d03D))); // DST_ADDRESS

        address srcToken = 0x0000000000000000000000000000000000000000; // Native ETH
        uint256 srcAmount = 0.001 ether; // Amount of coins, if input token has 1 decomals it will work

        bytes32 dstToken = bytes32(uint256(0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7));
        uint256 dstAmount = 0.000001 ether; // USDC

        bytes32 dstChainId = bytes32(uint256(0x534e5f5345504f4c4941)); // "SN_SEPOLIA"
        uint256 expiryWindow = 86400; // 1 day

        bool useSwap = false;
        address expectedOutToken = 0x0000000000000000000000000000000000000000; // If no swap - empty
        bytes32 hookExecutorSalt = bytes32(uint256(0x0)); // If not swap - empty - not needed

        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](0);

        // === Call the function ===
        escrow.createOrder{value: srcAmount}(
            usrDstAddress,
            srcToken,
            srcAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            useSwap,
            expectedOutToken,
            hookExecutorSalt,
            hooks
        );

        vm.stopBroadcast();
    }
}

// forge script script/escrow/create_order/CreateOrder.s.sol:CreateOrder \
//   --rpc-url $ETH_SEPOLIA_RPC \
//   --broadcast \
//   --private-key $USR_SRC_PRIVATE_KEY
