#!/usr/bin/env bash

# load env vars 
source .env && \

# OP SEPOLIA
# first address is the contract address, second address is new allowed address
cast send 0x40b4e42e300f141df8b1163a3bdc22aebeccdcf9 "setAllowedAddress(address)" 0xDd2A1C0C632F935Ea2755aeCac6C73166dcBe1A6 --rpc-url $OP_SEPOLIA_RPC  --private-key $DEPLOY_PRIVATE_KEY