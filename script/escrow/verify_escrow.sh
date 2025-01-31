#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

# *NOTE* change contract address with each deployment

# OP SEPOLIA 
# forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  $ESCROW_ADDRESS src/contracts/SMM/EscrowSMM.sol:Escrow

# ETH SEPOLIA
# forge verify-contract --chain-id 11155111 --compiler-version 0.8.26 $ESCROW_ADDRESS  src/contracts/SMM/EscrowSMM.sol:Escrow

# ETH MAINNET 
forge verify-contract --chain-id 1 --compiler-version 0.8.26 --via-ir --optimizer-runs 200 0xc18c2a20dD3327CE93BCADED4A9EE31aC08Fd78a src/contracts/whitelist/EscrowWhitelist.sol:EscrowWhitelist