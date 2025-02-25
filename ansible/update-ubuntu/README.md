# Ubuntu Update Management with Ansible

This project provides Ansible roles for managing Ubuntu system updates, including security updates, unattended-upgrades, and system reboots.

## Prerequisites

- Vagrant with VirtualBox provider
- Ansible

## Project Structure

```
.
├── inventory/
│   └── dev/             # Inventory group for development VMs
│       └── vagrant.yml  # Inventory file for Vagrant VMs
├── roles/
│   ├── check-updates/   # Role for checking available updates
│   ├── security-update/ # Role for applying security updates
│   ├── system-update/   # Role for applying system updates
│   └── reboot/          # Role for handling system reboots
├── site.yml            # Main playbook
├── Vagrantfile         # Vagrant configuration
└── README.md
```

## Test Environment Setup

1. Create test VMs:
   ```bash
   vagrant destroy -f  # Clean up any existing VMs
   vagrant up         # Create new VMs
   ```
   This will:
   - Create two Ubuntu 22.04 VMs
   - Configure network settings
   - Install and hold back specific packages
   - Simulate packages requiring reboot
   - Configure SSH access

2. Test Ansible connection:
   ```bash
   ansible all -i inventory/dev/vagrant.yml -m ping
   ```

## Usage

The main playbook `site.yml` includes four roles that can be run together or individually using tags:

1. Check for updates (always runs):
   ```bash
   ansible-playbook -i inventory/dev/vagrant.yml site.yml
   ```

2. Apply security updates only:
   ```bash
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags security
   ```

3. Apply all system updates:
   ```bash
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags update
   ```

4. Handle system reboots:
   ```bash
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags reboot
   ```

## Role Details

### check-updates
- Manages unattended-upgrades service
- Checks for available system updates
- Shows update status summary

### security-update
- Applies security updates only
- Uses Ubuntu security repository
- Shows security update summary

### system-update
- Performs full system update
- Checks if reboot is required
- Shows update summary

### reboot
- Checks reboot status
- Shows packages requiring reboot
- Performs controlled system reboot if required

## Testing Process

1. Initial Setup:
   ```bash
   vagrant destroy -f && vagrant up
   ```

2. Verify Connectivity:
   ```bash
   ansible all -i inventory/dev/vagrant.yml -m ping
   ```

3. Test Each Role:
   ```bash
   # Check updates
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags check

   # Apply security updates
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags security

   # Apply system updates
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags update

   # Handle reboots
   ansible-playbook -i inventory/dev/vagrant.yml site.yml --tags reboot
   ```

4. Clean Up:
   ```bash
   vagrant destroy -f
   ```

## Troubleshooting

1. VM Boot Timeout:
   - The Vagrantfile includes an increased boot timeout (600 seconds)
   - If timeout occurs, try destroying and recreating the VMs

2. SSH Connection Issues:
   - Verify VM IP addresses and SSH configuration
   - Check that the VM is running: `vagrant status`
   - Try reprovisioning: `vagrant provision`

## Notes

- Roles are designed to be idempotent and can be run multiple times
- The check-updates role is included in all operations
- Security updates can be applied independently of full system updates
- System reboot is only performed if required
- All roles handle errors gracefully and continue execution

## References
- https://github.com/joelhandwell/ubuntu_vagrant_boxes/issues/1#issuecomment-292370353
- https://stackoverflow.com/a/40325864