#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

# *NOTE*: change contract address with each deployment
forge verify-contract --chain-id 11155111 --compiler-version 0.8.26  0x24963fF9872Dad4526206b8C63aaB2Cee00263b3 src/contracts/SMM/PaymentRegistrySMM.sol:PaymentRegistry


