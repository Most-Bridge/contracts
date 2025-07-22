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
            paymentRegistryAddress: bytes32(uint256(0x051619905cafaf0be0aeb5e159f4b0ea43ed2efa55670f2aa0e4879910f24c53)),
            hdpProgramHash: bytes32(uint256(0x071afce37d7bb57b299d32f1e7d13359a079e69b555aaa1971c01693330a2671)) // CairoVM custom module program hash
        });

        new Escrow(initialHDPChainConnections);
        vm.stopBroadcast();
    }
}

// executable in deploy_verify_escrow.sh
