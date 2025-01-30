  #!/usr/bin/env bash

# load env vars 
source .env && \


# OPTIMISM SEPOLIA
export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY
forge script script/escrow/DeployEscrowMainnetWhitelist.s.sol:DeployEscrowWhitelist \
    --rpc-url $OP_SEPOLIA_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY \
    --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

# ETH SEPOLIA 
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrowMainnetWhitelist.s.sol:DeployEscrowWhitelist \
#     --rpc-url $ETH_SEPOLIA_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY \ 
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY

# ETH MAINNET
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge script script/escrow/DeployEscrowMainnetWhitelist.s.sol:DeployEscrowWhitelist \
#     --rpc-url $MAINNET_ETH_RPC \
#     --broadcast \
#     --private-key $DEPLOY_PRIVATE_KEY
#     --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY





