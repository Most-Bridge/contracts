#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the escrow contract on OPTIMISM SEPOLIA
forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
    --rpc-url $OP_SEPOLIA_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY
