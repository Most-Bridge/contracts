// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PaymentRegistry} from "src/contracts/PaymentRegistry.sol";

contract DeployPaymentRegistry is Script {
    function run() external {
        vm.startBroadcast();
        // new PaymentRegistry(); // TODO: add parameters to deploy
        vm.stopBroadcast();
    }
}

// executable in deploy_paymentRegistry.sh
