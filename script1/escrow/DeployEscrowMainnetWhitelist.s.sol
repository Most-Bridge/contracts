// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {Script} from "forge-std/Script.sol";
// import {EscrowWhitelist} from "../../src/contracts/whitelist/EscrowWhitelist.sol";

// contract DeployEscrowWhitelist is Script {
//     function run() external {
//         address[] memory whitelistAddresses = new address[](12);

//         whitelistAddresses[0] = 0xe727dbADBB18c998e5DeE2faE72cBCFfF2e6d03D;
//         whitelistAddresses[1] = 0x898e87f1f5DCabCCbF68f2C17E2929672c6CA7DC;
//         whitelistAddresses[2] = 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6;
//         whitelistAddresses[3] = 0x841aaC69ce44874de22E361cD48e204bF7d686A5;
//         whitelistAddresses[4] = 0xf37Fd9185Bb5657D7E57DDEA268Fe56C2458F675;
//         whitelistAddresses[5] = 0xB61A597C2Ad219bE1404E2BC9D3E3E1dB1e99255;
//         whitelistAddresses[6] = 0x946F7Cc10FB0A6DC70860B6cF55Ef2C722cC7e1a;
//         whitelistAddresses[7] = 0x26D4793a24eDeBa373505721E507aFf2f5c7B58F;
//         whitelistAddresses[8] = 0xE919522e686D4e998e0434488273C7FA2ce153D8;
//         whitelistAddresses[9] = 0x9ea09816Db61C2fd860ECD4A615431Fe86b944Aa;
//         whitelistAddresses[10] = 0x06B4f8c3438F21577cE8508077657cf4532B8214;
//         whitelistAddresses[11] = 0xdd9eDEA60c8a92620606ad79C237217aEF3E4D93;

//         EscrowWhitelist.HDPConnectionInitial[] memory initialHDPChainConnections =
//             new EscrowWhitelist.HDPConnectionInitial[](2);

//         // For Ethereum Sepolia
//         initialHDPChainConnections[0] = EscrowWhitelist.HDPConnectionInitial({
//             destinationChainId: bytes32(uint256(111555111)),
//             paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
//             hdpProgramHash: bytes32(uint256(0x7ae890076e0f39de9dd1761f8261b20fca3169b404b75284f9ceae0864736d5)) // EVM custom module program hash
//         });

//         // For Starknet Sepolia
//         initialHDPChainConnections[1] = EscrowWhitelist.HDPConnectionInitial({
//             destinationChainId: bytes32(uint256(0x534e5f5345504f4c4941)),
//             paymentRegistryAddress: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4)),
//             hdpProgramHash: bytes32(uint256(0x4b92de77e8a7ba6eb68c6ade761c76612f626ba85b3224320955247b770aa76)) // CairoVM custom module program hash
//         });

//         vm.startBroadcast();
//         new EscrowWhitelist(whitelistAddresses, initialHDPChainConnections); // TODO: ADD WHITELIST ADDRESSES
//         vm.stopBroadcast();
//     }
// }

// // executable in deploy_verify.sh
