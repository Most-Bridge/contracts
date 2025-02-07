// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IEscrow {
    function batchAddToWhitelist(address[] calldata _addresses) external;
}

contract BatchWhitelistScript is Script {
    address constant ESCROW_CONTRACT = 0xcE386419d2415fFB730aD3cc429e2446a871551A;
    address constant ADDRESS_TO_WHITELIST = 0xd8791B6ABdb7C5d564018Ebb93Ad8a092b1D8Abd; // **** TODO: ADD ADDRESS HERE *****

    function run() external {
        // Load the private key of the owner from the environment variable
        uint256 ownerPrivateKey = vm.envUint("MAINNET_DEPLOY_PRIVATE_KEY");

        // Start broadcasting transactions from the owner address
        vm.startBroadcast(ownerPrivateKey);

        // Create an instance of the escrow contract
        IEscrow escrow = IEscrow(ESCROW_CONTRACT);

        // Prepare the addresses to whitelist
        address[] memory addressesToWhitelist = new address[](1);
        addressesToWhitelist[0] = ADDRESS_TO_WHITELIST;

        // Call the batchAddToWhitelist function
        escrow.batchAddToWhitelist(addressesToWhitelist);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
