#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

# *NOTE*: change contract address in env with each deployment
forge verify-contract --chain-id 11155111 --compiler-version 0.8.26  ${PAYMENT_REGISTRY_ADDRESS} src/contracts/PaymentRegistry.sol:PaymentRegistry


