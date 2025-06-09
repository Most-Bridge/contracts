// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

library MerkleHelper {
    struct BalanceToWithdraw {
        address tokenAddress;
        uint256 summarizedAmount;
    }

    struct HDPTaskOutput {
        bytes32 isOrdersFulfillmentVerified;
        uint256 tokensBalancesArrayLength;
        BalanceToWithdraw[] tokensBalancesArray;
    }

    function computeTaskOutputMerkleRoot(HDPTaskOutput memory taskOutput) internal pure returns (bytes32) {
        require(
            taskOutput.tokensBalancesArray.length == taskOutput.tokensBalancesArrayLength,
            "HDPTaskOutput: length mismatch"
        );

        uint256 nLeaves = 2 + taskOutput.tokensBalancesArrayLength;
        bytes32[] memory leaves = new bytes32[](nLeaves);

        leaves[0] = keccak256(abi.encode(taskOutput.isOrdersFulfillmentVerified));
        leaves[1] = keccak256(abi.encode(taskOutput.tokensBalancesArrayLength));

        for (uint256 i = 0; i < taskOutput.tokensBalancesArray.length; ++i) {
            BalanceToWithdraw memory b = taskOutput.tokensBalancesArray[i];
            leaves[2 + i] = keccak256(abi.encode(b.tokenAddress, b.summarizedAmount));
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