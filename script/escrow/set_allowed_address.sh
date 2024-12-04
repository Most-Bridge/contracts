#!/usr/bin/env bash

# load env vars 
source .env && \

# first address is the contract address, second address is new allowed address
cast send $ESCROW_ADDRESS "setAllowedAddress(address)" $DEPLOY_ADDRESS --rpc-url $ETH_SEPOLIA_RPC  --private-key $DEPLOY_PRIVATE_KEY