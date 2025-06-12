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
        bytes32 isOrdersFulfillmentVerified;
        uint256 ordersWithdrawalsArrayLength;
        OrdersWithdrawal[] ordersWithdrawals;
    }

    function computeTaskOutputMerkleRoot(HDPTaskOutput memory taskOutput) internal pure returns (bytes32) {
        require(
            taskOutput.ordersWithdrawals.length == taskOutput.ordersWithdrawalsArrayLength,
            "HDPTaskOutput: length mismatch"
        );

        uint256 nLeaves = 2 + taskOutput.ordersWithdrawalsArrayLength;
        bytes32[] memory leaves = new bytes32[](nLeaves);

        leaves[0] = keccak256(abi.encode(taskOutput.isOrdersFulfillmentVerified));
        leaves[1] = keccak256(abi.encode(taskOutput.ordersWithdrawalsArrayLength));

        for (uint256 i = 0; i < taskOutput.ordersWithdrawals.length; ++i) {
            OrdersWithdrawal memory ordersWithdrawal = taskOutput.ordersWithdrawals[i];
            for (uint256 j = 0; i < ordersWithdrawal.balancesToWithdraw.length; ++j) {
                BalanceToWithdraw memory balanceToWithdraw = ordersWithdrawal.balancesToWithdraw[i];
                leaves[2 + i] = keccak256(abi.encode(balanceToWithdraw.tokenAddress, balanceToWithdraw.summarizedAmount));
            }
        }

        return computeMerkleRoot(leaves);
    }

    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32 root) {
        require(leaves.length > 0, "StandardMerkleTree: empty leaves");

        while (leaves.length > 1) {
            uint256 next = (leaves.length + 1) >> 1;
            bytes32[] memory level = new bytes32[](next);

            for (uint256 i = 0; i < leaves.length; i += 2) {
                bytes32 left = leaves[i];
                // duplicate last element if the level has odd length
                bytes32 right = i + 1 < leaves.length ? leaves[i + 1] : left;
                level[i >> 1] = _hashPair(left, right);
            }
            leaves = level;
        }
        root = leaves[0];
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a <= b ? keccak256(bytes.concat(a, b)) : keccak256(bytes.concat(b, a));
    }
}
