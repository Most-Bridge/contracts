#!/bin/bash

# Script to add a destination chain to the Escrow contract
# Usage: ./add_destination_chain.sh <destination_chain> <hdp_program_hash> <payment_registry_address> [private_key] [rpc_url]

set -e

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <destination_chain> <hdp_program_hash> <payment_registry_address> [private_key] [rpc_url]"
    echo ""
    echo "Arguments:"
    echo "  destination_chain       - The destination chain ID (e.g., 111555111 for Sepolia)"
    echo "  hdp_program_hash        - The HDP program hash (hex string without 0x)"
    echo "  payment_registry_address - The payment registry address (hex string without 0x)"
    echo "  private_key             - (Optional) Private key for transaction signing"
    echo "  rpc_url                 - (Optional) RPC URL for the network"
    echo ""
    echo "Examples:"
    echo "  $0 111555111 7ae890076e0f39de9dd1761f8261b20fca3169b404b75284f9ceae0864736d5 9eB3feB35884B284Ea1e38Dd175417cE90B43AA1"
    echo "  $0 0x534e5f5345504f4c4941 071afce37d7bb57b299d32f1e7d13359a079e69b555aaa1971c01693330a2671 051619905cafaf0be0aeb5e159f4b0ea43ed2efa55670f2aa0e4879910f24c53"
    exit 1
fi

DESTINATION_CHAIN=$1
HDP_PROGRAM_HASH=$2
PAYMENT_REGISTRY_ADDRESS=$3
PRIVATE_KEY=${4:-$PRIVATE_KEY}
RPC_URL=${5:-$RPC_URL}

# Remove 0x prefix if present
DESTINATION_CHAIN=${DESTINATION_CHAIN#0x}
HDP_PROGRAM_HASH=${HDP_PROGRAM_HASH#0x}
PAYMENT_REGISTRY_ADDRESS=${PAYMENT_REGISTRY_ADDRESS#0x}

# Check if ESCROW_ADDRESS is set
if [ -z "$ESCROW_ADDRESS" ]; then
    echo "Error: ESCROW_ADDRESS environment variable is not set"
    echo "Please set it to the deployed Escrow contract address"
    exit 1
fi

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable is not set"
    echo "Please set it or provide it as the 4th argument"
    exit 1
fi

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL environment variable is not set"
    echo "Please set it or provide it as the 5th argument"
    exit 1
fi

echo "Adding destination chain to Escrow contract..."
echo "Escrow Address: $ESCROW_ADDRESS"
echo "Destination Chain: $DESTINATION_CHAIN"
echo "HDP Program Hash: $HDP_PROGRAM_HASH"
echo "Payment Registry Address: $PAYMENT_REGISTRY_ADDRESS"
echo "Network: $RPC_URL"
echo ""

# Export environment variables for the script
export ESCROW_ADDRESS
export DESTINATION_CHAIN
export HDP_PROGRAM_HASH
export PAYMENT_REGISTRY_ADDRESS

# Run the Forge script
forge script script/escrow/AddDestinationChain.s.sol:AddDestinationChain \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --verify

echo ""
echo "Destination chain added successfully!"
echo "You can verify the connection using the Escrow contract's isHDPConnectionAvailable function"
