#!/usr/bin/env bash

# load env vars 
source .env && \

# *NOTE*: change contract address with each deployment
forge verify-contract --chain-id 11155111 --compiler-version 0.8.26  0x0CB147722909B3cD92D9a7C7f9dD83fA2D4d5B0E src/contracts/PaymentRegistry.sol:PaymentRegistry


