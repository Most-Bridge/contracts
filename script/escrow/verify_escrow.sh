#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$OP_ETHERSCAN_API_KEY

# *NOTE* change contract address with each deployment
forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  0xdD02545B6caD156e18D696dcb17420A4987EAcc9 src/contracts/SMM/EscrowSMM.sol:Escrow
