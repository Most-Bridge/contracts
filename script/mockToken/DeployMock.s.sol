// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockToken} from "./MockToken.sol";

contract DeployMock is Script {
    function run() external {
        vm.startBroadcast();
        new MockToken();
        vm.stopBroadcast();
    }
}
