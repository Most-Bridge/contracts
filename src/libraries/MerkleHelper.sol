// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

library MerkleHelper {
        struct BalanceToWithdraw {
            address tokenAddress;
            uint256 summarizedAmount;
        }

        struct OrdersWithdrawal {
            address marketMakerAddress;
            BalanceToWithdraw[] balancesToWithdraw;
        }

        struct HDPTaskOutput {
            bool isOrdersFulfillmentVerified;
            uint256 lowestExpirationTimestamp;
            OrdersWithdrawal[] ordersWithdrawals;
        }

        bytes32 constant EMPTY_ROOT = 0x1d818f822942463614281e7a9e7836bc8a96ff9165d677b4f7126666112202b1;

        function computeHDPTaskOutputMerkleRoot(HDPTaskOutput memory taskOutput) public pure returns (bytes32) {
            // Total leaves count: 3 base leaves + 2 per withdrawal + 4 per balance.

            uint256 totalLeaves = 3;
            // Because of this depends how many times balancesToWithdraw array size will be defined
            // Because each MarketMaker have own balancesToWithdraw array
            totalLeaves += taskOutput.ordersWithdrawals.length;

            for (uint256 i = 0; i < taskOutput.ordersWithdrawals.length; ++i) {
                totalLeaves += 2; // marketMakerAddress (low & high)

                // Why 4 - contract address low and high, amount low and high
                totalLeaves += 4 * taskOutput.ordersWithdrawals[i].balancesToWithdraw.length;
            }

            uint256[] memory leaves = new uint256[](totalLeaves);
            uint256 index = 0;

            leaves[index++] = taskOutput.isOrdersFulfillmentVerified ? 1 : 0;

            // Lowest registered timestamp accross all orders in given batch
            leaves[index++] = taskOutput.lowestExpirationTimestamp;

            // Size of orders withdrawals for whole batch
            // the size of it depends of number of unique MMs in proving/withdrawal batch
            leaves[index++] = taskOutput.ordersWithdrawals.length;

            for (uint256 i = 0; i < taskOutput.ordersWithdrawals.length; ++i) {
                OrdersWithdrawal memory ordersWithdrawal = taskOutput.ordersWithdrawals[i];

                (uint256 mmaLow, uint256 mmaHigh) = splitAddress(ordersWithdrawal.marketMakerAddress);
                leaves[index++] = mmaLow;
                leaves[index++] = mmaHigh;

                // Size of balances to withdraw array for this market maker
                // the size of it depends of how many tokens are to withdraw for this MM
                leaves[index++] = ordersWithdrawal.balancesToWithdraw.length;

                for (uint256 j = 0; j < ordersWithdrawal.balancesToWithdraw.length; ++j) {
                    BalanceToWithdraw memory balanceToWithdraw = ordersWithdrawal.balancesToWithdraw[j];

                    (uint256 tokenLow, uint256 tokenHigh) = splitAddress(balanceToWithdraw.tokenAddress);
                    leaves[index++] = tokenLow;
                    leaves[index++] = tokenHigh;

                    uint256 low = uint128(balanceToWithdraw.summarizedAmount);
                    uint256 high = balanceToWithdraw.summarizedAmount >> 128;
                    leaves[index++] = low;
                    leaves[index++] = high;
                }
            }

            return computeMerkleRoot(leaves);
        }

        function computeMerkleRoot(uint256[] memory leaves) public pure returns (bytes32) {
            uint256 leaves_len = leaves.length;

            if (leaves_len == 0) {
                return EMPTY_ROOT;
            }

            if (leaves_len == 1) {
                return computeLeafHash(leaves[0]);
            }

            uint256 tree_len = 2 * leaves_len - 1;
            bytes32[] memory tree = new bytes32[](tree_len);


            for (uint256 i = 0; i < leaves_len; i++) {
                bytes32 leafHash = computeLeafHash(leaves[i]);
                uint256 store_idx = tree_len - 1 - i;
                tree[store_idx] = leafHash;
            }


            uint256 innerNodeStartIndex = tree_len - leaves_len - 1;
            for (uint256 i = innerNodeStartIndex; i < type(uint256).max; i--) {
                uint256 left_idx = i * 2 + 1;
                uint256 right_idx = i * 2 + 2;

                tree[i] = hashPair(tree[left_idx], tree[right_idx]);

                // Break the loop when we've computed the root at index 0.
                if (i == 0) {
                    break;
                }
            }

            return tree[0];
        }

        function computeLeafHash(uint256 leaf) internal pure returns (bytes32) {
            // Convert uint256 to little-endian bytes32.
            bytes32 leLeaf = reverseBytes32(bytes32(leaf));

            // Perform the double-Keccak256 hash.
            bytes32 firstHash = keccak256(abi.encodePacked(leLeaf));
            return keccak256(abi.encodePacked(firstHash));
        }

        function hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
            if (left < right) {
                return keccak256(abi.encodePacked(left, right));
            } else {
                return keccak256(abi.encodePacked(right, left));
            }
        }


        function reverseBytes32(bytes32 input) internal pure returns (bytes32 output) {
            assembly {
                for { let i := 0 } lt(i, 32) { i := add(i, 1) } {
                    let lastByte := and(input, 0xff)
                    output := shl(8, output)
                    output := or(output, lastByte)
                    input := shr(8, input)
                }
            }
        }

        function splitAddress(address addr) internal pure returns (uint256 low, uint256 high) {
            uint256 val = uint256(uint160(addr));
            low = uint128(val);
            high = val >> 128;
        }

}
