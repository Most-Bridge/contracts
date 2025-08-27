// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "src/contracts/Escrow.sol";
import {console} from "forge-std/console.sol";

contract AddDestinationChain is Script {
    function run() external {
        // Read inputs from env for flexibility and correct typing
        address payable escrowAddress = payable(vm.envAddress("ESCROW_ADDRESS"));
        uint256 destChainId = vm.envUint("DESTINATION_CHAIN_ID");
        bytes32 destinationChain = bytes32(destChainId);
        // Accept HDP program hash as uint (supports 0x-hex) and cast to bytes32 to avoid strict bytes32 parsing errors
        uint256 hdpProgramHashUint = vm.envUint("HDP_PROGRAM_HASH");
        bytes32 hdpProgramHash = bytes32(hdpProgramHashUint);
        address paymentRegistry = vm.envAddress("PAYMENT_REGISTRY_ADDRESS");
        bytes32 paymentRegistryAddress = bytes32(uint256(uint160(paymentRegistry)));

        // Diagnostics
        Escrow escrow = Escrow(escrowAddress);
        address escrowOwner = escrow.owner();
        console.log("Escrow:", escrowAddress);
        console.log("Escrow owner:", escrowOwner);
        console.log("Destination Chain:", uint256(destinationChain));
        console.log("Payment Registry Address:", paymentRegistry);

        bool alreadyExists = escrow.isHDPConnectionAvailable(destinationChain);
        if (alreadyExists) {
            console.log("Destination chain mapping already exists; skipping add.");
            return;
        }

        vm.startBroadcast();
        try escrow.addDestinationChain(destinationChain, hdpProgramHash, paymentRegistryAddress) {
            // ok
        } catch Error(string memory reason) {
            console.log("addDestinationChain reverted:", reason);
            revert(reason);
        } catch (bytes memory data) {
            console.logBytes(data);
            revert("addDestinationChain failed");
        }

        vm.stopBroadcast();

        console.log("Successfully added destination chain:");
        console.log("Destination Chain:", uint256(destinationChain));
        console.logBytes32(hdpProgramHash);
        console.log("Payment Registry Address:", paymentRegistry);
    }
}

// RUN
// forge script script/escrow/AddDestinationChain.s.sol:AddDestinationChain --rpc-url $WLD_MAINNET_RPC --private-key $DEPLOY_PRIVATE_KEY --broadcast --verify
