#!/bin/bash

# Copy systemd service file from template
echo "Creating systemd service file from template..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
sudo cp "${SCRIPT_DIR}/../templates/act_runner.service" /etc/systemd/system/act_runner.service

# Reload systemd configuration
echo "Reloading systemd configuration..."
sudo systemctl daemon-reload

echo "Service setup completed successfully!"
