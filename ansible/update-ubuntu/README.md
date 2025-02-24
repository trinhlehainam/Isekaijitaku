# Ansible Update Ubuntu Test Environment

This project sets up a test environment for Ansible playbooks to manage Ubuntu system updates using Vagrant virtual machines.

## Prerequisites

- VirtualBox
- Vagrant
- Ansible
- WSL (if running on Windows)

## Directory Structure

```
.
├── Vagrantfile           # Vagrant VM configuration
├── inventory/
│   ├── vagrant.yml      # Ansible inventory for Vagrant VMs
│   └── production.yml   # Production inventory
└── playbooks/
    ├── check-updates.yml   # Check available updates
    ├── update-full.yml    # Perform full system update
    └── reboot.yml         # Handle system reboots
```

## Test Environment Setup

1. Start the Vagrant VMs:
```bash
vagrant up
```
   This will:
   - Create two Ubuntu 22.04 VMs
   - Configure private network (192.168.56.11 and 192.168.56.12)
   - Simulate packages requiring reboot

2. Test Ansible connection:
```bash
ansible all -i inventory/vagrant.yml -m ping
```

## Testing Playbooks

1. Check Available Updates:
```bash
ansible-playbook -i inventory/vagrant.yml playbooks/check-updates.yml
```
   - Stops unattended-upgrades service if running
   - Removes unattended-upgrades package
   - Shows available package updates
   - Can be run multiple times, even after unattended-upgrades is removed

2. Perform Full System Update:
```bash
ansible-playbook -i inventory/vagrant.yml playbooks/update-full.yml
```
   - Updates all packages
   - Checks if reboot is required
   - Shows packages requiring reboot

3. Handle System Reboots:
```bash
ansible-playbook -i inventory/vagrant.yml playbooks/reboot.yml
```
   - Reboots the system if required
   - Updates all packages
   - Checks if reboot is required
   - Shows packages requiring reboot
   - Performs reboot if required
   - Waits for system to come back online

## Cleanup

To remove the test VMs:
```bash
vagrant destroy -f
```

## Notes

- The test environment uses Vagrant's insecure private key for SSH authentication
- VMs are configured with private network IPs:
  - ubuntu1: 192.168.56.11
  - ubuntu2: 192.168.56.12
- Unattended-upgrades is installed and configured by default
- Test environment simulates packages requiring reboot
- The check-updates playbook is designed to work even after unattended-upgrades is removed
- All playbooks handle errors gracefully and continue execution

## References
- https://github.com/joelhandwell/ubuntu_vagrant_boxes/issues/1#issuecomment-292370353
- https://stackoverflow.com/a/40325864