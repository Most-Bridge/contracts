// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {Script} from "forge-std/Script.sol";
// import {Escrow} from "src/contracts/Escrow.sol";

contract CreateOrder is Script {
    function run() external {
        address escrowAddress = 0x9c46f4d7Aaf6fa5507220CB843D873C1f5D2342a;
        Escrow escrow = Escrow(payable(escrowAddress));

//         // Parameters for the createOrder function
//         bytes32 usrDstAddress = bytes32(uint256(0x034501931e05c7934A0c6246fC7409CF9e650538F330A6B7a36f134c3B0577Ee));
//         address srcToken = address(0);
//         uint256 srcAmount = 1000000000000000;
//         bytes32 dstToken = bytes32(uint256(0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7));
//         uint256 dstAmount = 900000000000000;
//         bytes32 dstChainId = bytes32(uint256(0x534e5f5345504f4c4941));
//         uint256 expiryWindow = 1 days;

//         // Call the createOrder function
//         escrow.createOrder{value: srcAmount}(
//             usrDstAddress, srcToken, srcAmount, dstToken, dstAmount, dstChainId, expiryWindow
//         );
//     }
// }
