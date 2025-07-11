// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEscrow {
    function onExecutorReturn(bytes32 swapId, address swappedToken, uint256 swappedAmount) external;
}

contract HookExecutor {
    using SafeERC20 for IERC20;

    struct Hook {
        address target;
        bytes callData;
    }

    error HookFailed();

    error ZeroOutputTokens();

    function execute(bytes32 swapId, Hook[] calldata hooks, address tokenIn, address tokenOut, address escrow)
        external
    {
        // approve spending
        uint256 balanceIn = IERC20(tokenIn).balanceOf(address(this));

        for (uint256 i = 0; i < hooks.length; i++) {
            IERC20(tokenIn).approve(hooks[i].target, balanceIn);
        }

        // execute hooks
        for (uint256 i = 0; i < hooks.length; i++) {
            (bool success,) = hooks[i].target.call(hooks[i].callData);
            if (!success) {
                revert HookFailed();
            }
        }

        uint256 balanceOut = IERC20(tokenOut).balanceOf(address(this));
        if (balanceOut == 0) {
            revert ZeroOutputTokens();
        }

        // transfer output tokens to escrow
        IERC20(tokenOut).safeTransfer(escrow, balanceOut);

        // notify escrow
        IEscrow(escrow).onExecutorReturn(swapId, tokenOut, balanceOut);

        selfdestruct(payable(escrow));
    }
}
