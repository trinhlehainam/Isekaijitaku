# Ubuntu Update Management with Ansible

Demonstrates Ansible configuration for managing Ubuntu VMs using both password and SSH key authentication methods.

## Project Structure

```
.
├── inventory/
│   └── dev/                    # Development environment
│       ├── group_vars/        # Common settings for all hosts
│       ├── host_vars/         # Host-specific settings
│       │   ├── ubuntu1/      # Password auth example
│       │   └── ubuntu2/      # SSH key auth example
│       └── hosts.yml         # Inventory file
└── README.md
```

## Host Configuration

### Common Settings (All Hosts)
```yaml
# inventory/dev/group_vars/ubuntu_servers/main.yml
ansible_user: vagrant
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_python_interpreter: /usr/bin/python3
```

### Password Authentication (ubuntu1)
```yaml
# inventory/dev/host_vars/ubuntu1/main.yml
ansible_host: 192.168.56.11
ansible_password: !vault |  # Encrypted password
```

### SSH Key Authentication (ubuntu2)
```yaml
# inventory/dev/host_vars/ubuntu2/main.yml
ansible_host: 192.168.56.12
ansible_ssh_private_key_file: ~/.vagrant.d/insecure_private_key
```

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
# Encrypt a string
ansible-vault encrypt_string 'your_password' --name 'ansible_password' --vault-password-file .vault_pass
```

### Run Commands
```bash
# Test all hosts
ansible all -i inventory/dev/hosts.yml -m ping --vault-password-file .vault_pass

# Run playbook
ansible-playbook -i inventory/dev/hosts.yml site.yml --vault-password-file .vault_pass

# Run on specific host
ansible-playbook -i inventory/dev/hosts.yml site.yml \
  --vault-password-file .vault_pass \
  --limit ubuntu1
```

## Security Best Practices

1. Always encrypt sensitive data with Ansible Vault
2. Store vault passwords securely, never in version control
3. Use SSH key authentication when possible
4. Regularly rotate passwords and update vault values