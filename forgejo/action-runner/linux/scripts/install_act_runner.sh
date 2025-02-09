#!/bin/bash

# Define version
ACT_RUNNER_VERSION="0.2.11"

# Detect system architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create directory for act runner
sudo mkdir -p /usr/local/bin

# Download the binary
echo "Downloading act_runner version ${ACT_RUNNER_VERSION} for ${ARCH}..."
sudo curl -L "https://dl.gitea.com/act_runner/${ACT_RUNNER_VERSION}/act_runner-${ACT_RUNNER_VERSION}-linux-${ARCH}" -o /usr/local/bin/act_runner

# Make it executable
sudo chmod +x /usr/local/bin/act_runner

# Verify installation
echo "Verifying installation..."
/usr/local/bin/act_runner --version

echo "Act runner installation completed successfully!"
