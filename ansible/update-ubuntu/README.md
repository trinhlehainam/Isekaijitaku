# Ubuntu Update Automation with Ansible

This project contains Ansible playbooks to automate Ubuntu system updates with different strategies.

## Project Structure
```
.
├── inventory/
│   ├── production.yml    # Production inventory
│   └── vagrant.yml      # Test inventory for Vagrant VMs
├── playbooks/
│   ├── check-updates.yml   # Display available updates
│   ├── update-security.yml # Security updates only
│   ├── update-full.yml    # Full system update
│   └── reboot.yml         # Handle system reboots
└── Vagrantfile          # Vagrant configuration for test environment
```

## Prerequisites
- Ansible 2.9+
- Vagrant 2.3+ (for testing)
- VirtualBox 6.1+ (for testing)

## Available Playbooks

### Check Available Updates
Display list of available package updates:
```bash
# Using command line
ansible-playbook -i inventory/vagrant.yml playbooks/check-updates.yml --diff

# Using Semaphore/Tower
Playbook: playbooks/check-updates.yml
Inventory: Select appropriate inventory
```

### Security Updates Only
Apply only security-related updates and check if reboot is needed:
```bash
# Using command line
ansible-playbook -i inventory/vagrant.yml playbooks/update-security.yml --diff

# Using Semaphore/Tower
Playbook: playbooks/update-security.yml
Inventory: Select appropriate inventory
```

### Full System Update
Perform a complete system update and check if reboot is needed:
```bash
# Using command line
ansible-playbook -i inventory/vagrant.yml playbooks/update-full.yml --diff

# Using Semaphore/Tower
Playbook: playbooks/update-full.yml
Inventory: Select appropriate inventory
```

### System Reboot
Handle system reboots when required:
```bash
# Using command line
ansible-playbook -i inventory/vagrant.yml playbooks/reboot.yml --diff

# Using Semaphore/Tower
Playbook: playbooks/reboot.yml
Inventory: Select appropriate inventory
```

## Usage Notes

### Command Line Options
When running from command line, useful options include:
- `--diff`: Show what changes will be made
- `-v`: Verbose mode
- `--check`: Dry run mode
- `--limit`: Limit to specific hosts

### Ansible Server Platforms
When using Ansible automation platforms (Semaphore UI or Ansible Tower):
1. Import the playbooks into your project
2. Configure your inventory in the platform
3. Set any required variables in the platform
4. Schedule or run the playbooks as needed

### Typical Workflow
1. Check available updates: `check-updates.yml`
2. Apply updates using either:
   - `update-security.yml` for security updates only
   - `update-full.yml` for all updates
3. If updates indicate a reboot is needed, use `reboot.yml` to perform the reboot

The playbooks are designed to work with both command-line execution and automation platforms without requiring additional configuration files.