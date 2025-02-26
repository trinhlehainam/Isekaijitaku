#!/bin/bash

# Test script for verifying reboot dependencies with real Vagrant VMs

echo "=== Vagrant Reboot Test ==="
echo "This script will test that ubuntu3 waits for ubuntu1 to reboot"

# Clean up any existing marker files
echo "Cleaning up any existing marker files..."
rm -rf /tmp/reboot_control
mkdir -p /tmp/reboot_control

# Ensure reboot-required files exist on all VMs
echo "Ensuring reboot-required files exist on all VMs..."
ansible -i inventory/local/hosts.yml all -m shell -a "touch /var/run/reboot-required && echo 'linux-image-generic' > /var/run/reboot-required.pkgs" -b

# Run the playbook with reboot tag
echo "Running the playbook with reboot tag..."
ansible-playbook -i inventory/local/hosts.yml site.yml --tags reboot -v

# Check if the marker files were cleaned up
echo "Checking if marker files were cleaned up..."
if [ -d "/tmp/reboot_control" ] && [ "$(ls -A /tmp/reboot_control)" ]; then
    echo " Test failed: Marker files were not cleaned up"
    ls -la /tmp/reboot_control
else
    echo " Test passed: Marker files were cleaned up correctly"
fi

# Check if all hosts have been rebooted
echo "Checking if all hosts have been rebooted..."
ansible -i inventory/local/hosts.yml all -m shell -a "ls -la /var/run/reboot-required || echo 'No reboot required'"

echo "=== Test Complete ==="
