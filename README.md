#!/bin/bash

# Function to display colored text
show() {
    echo -e "\e[1;34m$1\e[0m"
}

ARCH=$(uname -m)

show "Checking your system architecture: $ARCH"
echo

# Check if the required packages are installed and install if missing
if ! command -v screen &> /dev/null; then
    show "Screen not found. Please install screen and re-run the script."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    show "jq not found. Please install jq and re-run the script."
    exit 1
fi

# Download appropriate binary based on system architecture
if [ "$ARCH" == "x86_64" ]; then
    show "Downloading for x86_64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz -O heminetwork_v0.4.3_linux_amd64.tar.gz
    tar -xzf heminetwork_v0.4.3_linux_amd64.tar.gz > /dev/null
    cd heminetwork_v0.4.3_linux_amd64 || { show "Failed to change directory."; exit 1; }

elif [ "$ARCH" == "arm64" ]; then
    show "Downloading for arm64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_arm64.tar.gz -O heminetwork_v0.4.3_linux_arm64.tar.gz
    tar -xzf heminetwork_v0.4.3_linux_arm64.tar.gz > /dev/null
    cd heminetwork_v0.4.3_linux_arm64 || { show "Failed to change directory."; exit 1; }

else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

echo
show "Select only one option:"
show "1. Create a new wallet (recommended)"
show "2. Use existing wallet"
read -p "Enter your choice (1/2): " choice
echo

# Handling new wallet creation
if [ "$choice" == "1" ]; then
    show "Generating a new wallet..."
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    if [ $? -ne 0 ]; then
        show "Failed to generate wallet."
        exit 1
    fi
    cat ~/popm-address.json
    echo
    read -p "Have you saved the above details? (y/N): " saved
    echo
    if [[ "$saved" =~ ^[Yy]$ ]]; then
        pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
        show "Join : https://discord.gg/hemixyz"
        show "Request faucet from the faucet channel for this address: $pubkey_hash"
        echo
        read -p "Have you requested faucet? (y/N): " faucet_requested
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            priv_key=$(jq -r '.private_key' ~/popm-address.json)
            read -p "Enter static fee (numerical only, recommended : 100-200): " static_fee
            echo
            export POPM_BTC_PRIVKEY="$priv_key"
            export POPM_STATIC_FEE="$static_fee"
            export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

            # Start PoP mining in a detached screen session
            screen -dmS hemi ./popmd
            if [ $? -ne 0 ]; then
                show "Failed to start PoP mining in screen session."
                exit 1
            fi
            show "PoP mining has started in the detached screen session named 'hemi'."
        fi
    fi

# Handling existing wallet usage
elif [ "$choice" == "2" ]; then
    read -p "Enter your Private key: " priv_key
    read -p "Enter static fee (numerical only, recommended : 100-200): " static_fee
    echo
    export POPM_BTC_PRIVKEY="$priv_key"
    export POPM_STATIC_FEE="$static_fee"
    export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

    # Start PoP mining in a detached screen session
    screen -dmS hemi ./popmd
    if [ $? -ne 0 ]; then
        show "Failed to start PoP mining in screen session."
        exit 1
    fi
    show "PoP mining has started in the detached screen session named 'hemi'."
else
    show "Invalid choice."
    exit 1
fi
