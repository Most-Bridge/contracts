#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY

# *NOTE* change contract address with each deployment
forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  ${ESCROW_ADDRESS} src/contracts/SMM/EscrowSMM.sol:Escrow
