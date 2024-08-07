// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../src/contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run() external {
        vm.startBroadcast();
        new Escrow();
        vm.stopBroadcast();
    }
}

// *DEPLOY* script
// forge script script/DeployEscrow.s.sol:DeployEscrow --rpc-url $RPC_URL --broadcast --private-key $DEPLOY_PRIVATE_KEY

// *CREATE* an order on Escrow for 0.001 eth value, and 0.0001 fee
// cast send $ESCROW_ADDRESS "createOrder(address,uint256)" $USR_DST_ADDRESS 100000000000000 --value 10000000000000000 --rpc-url $RPC_URL --private-key $USR_SRC_PRIVATE_KEY

// *WITHDRAW PROVED*
// cast send $ESCROW_ADDRESS "withdrawProved(uint256)" 1 --rpc-url $RPC_URL --private-key $MM_SRC_PRIVATE_KEY
