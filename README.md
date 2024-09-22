#!/bin/bash

# Function to display colored text
show() {
    echo -e "\e[1;34m$1\e[0m"
}

ARCH=$(uname -m)

show "Checking your system architecture: $ARCH"
echo

# Check if required packages are installed
for cmd in screen jq sha256sum wget; do
    if ! command -v "$cmd" &> /dev/null; then
        show "$cmd not found. Please install $cmd and re-run the script."
        exit 1
    fi
done

# Define download URLs based on architecture
if [ "$ARCH" == "x86_64" ]; then
    DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz"
    CHECKSUM_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/checksum.txt"
elif [ "$ARCH" == "arm64" ]; then
    DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_arm64.tar.gz"
    CHECKSUM_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/checksum.txt"
else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

# Download the binary and checksum
show "Downloading the binary..."
wget --quiet --show-progress "$DOWNLOAD_URL" -O heminetwork.tar.gz
wget --quiet --show-progress "$CHECKSUM_URL" -O checksum.txt

# Read the checksum for the downloaded file from checksum.txt
EXPECTED_SHA256=$(grep "heminetwork_v0.4.3" checksum.txt | awk '{ print $1 }')

# Verify if checksum is found
if [ -z "$EXPECTED_SHA256" ]; then
    show "Error: Could not find the expected checksum in checksum.txt."
    exit 1
fi

# Calculate the actual SHA256 of the downloaded file
show "Calculating checksum for the downloaded file..."
ACTUAL_SHA256=$(sha256sum heminetwork.tar.gz | awk '{ print $1 }')

# Compare the calculated checksum with the expected checksum
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    show "Checksum verification failed! Expected: $EXPECTED_SHA256 but got: $ACTUAL_SHA256."
    exit 1
else
    show "Checksum verification passed."
fi

# Extract the downloaded file
show "Extracting downloaded archive..."
tar -xzf heminetwork.tar.gz
if [ $? -ne 0 ]; then
    show "Failed to extract the archive. Please check the file and try again."
    exit 1
fi

cd heminetwork_v0.4.3_linux_amd64 || { show "Failed to change directory."; exit 1; }

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
            screen -dmS airdropnode ./popmd
            if [ $? -ne 0 ]; then
                show "Failed to start PoP mining in screen session."
                exit 1
            fi
            show "PoP mining has started in the detached screen session named 'airdropnode'."
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
    screen -dmS airdropnode ./popmd
    if [ $? -ne 0 ]; then
        show "Failed to start PoP mining in screen session."
        exit 1
    fi
    show "PoP mining has started in the detached screen session named 'airdropnode'."
else
    show "Invalid choice."
    exit 1
fi
