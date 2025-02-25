# Ubuntu Update Management with Ansible

Demonstrates Ansible configuration for managing Ubuntu VMs using both password and SSH key authentication methods, including sudo privilege escalation.

## Project Structure

```
.
├── inventory/
│   └── dev/                    # Development environment
│       ├── group_vars/        # Common settings for all hosts
│       ├── host_vars/         # Host-specific settings
│       │   ├── ubuntu1/      # Password auth + sudo example
│       │   └── ubuntu2/      # SSH key auth example
│       └── hosts.yml         # Inventory file
└── README.md
```

## Host Configuration

### Common Settings (All Hosts)
```yaml
# inventory/dev/group_vars/ubuntu_servers/main.yml
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_python_interpreter: /usr/bin/python3
```

### Password Authentication with Sudo (ubuntu1)
```yaml
# inventory/dev/host_vars/ubuntu1/main.yml
ansible_host: 192.168.56.11
ansible_user: dummy              # Custom user with sudo access
ansible_password: !vault |       # SSH password
ansible_become_password: !vault | # Sudo password
```

### SSH Key Authentication (ubuntu2)
```yaml
# inventory/dev/host_vars/ubuntu2/main.yml
ansible_host: 192.168.56.12
ansible_user: vagrant
ansible_ssh_private_key_file: ~/.vagrant.d/insecure_private_key
```

## Authentication Methods

### 1. Password Authentication (ubuntu1)
- Uses custom user 'dummy' with sudo privileges
- Requires password for both SSH and sudo operations
- Password authentication enabled in sshd_config
- Sudo access configured via /etc/sudoers.d/dummy

### 2. SSH Key Authentication (ubuntu2)
- Uses default vagrant user
- Authenticates using Vagrant's insecure private key
- Sudo access without password (vagrant user in sudoers)

## Playbook Tags

The playbook includes the following tags for granular control:

### check
- Disables and removes unattended-upgrades
- Updates apt cache
- Lists available package updates
- Test Status: ✅ Passed

### security
- Applies security updates only
- Checks for required reboots
- Lists packages requiring reboot
- Test Status: ✅ Passed

### update
- Performs full system update
- Checks for required reboots
- Lists packages requiring reboot
- Test Status: ✅ Passed

### reboot
- Checks if reboot is required
- Lists packages requiring reboot
- Performs reboot if needed
- Test Status: ✅ Passed

## Usage

### Setup Vault Password
```bash
# Create and secure vault password file
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass

# Add to gitignore
echo ".vault_pass" >> .gitignore
```

### Encrypt Passwords
```bash
# Encrypt SSH password
ansible-vault encrypt_string 'your_password' --name 'ansible_password' --vault-password-file .vault_pass

# Encrypt sudo password
ansible-vault encrypt_string 'your_sudo_password' --name 'ansible_become_password' --vault-password-file .vault_pass
```

### Run Commands
```bash
# Test all hosts
ansible all -i inventory/dev/hosts.yml -m ping --vault-password-file .vault_pass

# Run specific tags
ansible-playbook -i inventory/dev/hosts.yml site.yml \
  --vault-password-file .vault_pass \
  -t check,security  # Run check and security updates only

# Run full playbook
ansible-playbook -i inventory/dev/hosts.yml site.yml --vault-password-file .vault_pass

# Run on specific host with privilege escalation
ansible-playbook -i inventory/dev/hosts.yml site.yml \
  --vault-password-file .vault_pass \
  --limit ubuntu1 -b
```

## Test Results

All roles have been tested successfully with both authentication methods:

1. Password Authentication (ubuntu1):
   - SSH access with dummy user: ✅ Passed
   - Sudo privilege escalation: ✅ Passed
   - All playbook tags: ✅ Passed

2. Key Authentication (ubuntu2):
   - SSH access with vagrant user: ✅ Passed
   - Sudo privilege escalation: ✅ Passed
   - All playbook tags: ✅ Passed

## Security Best Practices

1. Always encrypt sensitive data with Ansible Vault
2. Store vault passwords securely, never in version control
3. Use SSH key authentication when possible
4. Configure sudo access with appropriate restrictions
5. Regularly rotate passwords and update vault values
6. Use separate users for different roles/responsibilities