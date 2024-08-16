#!/usr/bin/env bash

# load env vars 
source .env && \

# call the create order function on the escrow contract 
cast send \
    --rpc-url $RPC_URL \
    --private-key $USR_SRC_PRIVATE_KEY \
    $ESCROW_ADDRESS \
    "createOrder(address,uint256)" \
    $USR_DST_ADDRESS \
    100000000000000 \
    --value 1000000000000000
