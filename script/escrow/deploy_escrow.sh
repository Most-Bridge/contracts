#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the escrow contract on OPTIMISM SEPOLIA
forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
    --rpc-url $ETH_SEPOLIA_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY

# also verify right after lol... not possible yet, need to grep the contract address out of the deployment output and add it into this script
# export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY

# forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  $ESCROW_ADDRESS src/contracts/SMM/EscrowSMM.sol:Escrow
