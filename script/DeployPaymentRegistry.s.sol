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

// *NOTE*: 
// when adding changing vars in the .env make sure to run `source .env` to update the changes in the terminal 

// *DEPLOY* using
// forge script script/DeployPaymentRegistry.s.sol:DeployPaymentRegistry --rpc-url https://sepolia.infura.io/v3/580a6a4667464912b43ef356b016839c --broadcast --private-key $DEPLOY_PRIVATE_KEY


// *TRANSFER* an order *** CHANGE ORDER ID PER TRANSFER *****
// cast send $PAYMENT_REGISTRY_ADDRESS "transferTo(uint256,address,address)" 2 $USR_DST_ADDRESS $MM_SRC_ADDRESS --value 9900000000000000 --rpc-url $RPC_URL --private-key $MM_DST_PRIVATE_KEY
