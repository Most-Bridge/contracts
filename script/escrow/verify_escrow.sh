#!/usr/bin/env bash

# load env vars 
source .env && \



# *NOTE* change contract address with each deployment

# OP SEPOLIA 
export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY
forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  $ESCROW_ADDRESS src/contracts/SMM/EscrowSMM.sol:Escrow

# ETH SEPOLIA
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
# forge verify-contract --chain-id 11155111 --compiler-version 0.8.26 $ESCROW_ADDRESS  src/contracts/SMM/EscrowSMM.sol:Escrow

