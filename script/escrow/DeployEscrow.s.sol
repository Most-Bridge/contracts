// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../../src/contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run() external {
        vm.startBroadcast();
        new Escrow();
        vm.stopBroadcast();
    }
}

// executable in deploy_escrow.sh
