#!/usr/bin/env bash

# load env vars 
source .env && \

# *NOTE* change contract address with each deployment
forge verify-contract --chain-id 11155420 --compiler-version 0.8.26  0x248DA3C9904a3e1CdF90e27f35b59235eB3eEDB5 src/contracts/Escrow.sol:Escrow
