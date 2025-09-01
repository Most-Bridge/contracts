// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {EscrowPM2, ISignatureTransferP2} from "src/contracts/WLD/EscrowPM2.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ---- tiny views on Permit2 ----
interface IPermit2 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonceBitmap(address owner, uint256 word) external view returns (uint256);
}

contract CreateOrderPermit2 is Script {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // EIP-712 typehashes for legacy SignatureTransfer
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)"
        "TokenPermissions(address token,uint256 amount)"
    );

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
        bytes32 ds = _domainSeparator();
        bytes32 structHash = _hashPermitTransferFrom(permit, spender);
        return keccak256(abi.encodePacked("\x19\x01", ds, structHash));
    }

    function _loadPk(string memory varName) internal view returns (uint256) {
        string memory raw = vm.envString(varName);
        if (!(bytes(raw).length >= 2 && bytes(raw)[0] == "0" && (bytes(raw)[1] == "x" || bytes(raw)[1] == "X"))) {
            require(bytes(raw).length == 64, "private key must be 64 hex chars (no 0x)");
            raw = string.concat("0x", raw);
        }
        return uint256(vm.parseBytes32(raw));
    }

    function run() external {
        uint256 pk = _loadPk("DEPLOY_PRIVATE_KEY");
        vm.startBroadcast(pk);

        address payable escrowAddress = payable(0x52702Ce4198e2278DC7c215362F22713A7a5fFc3);
        EscrowPM2 escrow = EscrowPM2(escrowAddress);
        address owner = vm.addr(pk);

        // Params
        bytes32 usrDstAddress = bytes32(uint256(uint160(0x3814f9F424874860ffCD9f70f0D4B74b81e791E8)));
        address srcToken = 0x2cFc85d8E48F8EAB294be644d9E25C3030863003; // WLD
        uint256 srcAmount = 100_000_000_000_000_000; // 0.1
        bytes32 dstToken = bytes32(uint256(uint160(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85))); // OP USDC
        uint256 dstAmount = 105_509;
        bytes32 dstChainId = bytes32(uint256(10));
        uint256 expiryWindow = 7 days;

        // Preflight
        require(IERC20(srcToken).balanceOf(owner) >= srcAmount, "Insufficient balance");
        require(IERC20(srcToken).allowance(owner, PERMIT2) >= srcAmount, "Approve Permit2 first");

        console2.log("DOMAIN_SEPARATOR");
        console2.logBytes32(_domainSeparator());

        // Nonce bitmap: word=0, bit=0
        uint256 word = 0;
        uint256 bit = 0;
        uint256 bm = IPermit2(PERMIT2).nonceBitmap(owner, word);
        require((bm & (1 << bit)) == 0, "Nonce bit already used");

        // Build legacy permit (amount as uint160)
        ISignatureTransferP2.PermitTransferFrom memory permit;
        permit.permitted.token = srcToken;
        permit.permitted.amount = srcAmount;
        permit.nonce = (word << 8) | bit;
        permit.deadline = block.timestamp + 1 hours;

        // Sign digest
        bytes32 digest = _buildDigest(permit, escrowAddress);
        console2.log("digest");
        console2.logBytes32(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Sanity: signer matches owner
        address rec = ecrecover(digest, v, r, s);
        console2.log("owner");
        console2.logAddress(owner);
        console2.log("recovered");
        console2.logAddress(rec);
        require(rec == owner, "ecrecover != owner");

        // Call escrow (expects legacy struct)
        escrow.createOrderWithPermit2(
            usrDstAddress, srcToken, srcAmount, dstToken, dstAmount, dstChainId, expiryWindow, permit, signature
        );

        vm.stopBroadcast();
    }
}

// forge script script/escrow/create_order/CreateOrderPermit2.s.sol:CreateOrderPermit2 \
//   --rpc-url $WLD_MAINNET_RPC \
//   --broadcast \
//   --private-key $DEPLOY_PRIVATE_KEY
