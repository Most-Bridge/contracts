// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PaymentRegistry} from "../src/contracts/PaymentRegistry.sol";

contract DeployPaymentRegistry is Script {
    function run() external {
        vm.startBroadcast();
        new PaymentRegistry();
        vm.stopBroadcast();
    }
}

// run using
// forge script script/DeployPaymentRegistry.s.sol:DeployPaymentRegistry --rpc-url https://sepolia.infura.io/v3/580a6a4667464912b43ef356b016839c --broadcast --private-key $DEPLOY_ADDRESS_PRIVATE_KEY
