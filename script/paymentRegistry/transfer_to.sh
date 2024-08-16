#!/usr/bin/env bash

# load env vars 
source .env && \

# call the transfer to function of the payment registry smart contract 
cast send \
    $PAYMENT_REGISTRY_ADDRESS \
    "transferTo(uint256,address,address)" \
    2 \ 
    $USR_DST_ADDRESS \
    $MM_SRC_ADDRESS \
    --value 9900000000000000 \
    --rpc-url $RPC_URL \
    --private-key $MM_DST_PRIVATE_KEY

    # *** CHANGE ORDER ID AS NEEDED *** 
