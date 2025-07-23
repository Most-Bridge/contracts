#!/usr/bin/env bash

# load env vars 
source .env && \

export ETHERSCAN_API_KEY=$ETH_ETHERSCAN_API_KEY

# *NOTE* change contract address with each deployment

# OP SEPOLIA 
# forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  $ESCROW_ADDRESS src/contracts/Escrow.sol:Escrow

# ETH SEPOLIA
# forge verify-contract --chain-id 11155111 --compiler-version 0.8.26 $ESCROW_ADDRESS  src/contracts/Escrow.sol:Escrow

# ETH MAINNET 
# forge verify-contract --chain-id 1 --compiler-version 0.8.26 $ESCROW_MAINNET_ADDRESS  src/contracts/Escrow.sol:Escrow

# OP SEPOLIA SOURCIFY
# forge verify-contract --chain-id 11155420 --compiler-version 0.8.28 0x5CcEF500C704cf6AafF2972dd0b64D038388bd38 src/contracts/Escrow.sol:Escrow --verifier-api-version sourcify

# lets see if this worked 
# forge verify-contract --chain-id 11155420 --compiler-version 0.8.28 \
#   0xC2769AaBB975d8061FA3BD54c306a4AaA0f5F6f5 \
#   src/contracts/Escrow.sol:Escrow \
#   --verifier sourcify

0x47c097d9Bb456634E85e283d3627C6D6FE3Dbb5D
forge verify-contract --chain-id 11155111 --compiler-version 0.8.28 \
  0x47c097d9Bb456634E85e283d3627C6D6FE3Dbb5D \
  src/contracts/Escrow.sol:Escrow \
  --verifier sourcify