#!/usr/bin/env bash

# load env vars 
source .env && \

export PRIVATE_KEY=your_private_key_here

forge script script/whitelist/BatchWhitelistScript.sol:BatchWhitelistScript --rpc-url $MAINNET_ETH_RPC --broadcast 