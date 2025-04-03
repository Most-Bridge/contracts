// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../../../src/contracts/SMM/EscrowSMM.sol";

contract SolidityInteraction is Script {
    function run() external {
        address escrowAddress = 0xA5AeC461aeAD380f35991ceB444890a653167826;
        Escrow escrow = Escrow(escrowAddress);

        // Parameters for the createOrder function
        bytes32 usrDstAddress = bytes32(uint256(0x034501931e05c7934A0c6246fC7409CF9e650538F330A6B7a36f134c3B0577Ee));
        address srcToken = address(0);
        uint256 srcAmount = 1000000000000000;
        bytes32 dstToken = bytes32(uint256(0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7));
        uint256 dstAmount = 900000000000000;
        uint256 fee = 100000000000000;
        bytes32 dstChainId = bytes32(uint256(111555111));

        // Call the createOrder function
        escrow.createOrder(usrDstAddress, srcToken, srcAmount, dstToken, dstAmount, fee, dstChainId);

        // Optionally, check results or states if needed
    }
}
