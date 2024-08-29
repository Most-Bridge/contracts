#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the payment registry on ETHEREUM SEPOLIA
forge script script/paymentRegistry/DeployPaymentRegistry.s.sol:DeployPaymentRegistry \
    --rpc-url $ETH_SEPOLIA_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY
