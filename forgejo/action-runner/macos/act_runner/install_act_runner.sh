#!/bin/bash

# Source architecture check script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_arch.sh"

# Set architecture for download
if echo "$CPU_INFO" | grep -q "Apple M"; then
    # For M-series Macs, use arm64 even if running under Rosetta
    ARCH="arm64"
else
    # For Intel Macs
    ARCH="amd64"
fi

# Set version
VERSION="0.2.11"  # Check https://dl.gitea.com/act_runner/ for latest version

echo "Downloading act_runner version $VERSION for darwin-$ARCH..."

# Download specific version of darwin binary from Gitea releases
curl -L -o act_runner "https://dl.gitea.com/act_runner/${VERSION}/act_runner-${VERSION}-darwin-${ARCH}"

echo "Making binary executable..."
chmod +x act_runner

echo "Moving to system bin directory..."
sudo mv act_runner /usr/local/bin/

echo "Installation complete. Verify by running:"
echo "act_runner --version"
