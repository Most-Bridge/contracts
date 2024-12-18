#!/usr/bin/env bash

# load env vars 
source .env && \

# call the create order function on the escrow contract - order from OP to ETH
# cast send \
#     --rpc-url $OP_SEPOLIA_RPC \
#     --private-key $USR_SRC_PRIVATE_KEY \
#     $ESCROW_ADDRESS \
#     "createOrder(uint256,uint256,bytes32)" \
#     $USR_DST_ADDRESS \
#     100000000000000 \
#     11155111 \
#     --value 1000000000000000


# call the create order function on the escrow contract - order from OP to STARKNET    
cast send \
    --rpc-url $OP_SEPOLIA_RPC \
    --private-key $USR_SRC_PRIVATE_KEY \
    $ESCROW_ADDRESS \
    "createOrder(uint256,uint256,bytes32)" \
    $USR_DST_ACCOUNT_STARKNET \
    10 \
    0x534e5f5345504f4c494100000000000000000000000000000000000000000000 \
    --value 100
