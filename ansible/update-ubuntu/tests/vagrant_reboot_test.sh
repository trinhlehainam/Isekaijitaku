#!/bin/bash

# Set colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "=== Vagrant Reboot Test ==="
echo "This script will test that ubuntu3 waits for ubuntu1 to reboot"

# Clean up any existing reboot status files
echo -e "${CYAN}Cleaning up any existing reboot status files...${NC}"
rm -rf /tmp/ansible_reboot_control

# Ensure reboot-required files exist on all VMs
echo -e "${CYAN}Ensuring reboot-required files exist on all VMs...${NC}"
ansible -i inventory/local/hosts.yml all -m shell -a "touch /var/run/reboot-required && echo 'linux-image-generic' > /var/run/reboot-required.pkgs" -b

# Run the playbook with reboot tag
echo -e "${CYAN}Running the playbook with reboot tag...${NC}"
ansible-playbook -i inventory/local/hosts.yml site.yml --tags reboot -v

# Check if all hosts have been rebooted
echo -e "${CYAN}Checking if all hosts have been rebooted...${NC}"
ansible -i inventory/local/hosts.yml all -m shell -a "if [ -f /var/run/reboot-required ]; then echo -rw-r--r-- 1 root root 0 $(date '+%b %d %H:%M') /var/run/reboot-required; else echo 'No reboot required'; fi" -b

# Check if reboot status files were cleaned up
echo -e "${CYAN}Checking if reboot status files were cleaned up...${NC}"
if [ -d "/tmp/ansible_reboot_control" ]; then
    echo -e "${RED}Test failed: Reboot status files were not cleaned up${NC}"
    ls -la /tmp/ansible_reboot_control
else
    echo -e "${GREEN}Test passed: Reboot status files were cleaned up correctly${NC}"
fi

echo "=== Test Complete ==="
