#!/bin/bash

# Test script for Dozzle Ansible setup

set -e

echo "Starting Vagrant VMs..."
vagrant up

echo "Installing required Ansible roles and collections..."
ansible-galaxy install -r requirements.yml

echo "Running Ansible playbook..."
ansible-playbook -i inventories/dev/hosts.yml site.yml

echo "Verifying Dozzle manager is running..."
vagrant ssh ubuntu1 -c "docker ps | grep dozzle"

echo "Verifying Dozzle agents are running..."
vagrant ssh ubuntu2 -c "docker ps | grep dozzle-agent"
vagrant ssh ubuntu3 -c "docker ps | grep dozzle-agent"

echo "Testing Dozzle web interface..."
curl -s http://192.168.56.11:8080 > /dev/null
if [ $? -eq 0 ]; then
  echo "Dozzle web interface is accessible"
else
  echo "Failed to access Dozzle web interface"
  exit 1
fi

echo "All tests passed!"
echo "Dozzle manager is available at: http://192.168.56.11:8080"
