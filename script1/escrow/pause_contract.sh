#!/usr/bin/env bash

# load env vars 
source .env && \

# pause the escrow smart contract 
cast send --rpc-url $ETH_SEPOLIA_RPC  --private-key $DEPLOY_PRIVATE_KEY $ESCROW_ADDRESS "pauseContract()"
