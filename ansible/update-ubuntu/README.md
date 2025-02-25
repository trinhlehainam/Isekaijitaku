# Ubuntu Update Management with Ansible

This project demonstrates different authentication methods for Ansible, including password-based and SSH key-based authentication.

## Prerequisites

- Vagrant with VirtualBox provider
- Ansible

## Project Structure

```
.
├── inventory/
│   ├── dev/                    # Development environment
│   │   ├── group_vars/        # Variables for groups
│   │   │   └── ubuntu_servers/
│   │   │       └── main.yml   # Common settings (user, Python interpreter)
│   │   ├── host_vars/         # Host-specific variables
│   │   │   ├── ubuntu1/       # Password authentication example
│   │   │   │   └── main.yml
│   │   │   └── ubuntu2/       # SSH key authentication example
│   │   │       └── main.yml
│   │   └── inventory.yml      # Development inventory
│   └── prod/                  # Production environment (not modified)
└── README.md
```

## Authentication Methods

The project demonstrates two common authentication methods in Ansible:

### 1. Common Settings (Group Variables)

All hosts share these common settings:

```yaml
# inventory/dev/group_vars/ubuntu_servers/main.yml
ansible_user: vagrant
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_python_interpreter: /usr/bin/python3
```

### 2. Password Authentication (ubuntu1)

Example of password-based authentication with encrypted password:

```yaml
# inventory/dev/host_vars/ubuntu1/main.yml
ansible_host: 192.168.56.11
ansible_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          [encrypted password string]
```

Note: The vagrant user has sudo privileges by default, so no become password is required.

### 3. SSH Key Authentication (ubuntu2)

Example of SSH key-based authentication:

```yaml
# inventory/dev/host_vars/ubuntu2/main.yml
ansible_host: 192.168.56.12
ansible_ssh_private_key_file: ~/.vagrant.d/insecure_private_key
```

## Managing Encrypted Passwords

### Creating Encrypted Passwords

1. Create a vault password file (Example password shown for demonstration):
   ```bash
   echo "ExamplePassword123" > .vault_pass
   chmod 600 .vault_pass
   ```

2. Add vault password file to .gitignore:
   ```bash
   echo ".vault_pass" >> .gitignore
   ```

   Important: Always keep your vault password secure and never commit it to version control!

3. Encrypt a password:
   ```bash
   ansible-vault encrypt_string 'vagrant' --name 'ansible_password' --vault-password-file .vault_pass
   ```

4. Add the encrypted string to your host vars file:
   ```yaml
   ansible_password: !vault |
     $ANSIBLE_VAULT;1.1;AES256
     [encrypted string]
   ```

### Running Playbooks with Encrypted Passwords

1. Using a vault password file:
   ```bash
   ansible-playbook -i inventory/dev/inventory.yml site.yml --vault-password-file .vault_pass
   ```

2. Entering password manually:
   ```bash
   ansible-playbook -i inventory/dev/inventory.yml site.yml --ask-vault-pass
   ```

## Test Environment Setup

1. Create test VMs:
   ```bash
   vagrant destroy -f  # Clean up any existing VMs
   vagrant up         # Create new VMs
   ```

2. Test Ansible connection:
   ```bash
   # Test password authentication
   ansible ubuntu1 -i inventory/dev/inventory.yml -m ping --vault-password-file .vault_pass

   # Test SSH key authentication
   ansible ubuntu2 -i inventory/dev/inventory.yml -m ping
   ```

## Best Practices for Password Management

1. **Never store unencrypted passwords**
   - Always use Ansible Vault for passwords
   - Keep vault passwords secure and separate from the repository

2. **Use different vault passwords per environment**
   - Create separate vault password files for dev and prod
   - Distribute vault passwords securely to team members

3. **Regular password rotation**
   - Regularly update passwords
   - Re-encrypt with new vault passwords when rotating

4. **Secure vault password storage**
   - Store vault passwords in a secure password manager
   - Never commit vault password files to version control
   - Add .vault_pass to .gitignore

## References
- https://github.com/joelhandwell/ubuntu_vagrant_boxes/issues/1#issuecomment-292370353
- https://stackoverflow.com/a/40325864
- https://docs.ansible.com/ansible/latest/vault_guide/index.html
- https://docs.ansible.com/ansible/latest/user_guide/connection_details.html