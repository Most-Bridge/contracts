#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY

# *NOTE* change contract address with each deployment
forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  0xF542a55D4F43d2557C7Ad2d4Ed664Bf555e2F1d5 src/contracts/SMM/EscrowSMM.sol:EscrowSMM
