// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run() external {
        vm.startBroadcast();

        Escrow.HDPConnectionInitial[] memory initialHDPChainConnections = new Escrow.HDPConnectionInitial[](2);

        // For Ethereum Sepolia
        initialHDPChainConnections[0] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(111555111)),
            paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
            hdpProgramHash: bytes32(uint256(0x7ae890076e0f39de9dd1761f8261b20fca3169b404b75284f9ceae0864736d5)) // EVM custom module program hash
        });

        // For Starknet Sepolia
        initialHDPChainConnections[1] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(0x534e5f5345504f4c4941)),
            paymentRegistryAddress: bytes32(uint256(0x0740aa1758532dd9cb945a52a59d949aed280733fb243b7721666a1aa1989d55)),
            hdpProgramHash: bytes32(uint256(0x228737596cc16de4a733aec478701996f6c0f937fe66144781d91537b6df629)) // CairoVM custom module program hash
        });

        address withdrawalAddress = 0x9c46f4d7Aaf6fa5507220CB843D873C1f5D2342a; // Replace with the actual withdrawal address
        address relayAddress = address(1); // Replace with the actual relay address

        new Escrow(initialHDPChainConnections, withdrawalAddress, relayAddress);
        vm.stopBroadcast();
    }
}

// executable in deploy_verify_escrow.sh
