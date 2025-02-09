#!/bin/bash

# Create system user
echo "Creating system user act_runner..."
sudo useradd -r -s /bin/bash -m -d /var/lib/act_runner act_runner

# Add to docker group if docker is installed
if command -v docker &> /dev/null; then
    echo "Docker detected, adding act_runner to docker group..."
    sudo usermod -aG docker act_runner
fi

# Create configuration directory
echo "Setting up configuration..."
sudo mkdir -p /etc/act_runner

# Copy configuration file from template
echo "Creating configuration file from template..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
sudo cp "${SCRIPT_DIR}/../templates/config.yaml" /etc/act_runner/config.yaml

# Create log directory
echo "Setting up log directory..."
sudo mkdir -p /var/lib/act_runner/log
sudo chown -R act_runner:act_runner /var/lib/act_runner

echo "System setup completed successfully!"
