#!/usr/bin/env bash

# load env vars 
source .env && \

# deploy the payment registry on ETHEREUM SEPOLIA
forge script script/paymentRegistry/DeployPaymentRegistry.s.sol:DeployPaymentRegistry \
    --rpc-url $MAINNET_OP_RPC \
    --broadcast \
    --private-key $DEPLOY_PRIVATE_KEY \
    --verify --etherscan-api-key $ETH_ETHERSCAN_API_KEY


# and verify it 
# export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

# forge verify-contract --chain-id 11155111 --compiler-version 0.8.26  $PAYMENT_REGISTRY_ADDRESS src/contracts/SMM/PaymentRegistrySMM.sol:PaymentRegistry