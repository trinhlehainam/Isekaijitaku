#!/bin/bash

# Copy systemd service file from template
echo "Creating systemd service file from template..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
sudo cp "${SCRIPT_DIR}/../templates/act_runner.service" /etc/systemd/system/act_runner.service

# Reload systemd configuration
echo "Reloading systemd configuration..."
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl enable act_runner.service
sudo systemctl start act_runner.service

echo "Service setup completed successfully!"
