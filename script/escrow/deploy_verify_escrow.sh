#!/usr/bin/env bash

# load env vars 
source .env && \


# load foundry profile
# export FOUNDRY_PROFILE=deploy 


# OPTIMISM SEPOLIA
# export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
#     --rpc-url $OP_SEPOLIA_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY \
#     --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY \


# ETH SEPOLIA 
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
#     --rpc-url $ETH_SEPOLIA_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY \
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY

# ETH MAINNET
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
#     --rpc-url $MAINNET_ETH_RPC \
#     --broadcast \
#     --private-key $MAINNET_DEPLOY_PRIVATE_KEY \
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY

# WORLDCHAIN MAINNET
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
#     --rpc-url $WLD_MAINNET_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY \
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY


# ARBITRUM MAINNET
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
#     --rpc-url $ARBITRUM_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY \
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY


# BASE MAINNET
export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
    --rpc-url $BASE_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY \
    --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY




