#!/bin/bash

show() {
    echo -e "\e[1;34m$1\e[0m"
}

ARCH=$(uname -m)

show "Checking your system architecture: $ARCH"
echo

# Install necessary dependencies if not installed
if ! command -v screen &> /dev/null; then
    show "Screen not found, installing..."
    sudo apt-get update
    sudo apt-get install -y screen > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show "Failed to install screen. Please check your package manager."
        exit 1
    fi
fi

if ! command -v jq &> /dev/null; then
    show "jq not found, installing..."
    sudo apt-get update
    sudo apt-get install -y jq > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show "Failed to install jq. Please check your package manager."
        exit 1
    fi
fi

# Download the appropriate version based on architecture
if [ "$ARCH" == "x86_64" ]; then
    show "Downloading for x86_64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz -O heminetwork_v0.4.3_linux_amd64.tar.gz
    tar -xzf heminetwork_v0.4.3_linux_amd64.tar.gz > /dev/null
    cd heminetwork_v0.4.3_linux_amd64 || { show "Failed to change directory."; exit 1; }

elif [ "$ARCH" == "arm64" ]; then
    show "Downloading for arm64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz -O heminetwork_v0.4.3_linux_amd64.tar.gz
    tar -xzf heminetwork_v0.4.3_linux_amd64.tar.gz > /dev/null
    cd heminetwork_v0.4.3_linux_amd64 || { show "Failed to change directory."; exit 1; }

else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

# Verify checksum
echo "Verifying checksum..."
if [ -f "../checksum.txt" ]; then
    sha256sum -c ../checksum.txt 2>&1 | grep -q "OK"
    if [ $? -ne 0 ]; then
        show "Checksum verification failed."
        exit 1
    fi
else
    show "Checksum file not found."
    exit 1
fi

echo
show "Select only one option:"
show "1. Create a new wallet (recommended)"
show "2. Use existing wallet"
read -p "Enter your choice (1/2): " choice
echo

# Function to securely read the private key from a file
read_private_key() {
    show "Enter the full path to your encrypted private key file (e.g., /path/to/private_key.enc):"
    read -p "Private key file path: " key_file

    if [ ! -f "$key_file" ]; then
        show "Private key file not found. Exiting."
        exit 1
    fi

    # Decrypt private key securely
    read -sp "Enter the passphrase to decrypt your private key: " passphrase
    echo

    priv_key=$(openssl enc -aes-256-cbc -d -in "$key_file" -pass pass:"$passphrase" 2>/dev/null)

    if [ -z "$priv_key" ]; then
        show "Decryption failed. Exiting."
        exit 1
    fi

    show "Private key successfully decrypted."
}

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
        show "Join: https://discord.gg/hemixyz"
        show "Request faucet from the faucet channel to this address: $pubkey_hash"
        echo
        read -p "Have you requested faucet? (y/N): " faucet_requested
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            priv_key=$(jq -r '.private_key' ~/popm-address.json)
            read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
            echo

            # Starting mining without exposing sensitive data
            screen -dmS airdropnode ./popmd --privkey="$priv_key" --static_fee="$static_fee" --bfg_url="wss://testnet.rpc.hemi.network/v1/ws/public"
            if [ $? -ne 0 ]; then
                show "Failed to start PoP mining in screen session."
                exit 1
            fi

            show "PoP mining has started in the detached screen session named 'airdropnode'."
        fi
    fi

elif [ "$choice" == "2" ]; then
    # Securely read the private key from an encrypted file
    read_private_key
    read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
    echo

    # Starting mining without exposing sensitive data
    screen -dmS airdropnode ./popmd --privkey="$priv_key" --static_fee="$static_fee" --bfg_url="wss://testnet.rpc.hemi.network/v1/ws/public"
    if [ $? -ne 0 ]; then
        show "Failed to start PoP mining in screen session."
        exit 1
    fi

    show "PoP mining has started in the detached screen session named 'airdropnode'."
else
    show "Invalid choice."
    exit 1
fi
