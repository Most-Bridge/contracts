## MOST BRIDGE

Most is an L2<>L1 bridge. 

The following is a v1.0, POC, deployed on OP Sepolia as the source chain and ETH Sepolia the destination chain. The v1, is built around a singular MM that facilitates the bridging process, and claiming the bridging tolls. 

The smart contracts are written in Solidity, and all testing is done through Foundry. 

The following repo is a part of a bigger system, that facilitates the entire bridging process, below you will find the repos that complete the system. 

## Additional Repos 
[most-contracts](https://github.com/Most-Bridge/most-contracts) This repo. Implements the smart contract which are responsible for locking up user funds, during the order creation in the Escrow smart contract, accepting a fulfillment of an order through the Payment Registry smart contract, and accepting proof on the source chain of the fulfilled order tx that took place on the destination chain. 

[mm-service](https://github.com/Most-Bridge/mm-service), the 3rd party system acting as the operator that facilitates the bridging process. Event Watch takes care of things such as listening for new orders being made, delivering those orders to MMs, listening for MMs fulfilling order events, and relaying proof of an order being completed back to the origin chain, to allow the locked funds to be claimed. 

[most-ui](https://github.com/Most-Bridge/most-ui), is a basic UI for creating an order as a User, which interacts with the bridge's smart contracts. 

[mm-ui](https://github.com/Most-Bridge/mm-ui), is a basic UI for fulfilling an order that is received, and withdrawing the locked funds, once the order fulfillment has been proven. 

In order to test the entire system, all of the pieces must be running together, especially the mm-service, as well as all listeners that are hosted on the backend. 
