#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the escrow contract 
forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
    --rpc-url $RPC_URL \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY
