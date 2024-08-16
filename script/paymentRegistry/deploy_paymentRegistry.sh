#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the payment registry 
forge script script/paymentRegistry/DeployPaymentRegistry.s.sol:DeployPaymentRegistry \
    --rpc-url $RPC_URL \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY
