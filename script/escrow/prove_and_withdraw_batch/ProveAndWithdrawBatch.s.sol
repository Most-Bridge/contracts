// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {MerkleHelper} from "src/libraries/MerkleHelper.sol";
import "forge-std/console.sol";

contract ProveAndWithdrawBatch is Script {
    function run() external {
        vm.startBroadcast();

        address escrowAddress = 0x392A4B03AD7048557469f4DF7dB5706Ed2B33704;
        Escrow escrow = Escrow(payable(escrowAddress));

        // Parameters for the proveAndWithdrawBatch function
        bytes32[] memory ordersHashes = new bytes32[](1);
        ordersHashes[0] = 0x72c42dbbc85bd0969aeac8080206c955e58fc8fab1b0180bd64d49de8ca112a3;
        uint256 blockNumber = 923027;
        bytes32 destinationChainId = bytes32(uint256(0x534e5f5345504f4c4941));
        uint256 lowestExpirationTimestamp = 1760639640;

        MerkleHelper.OrdersWithdrawal[] memory ordersWithdrawals = new MerkleHelper.OrdersWithdrawal[](1);
        MerkleHelper.BalanceToWithdraw[] memory balancesMarketMaker1 = new MerkleHelper.BalanceToWithdraw[](1);

        balancesMarketMaker1[0] = MerkleHelper.BalanceToWithdraw({
                    tokenAddress: address(0x0000000000000000000000000000000000000000),
                    summarizedAmount: 1000000000
                });

        ordersWithdrawals[0] =
            MerkleHelper.OrdersWithdrawal({
                marketMakerAddress: address(0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6),
                balancesToWithdraw: balancesMarketMaker1
            });

        // Call the proveAndWithdrawBatch function
        escrow.proveAndWithdrawBatch(
            ordersHashes, blockNumber, destinationChainId, lowestExpirationTimestamp, ordersWithdrawals
        );

        vm.stopBroadcast();

    }
}
