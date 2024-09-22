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

if ! command -v sha256sum &> /dev/null; then
    show "sha256sum not found. Please install sha256sum and re-run the script."
    exit 1
fi

# Define URLs for downloads and checksums
DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_amd64.tar.gz"
CHECKSUM_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/checksum.txt"

# Download appropriate binary based on system architecture
if [ "$ARCH" == "x86_64" ]; then
    show "Downloading for x86_64 architecture..."
    wget --quiet --show-progress "$DOWNLOAD_URL" -O heminetwork_v0.4.3_linux_amd64.tar.gz
    wget --quiet --show-progress "$CHECKSUM_URL" -O checksum.txt

elif [ "$ARCH" == "arm64" ]; then
    show "Downloading for arm64 architecture..."
    DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/v0.4.3/heminetwork_v0.4.3_linux_arm64.tar.gz"
    wget --quiet --show-progress "$DOWNLOAD_URL" -O heminetwork_v0.4.3_linux_arm64.tar.gz
    wget --quiet --show-progress "$CHECKSUM_URL" -O checksum.txt

else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

# Check if the checksum file is properly formatted
if ! grep -q "heminetwork_v0.4.3" checksum.txt; then
    show "Error: Checksum file does not contain the correct checksum entry."
    exit 1
fi

# Perform checksum verification
show "Verifying checksum..."
if ! sha256sum -c checksum.txt --ignore-missing; then
    show "Checksum verification failed for the downloaded file."
    exit 1
else
    show "Checksum verification passed."
fi

# Extract the downloaded file
show "Extracting downloaded archive..."
tar -xzf heminetwork_v0.4.3_linux_amd64.tar.gz > /dev/null
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
    if [ $? -ne 0 ];
