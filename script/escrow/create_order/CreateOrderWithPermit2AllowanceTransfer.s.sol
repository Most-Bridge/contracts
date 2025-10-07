// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Escrow} from "src/contracts/Escrow.sol";

/// Minimal Permit2 Allowance interface
interface IPermit2Allowance {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
    function allowance(address user, address token, address spender)
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce);
}

contract CreateOrderWithPermit2AllowanceTransfer is Script {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function _loadPk(string memory varName) internal view returns (uint256) {
        string memory raw = vm.envString(varName);
        if (!(bytes(raw).length >= 2 && bytes(raw)[0] == "0" && (bytes(raw)[1] == "x" || bytes(raw)[1] == "X"))) {
            require(bytes(raw).length == 64, "private key must be 64 hex chars (no 0x)");
            raw = string.concat("0x", raw);
        }
        return uint256(vm.parseBytes32(raw));
    }

    function _ensureERC20Approval(address owner, address token, uint256 minAmount) internal {
        uint256 current = IERC20(token).allowance(owner, PERMIT2);
        if (current < minAmount) {
            console2.log("Approving ERC20 -> Permit2");
            // Some tokens require setting to 0 before increasing
            try IERC20(token).approve(PERMIT2, 0) {} catch {}
            require(IERC20(token).approve(PERMIT2, type(uint256).max), "ERC20 approve to Permit2 failed");
        }
    }

    function _ensurePermit2Allowance(address owner, address token, address spender, uint256 minAmount) internal {
        (uint160 amount, uint48 expiration,) = IPermit2Allowance(PERMIT2).allowance(owner, token, spender);
        bool expired = expiration != 0 && expiration < block.timestamp;
        if (amount < uint160(minAmount) || expired) {
            console2.log("Setting Permit2 allowance for Escrow");
            // set a generous expiration (1 year)
            uint48 newExpiration = uint48(block.timestamp + 365 days);
            IPermit2Allowance(PERMIT2).approve(token, spender, type(uint160).max, newExpiration);
        }
    }

    function run() external {
        uint256 pk = _loadPk("DEPLOY_PRIVATE_KEY");
        vm.startBroadcast(pk);

        address owner = vm.addr(pk);

        // --- Configure your deployment params here ---
        address payable escrowAddr = payable(0xB6eff915c83A5061Af9DF4915E9C31cB0c041026); // Escrow
        Escrow escrow = Escrow(escrowAddr);

        // Order params (example values aligned with existing scripts)
        bytes32 usrDstAddress = bytes32(uint256(uint160(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8)));
        address srcToken = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003; // WLD on World Chain
        uint256 srcAmount = 1_000_000_000_000_000; // 0.001 WLD
        bytes32 dstToken = bytes32(uint256(uint160(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85))); // OP USDC
        uint256 dstAmount = 105_509; // example
        bytes32 dstChainId = bytes32(uint256(10)); // Optimism
        uint256 expiryWindow = 7 days;

        // --- Preflight ---
        require(IERC20(srcToken).balanceOf(owner) >= srcAmount, "Insufficient balance");

        // 1) Ensure ERC20 approval from user to Permit2
        _ensureERC20Approval(owner, srcToken, srcAmount);

        // 2) Ensure Permit2 allowance from user to Escrow for this token
        _ensurePermit2Allowance(owner, srcToken, escrowAddr, srcAmount);

        // 3) Call Escrow to create order via Permit2 AllowanceTransfer
        escrow.createOrderWithPermit2AllowanceTransfer(
            usrDstAddress, srcToken, srcAmount, dstToken, dstAmount, dstChainId, expiryWindow
        );

        vm.stopBroadcast();
    }
}

// forge script script/escrow/create_order/CreateOrderWithPermit2AllowanceTransfer.s.sol:CreateOrderWithPermit2AllowanceTransfer \
//   --rpc-url $WLD_MAINNET_RPC \
//   --broadcast \
//   --private-key $DEPLOY_PRIVATE_KEY
