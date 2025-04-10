#!/usr/bin/env bash

# load env vars 
source .env && \


export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY
cast send \
  --rpc-url $ETH_SEPOLIA_RPC \
  --private-key $USR_SRC_PRIVATE_KEY \
  $ESCROW_ADDRESS \
  "createOrder(bytes32,address,uint256,bytes32,uint256,uint256,bytes32)" \
  0x034501931e05c7934A0c6246fC7409CF9e650538F330A6B7a36f134c3B0577Ee \
  0x0000000000000000000000000000000000000000 \
  100000000000000 \
  0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 \
  90000000000000 \
  10000000000000 \
  0x534e5f5345504f4c494100000000000000000000000000000000000000000000 \
  --value 100000000000000

# forge script script/escrow/create_order/CreateOrder.s.sol:CreateOrder \
#     --rpc-url $ETH_SEPOLIA_RPC \
#     --broadcast \
#     --private-key $USR_SRC_PRIVATE_KEY \
#     --value 1000000000000000 

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
# USR_DST_ADDRESS=$STARKNET_DST_ADDRESS
# FEE=100000000000000
# DST_CHAIN_ID=$(printf '%-64s' "534e5f5345504f4c4941" | tr ' ' '0')
# SRC_TOKEN=0
# SRC_AMOUNT=1000000000000000
# DST_TOKEN=0
# DST_AMOUNT=900000000000000

# cast send \
#     --rpc-url $ETH_SEPOLIA_RPC \
#     --private-key $USR_SRC_PRIVATE_KEY \
#     $ESCROW_ADDRESS \
#     "createOrder(uint256,uint256,bytes32,address,uint256,address,uint256)" \
#     $USR_DST_ADDRESS \
#     $FEE \
#     $DST_CHAIN_ID \
#     $SRC_TOKEN \
#     $SRC_AMOUNT \
#     $DST_TOKEN \
#     $DST_AMOUNT \
#     --value $SRC_AMOUNT
