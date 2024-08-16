#!/usr/bin/env bash

# load env vars
source .env && \

# call the withdraw proved function from escrow contract 
cast send \
    --rpc-url $RPC_URL \
    --private-key $MM_SRC_PRIVATE_KEY \
    $ESCROW_ADDRESS \
    "withdrawProved(uint256)" \
    1 
    # ***  CHANGE ORDERID AS NEEDED *** 
