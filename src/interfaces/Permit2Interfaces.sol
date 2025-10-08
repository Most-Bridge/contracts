// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface ISignatureTransferP2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

interface IAllowanceTransferP2 {
    struct AllowanceTransferDetails {
        address from;
        address to;
        uint160 amount;
        address token;
    }

    function transferFrom(AllowanceTransferDetails[] calldata transferDetails) external;
    function transferFrom(address from, address to, uint160 amount, address token) external;
}
