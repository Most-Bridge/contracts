// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IEscrow {
    function batchAddToWhitelist(address[] calldata _addresses) external;
}

contract BatchWhitelistScript is Script {
    address constant ESCROW_CONTRACT = address(1); // **** TODO: ADD ADDRESS HERE *****
    address constant WHITELIST_ADDRESS = 0x17C2D875CB397D813eAE817DaFD25807E348Df07;

    function run() external {
        // Load the private key of the owner from the environment variable
        uint256 ownerPrivateKey = vm.envUint("MAINNET_DEPLOY_PRIVATE_KEY");

        // Start broadcasting transactions from the owner address
        vm.startBroadcast(ownerPrivateKey);

        // Create an instance of the escrow contract
        IEscrow escrow = IEscrow(ESCROW_CONTRACT);

        // Prepare the addresses to whitelist
        address[] memory addressesToWhitelist = new address[](1);
        addressesToWhitelist[0] = WHITELIST_ADDRESS;

        // Call the batchAddToWhitelist function
        escrow.batchAddToWhitelist(addressesToWhitelist);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
