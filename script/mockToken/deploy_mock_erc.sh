#!/usr/bin/env bash

# load env vars 
source .env && \
export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

forge create --rpc-url https://sepolia.infura.io/v3/YOUR_KEY \
  --private-key YOUR_PRIVATE_KEY \
  src/MockToken.sol:MockToken