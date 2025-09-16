// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HookExecutor} from "src/contracts/HookExecutor.sol";
import {Escrow, ISignatureTransferP2} from "src/contracts/Escrow.sol";

// ---- Minimal Permit2 view ----
interface IPermit2 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonceBitmap(address owner, uint256 word) external view returns (uint256);
}

contract SwapAndCreateOrderWithPermit2 is Script {
    // --- constants ---
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // EIP-712 typehashes (SignatureTransfer v1)
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)"
        "TokenPermissions(address token,uint256 amount)"
    );

    // --- helpers ---
    function _domainSeparator() private view returns (bytes32) {
        return IPermit2(PERMIT2).DOMAIN_SEPARATOR();
    }

    function _hashTokenPermissions(address token, uint256 amount) private pure returns (bytes32) {
        return keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, amount));
    }

    function _hashPermitTransferFrom(ISignatureTransferP2.PermitTransferFrom memory permit, address spender)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PERMIT_TRANSFER_FROM_TYPEHASH,
                _hashTokenPermissions(permit.permitted.token, permit.permitted.amount),
                spender,
                permit.nonce,
                permit.deadline
            )
        );
    }

    function _buildDigest(ISignatureTransferP2.PermitTransferFrom memory permit, address spender)
        private
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), _hashPermitTransferFrom(permit, spender)));
    }

    function _loadPk(string memory varName) internal view returns (uint256) {
        string memory raw = vm.envString(varName);
        // allow with or without 0x
        if (!(bytes(raw).length >= 2 && bytes(raw)[0] == "0" && (bytes(raw)[1] == "x" || bytes(raw)[1] == "X"))) {
            require(bytes(raw).length == 64, "private key must be 64 hex chars (no 0x)");
            raw = string.concat("0x", raw);
        }
        return uint256(vm.parseBytes32(raw));
    }

    /// pick first free nonce bit in word 0 (matches Permit2 canonical encoding: (word<<8)|bit)
    function _pickNonce(address owner) internal view returns (uint256 nonce) {
        uint256 word = 0;
        uint256 bitmap = IPermit2(PERMIT2).nonceBitmap(owner, word);
        for (uint256 bit = 0; bit < 256; bit++) {
            if ((bitmap & (1 << bit)) == 0) {
                return (word << 8) | bit;
            }
        }
        revert("all nonce bits in word 0 used");
    }

    function run() external {
        uint256 pk = _loadPk("DEPLOY_PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Escrow + user
        address payable escrowAddr = payable(0x52702Ce4198e2278DC7c215362F22713A7a5fFc3); // <-- YOUR ESCROW
        Escrow escrow = Escrow(escrowAddr);
        address owner = vm.addr(pk);

        // ---- Order params
        bytes32 usrDstAddress = bytes32(uint256(uint160(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8)));
        address srcToken = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003; // WLD on World Chain
        uint256 srcAmount = 1_000_000_000_000_000; // 0.001 WLD (wei)
        bytes32 dstToken = bytes32(uint256(uint160(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85))); // OP USDC
        uint256 dstAmount = 1_000_000; // example: 0.100000 USDC (6dp)
        bytes32 dstChainId = bytes32(uint256(10)); // Optimism chain id
        uint256 expiryWindow = 7 days;

        address expectedOutToken = 0x79A02482A880bCE3F13e09Da970dC34db4CD24d1; // USDC on World Chain (executor's tokenOut)
        bytes32 hookExecutorSalt = bytes32(uint256(0x01a4)); // MUST match API's assumption

        HookExecutor.Hook[] memory hooks = new HookExecutor.Hook[](2);

        // Hook 1: Permit2.approve (executor -> router)
        hooks[0] = HookExecutor.Hook({
            target: 0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
            callData: hex"87517c450000000000000000000000002cfc85d8e48f8eab294be644d9e25c30308630030000000000000000000000008ac7bee993bb44dab564ea4bc9ea67bf9eb5e74300000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000006fa05a28"
        });

        // Hook 2: Universal Router swap (recipient MUST be the CREATE2 HookExecutor address)
        hooks[1] = HookExecutor.Hook({
            target: 0x8ac7bEE993bb44dAb564Ea4bc9EA67Bf9Eb5e743, // Universal Router on your chain
            callData: hex"3593564c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000068c3e20400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000120000000000000000000000000a7a491cd33af3648f141af9504e4ce6e6a1ac22900000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000422cfc85d8e48f8eab294be644d9e25c3030863003000bb84200000000000000000000000000000000000006000bb879a02482a880bce3f13e09da970dc34db4cd24d1000000000000000000000000000000000000000000000000000000000000"
        });

        // Sanity check
        require(IERC20(srcToken).balanceOf(owner) >= srcAmount, "insufficient balance");
        require(IERC20(srcToken).allowance(owner, PERMIT2) >= srcAmount, "approve Permit2 first");

        // ---- Build & sign Permit2 (SignatureTransfer) for Escrow as spender ----
        uint256 nonce = _pickNonce(owner);
        uint256 deadline = block.timestamp + 1 hours;

        ISignatureTransferP2.PermitTransferFrom memory permit;
        permit.permitted.token = srcToken;
        permit.permitted.amount = srcAmount;
        permit.nonce = nonce;
        permit.deadline = deadline;

        bytes32 digest = _buildDigest(permit, escrowAddr);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Sanity: verify signer
        address recovered = ecrecover(digest, v, r, s);
        require(recovered == owner, "bad sig");

        console2.log("DOMAIN_SEPARATOR");
        console2.logBytes32(_domainSeparator());
        console2.log("digest");
        console2.logBytes32(digest);
        console2.log("owner");
        console2.logAddress(owner);
        console2.log("recovered");
        console2.logAddress(recovered);

        // ---- Call escrow: swap + order with Permit2 ----
        escrow.swapAndCreateOrderWithPermit2(
            usrDstAddress,
            srcToken,
            srcAmount,
            dstToken,
            dstAmount,
            dstChainId,
            expiryWindow,
            expectedOutToken,
            hookExecutorSalt,
            hooks,
            permit,
            signature
        );

        vm.stopBroadcast();
    }
}

// forge script script/escrow/create_order/SwapAndCreateOrderWithPermit2.s.sol:SwapAndCreateOrderWithPermit2 \
//   --rpc-url $WLD_MAINNET_RPC \
//   --broadcast \
//   --private-key $DEPLOY_PRIVATE_KEY
