// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";

contract AddDestinationChain is Script {
    function run() external {
        // Get the Escrow contract address from environment variable
        address escrowAddress = vm.envAddress("ESCROW_ADDRESS");
        
        // Get destination chain parameters from environment variables
        bytes32 destinationChain = vm.envBytes32("DESTINATION_CHAIN");
        bytes32 hdpProgramHash = vm.envBytes32("HDP_PROGRAM_HASH");
        bytes32 paymentRegistryAddress = vm.envBytes32("PAYMENT_REGISTRY_ADDRESS");
        
        vm.startBroadcast();
        
        Escrow escrow = Escrow(escrowAddress);
        escrow.addDestinationChain(destinationChain, hdpProgramHash, paymentRegistryAddress);
        
        vm.stopBroadcast();
        
        console.log("Successfully added destination chain:");
        console.log("Destination Chain:", uint256(destinationChain));
        console.log("HDP Program Hash:", uint256(hdpProgramHash));
        console.log("Payment Registry Address:", uint256(paymentRegistryAddress));
    }
}
