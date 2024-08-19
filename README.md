## ~Name In Progress~

~Name In Progress~ is an L2<>L2 bridge. 

The following is a v0.0, POC, deployed on Sepolia testnet as the source chain and the destination chain. The v0, is built around a system where anyone can become a MM, and get paid out for completing bridging orders. 

The smart contracts are written in Solidity, and all testing is done through Foundry. 

The following repo is a part of a bigger system, that facilitates the entire bridging process, below you will find the repos that complete the system. 

## Additional Repos 
[layerGate](https://github.com/jackchinski/layerGate) This repo. Implements the smart contract which are responsible for locking up user funds, during the order creation in the Escrow smart contract, accepting a fulfillment of an order through the Payment Registry smart contract, and accepting proof on the source chain of the fulfilled order tx that took place on the destination chain. 

[EventWatch](https://github.com/jackchinski/eventWatch), the 3rd party system acting as the operator that facilitates the bridging process. Event Watch takes care of things such as listening for new orders being made, delivering those orders to MMs, listening for MMs fulfilling order events, and relaying proof of an order being completed back to the origin chain, to allow the locked funds to be claimed. 

[User Front End](https://github.com/jackchinski/havvalaUserFront), is a basic UI for creating an order as a User, which interacts with the bridge's smart contracts. 

[MM Front End](https://github.com/jackchinski/havvalaMMFront), is a basic UI for fulfilling an order that is received, and withdrawing the locked funds, once the order fulfillment has been proven. 

In order to test the entire system, all of the pieces must be running together in, especially the Event Watch system, more info can be found in the Event Watch repo, specifically in the `src/index.ts` file. 
