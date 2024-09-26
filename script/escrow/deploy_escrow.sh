#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the escrow contract on OPTIMISM SEPOLIA
forge script script/escrow/DeployEscrow.s.sol:DeployEscrow \
    --rpc-url $OP_SEPOLIA_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY

# also verify right after lol 
export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY

# forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  $ESCROW_ADDRESS src/contracts/SMM/EscrowSMM.sol:Escrow
