#!/bin/bash

# Function to display information in blue color
show() {
    echo -e "\e[1;34m$1\e[0m"
}

# Function to display an error in red color
error() {
    echo -e "\e[1;31m$1\e[0m" >&2
}

ARCH=$(uname -m)
show "Checking your system architecture: $ARCH"
echo

# Prompt user before installing 'screen' and 'jq'
install_if_missing() {
    local pkg_name=$1
    if ! command -v "$pkg_name" &> /dev/null; then
        read -p "$pkg_name not found, install? (y/N): " install_pkg
        if [[ "$install_pkg" =~ ^[Yy]$ ]]; then
            sudo apt-get update
            sudo apt-get install -y "$pkg_name" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                error "Failed to install $pkg_name. Please check your package manager."
                exit 1
            fi
        else
            error "$pkg_name is required. Exiting."
            exit 1
        fi
    fi
}

# Check and install 'screen' and 'jq' if not found
install_if_missing screen
install_if_missing jq

# Function to verify checksum of downloaded file
verify_checksum() {
    local file=$1
    local checksum=$2
    echo "$checksum  $file" > checksum.txt
    sha256sum -c checksum.txt --quiet
    if [ $? -ne 0 ]; then
        error "Checksum verification failed for $file."
        exit 1
    fi
    rm checksum.txt  # Clean up
}

# Download appropriate software based on system architecture
if [ "$ARCH" == "x86_64" ]; then
    show "Downloading for x86_64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.3.13/heminetwork_v0.3.13_linux_amd64.tar.gz -O heminetwork_v0.3.13_linux_amd64.tar.gz
    
    # Replace with actual checksum
    verify_checksum "heminetwork_v0.3.13_linux_amd64.tar.gz" "YOUR_X86_64_CHECKSUM"
    
    tar -xzf heminetwork_v0.3.13_linux_amd64.tar.gz > /dev/null
    cd heminetwork_v0.3.13_linux_amd64 || { error "Failed to change directory."; exit 1; }

elif [ "$ARCH" == "arm64" ]; then
    show "Downloading for arm64 architecture..."
    wget --quiet --show-progress https://github.com/hemilabs/heminetwork/releases/download/v0.3.13/heminetwork_v0.3.13_linux_arm64.tar.gz -O heminetwork_v0.3.13_linux_arm64.tar.gz
    
    # Replace with actual checksum
    verify_checksum "heminetwork_v0.3.13_linux_arm64.tar.gz" "YOUR_ARM64_CHECKSUM"
    
    tar -xzf heminetwork_v0.3.13_linux_arm64.tar.gz > /dev/null
    cd heminetwork_v0.3.13_linux_arm64 || { error "Failed to change directory."; exit 1; }

else
    error "Unsupported architecture: $ARCH"
    exit 1
fi

echo
show "Select only one option:"
show "1. Create a new wallet (recommended)"
show "2. Use an existing wallet"
read -p "Enter your choice (1/2): " choice
echo

# Encrypt and store private key securely
encrypt_and_save_priv_key() {
    local priv_key=$1
    echo "$priv_key" | openssl enc -aes-256-cbc -salt -pbkdf2 -out ~/.popm_priv_key.enc
    chmod 600 ~/.popm_priv_key.enc
}

# Decrypt private key from file
decrypt_priv_key() {
    openssl enc -aes-256-cbc -d -pbkdf2 -in ~/.popm_priv_key.enc
}

# Static fee input validation
validate_fee() {
    local fee=$1
    if ! [[ "$fee" =~ ^[0-9]+$ ]]; then
        error "Invalid static fee. Must be a number."
        exit 1
    fi
}

if [ "$choice" == "1" ]; then
    show "Generating a new wallet..."
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    if [ $? -ne 0 ]; then
        error "Failed to generate wallet."
        exit 1
    fi

    # Display wallet info but don't log sensitive data
    jq . ~/popm-address.json
    echo
    read -p "Have you saved the above details? (y/N): " saved
    echo
    if [[ "$saved" =~ ^[Yy]$ ]]; then
        pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
        show "Join the Discord: https://discord.gg/hemixyz"
        show "Request faucet funds for this address: $pubkey_hash"
        echo
        read -p "Have you requested faucet funds? (y/N): " faucet_requested
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            priv_key=$(jq -r '.private_key' ~/popm-address.json)
            read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
            validate_fee "$static_fee"
            echo

            # Encrypt and save private key
            encrypt_and_save_priv_key "$priv_key"

            # Export required environment variables
            export POPM_STATIC_FEE="$static_fee"
            export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

            # Start PoP mining in a screen session
            screen -dmS hemi ./popmd --priv-key-file <(decrypt_priv_key)
            if [ $? -ne 0 ]; then
                error "Failed to start PoP mining in screen session."
                exit 1
            fi

            show "PoP mining has started in the detached screen session named 'hemi'."
        fi
    fi

elif [ "$choice" == "2" ]; then
    read -sp "Enter your private key: " priv_key
    echo
    read -p "Enter static fee (numerical only, recommended: 100-200): " static_fee
    validate_fee "$static_fee"
    echo

    # Encrypt and save private key
    encrypt_and_save_priv_key "$priv_key"

    # Export required environment variables
    export POPM_STATIC_FEE="$static_fee"
    export POPM_BFG_URL="wss://testnet.rpc.hemi.network/v1/ws/public"

    # Start PoP mining in a screen session
    screen -dmS hemi ./popmd --priv-key-file <(decrypt_priv_key)
    if [ $? -ne 0 ]; then
        error "Failed to start PoP mining in screen session."
        exit 1
    fi

    show "PoP mining has started in the detached screen session named 'hemi'."
else
    error "Invalid choice."
    exit 1
fi
