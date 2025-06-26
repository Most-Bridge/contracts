#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

forge script script/mockToken/DeployMock.s.sol:DeployMock \
    --rpc-url $ETH_SEPOLIA_RPC \
    --broadcast \
    --verify \
    --etherscan-api-key $ETH_ETHERSCAN_API_KEY \
    --private-key $DEPLOY_PRIVATE_KEY
    