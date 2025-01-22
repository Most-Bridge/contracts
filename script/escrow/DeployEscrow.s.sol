// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../../src/contracts/SMM/EscrowSMM.sol";

contract DeployEscrow is Script {
    function run() external {
        vm.startBroadcast();

        Escrow.HDPConnectionInitial[] memory initialHDPChainConnections = new Escrow.HDPConnectionInitial[](2);

        // For Ethereum Sepolia
        initialHDPChainConnections[0] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(111555111)),
            paymentRegistryAddress: bytes32(uint256(uint160(0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1))),
            hdpProgramHash: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4))
        });

        // For Starknet Sepolia
        initialHDPChainConnections[1] = Escrow.HDPConnectionInitial({
            destinationChainId: bytes32(uint256(0x534e5f5345504f4c4941)),
            paymentRegistryAddress: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4)),
            hdpProgramHash: bytes32(uint256(0x3e6ede9c31b71072c18c6d1453285eac4ae0cf7702e3e5b8fe17d470ed0ddf4))
        });

        new Escrow(initialHDPChainConnections);
        vm.stopBroadcast();
    }
}

// executable in deploy_escrow.sh
