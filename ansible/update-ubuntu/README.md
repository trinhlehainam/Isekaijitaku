# Ubuntu Update Management with Ansible

Demonstrates Ansible configuration for managing Ubuntu VMs using both password and SSH key authentication methods, including sudo privilege escalation.

## Project Structure

```
.
├── inventories/
│   └── dev/                  # Development environment
│       ├── group_vars/       # Common settings for all hosts
│       ├── host_vars/        # Host-specific settings
│       │   ├── ubuntu1/      # Password auth + sudo example
│       │   ├── ubuntu2/      # SSH key auth example
│       │   └── ubuntu3/      # SSH key auth example
│       └── hosts.yml         # inventories file
└── README.md
```

## Host Configuration

### Common Settings (All Hosts)
```yaml
# inventories/dev/group_vars/ubuntu_servers/main.yml
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
ansible_python_interpreter: /usr/bin/python3
ansible_user: vagrant
ansible_ssh_private_key_file: ~/.vagrant.d/insecure_private_key
```

### Password Authentication with Sudo (ubuntu1)
```yaml
# inventories/dev/host_vars/ubuntu1/main.yml
ansible_host: 192.168.56.11
ansible_user: dummy              # Custom user with sudo access
ansible_password: !vault |       # SSH password
ansible_become_password: !vault | # Sudo password
```

### SSH Key Authentication (ubuntu2)
```yaml
# inventories/dev/host_vars/ubuntu2/main.yml
ansible_host: 192.168.56.12
```

### SSH Key Authentication (ubuntu3)
```yaml
# inventories/dev/host_vars/ubuntu3/main.yml
ansible_host: 192.168.56.13
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

## Running Playbook Roles

Each role can be run independently using tags. Here's how to run each role:

### 1. Check Updates (check)
Checks system for available updates and removes unattended-upgrades:
```bash
# Check updates on all hosts
ansible-playbook -i inventories/dev/hosts.yml site.yml -t check -b

# Check updates on specific host
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  -t check -b \
  --limit ubuntu1

### 2. Security Updates (security)
Applies security updates only, removes unused packages (`autoremove`), and cleans the package cache (`autoclean`):
```bash
# Apply security updates on all hosts
ansible-playbook -i inventories/dev/hosts.yml site.yml -t security -b

# Apply security updates on specific host
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  -t security -b \
  --limit ubuntu1

### 3. System Updates (update)
Performs full system update, removes unused packages (`autoremove`), and cleans the package cache (`autoclean`):
```bash
# Update all hosts
ansible-playbook -i inventories/dev/hosts.yml site.yml -t update -b

# Update specific host
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  -t update -b \
  --limit ubuntu1

### 4. System Reboot (reboot)
Reboots system if required after updates:
```bash
# Check and reboot all hosts if needed
ansible-playbook -i inventories/dev/hosts.yml site.yml -t reboot -b

# Check and reboot specific host if needed
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  -t reboot -b \
  --limit ubuntu1

### Running Multiple Roles
You can combine multiple roles by specifying multiple tags:
```bash
# Run check and security updates only
ansible-playbook -i inventories/dev/hosts.yml site.yml -t check,security -b

# Full update cycle (all roles)
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  -t check,security,update,reboot -b

### Role Output Examples

1. Check Updates Output:
   ```
   Check Update Status:
   - Unattended-upgrades has been removed
   - Available Updates:
     - package1/updates 1.2.3-1 amd64
     - package2/security 2.3.4-2 amd64
   ```

2. Security Updates Output:
   ```
   Security Update Summary:
   - Security updates applied: True
   - Changed packages: 2
   - Packages requiring reboot:
     - linux-image-generic
     - dbus
   ```

3. System Updates Output:
   ```
   Full System Update Summary:
   - Updates applied: True
   - Changed packages: 5
   - Packages requiring reboot:
     - linux-image-generic
     - linux-headers-generic
   ```

4. Reboot Status Output:
   ```
   Reboot Status:
   - Reboot required: True
   - Packages requiring reboot: 3
   ```

## Implementation Notes

### Reboot Role Implementation

The reboot role has been simplified to use a more elegant approach for handling dependencies between hosts:

1. **Checking Reboot Requirements**:
   - The role checks for the presence of `/var/run/reboot-required` to determine if a reboot is needed
   - It also reads the list of packages that require a reboot from `/var/run/reboot-required.pkgs`

2. **Reboot Control**:
   - Hosts with `ignore_reboot: true` will be excluded from rebooting
   - For hosts without dependencies, the reboot process is straightforward
   - For hosts with dependencies (defined via `wait_for_inventories_hostname`), the role:
     - Creates a temporary status directory to track reboot status
     - Waits for the dependent host to complete its reboot by checking for a status file
     - Verifies the dependent host is fully operational by checking network connectivity
     - Only then proceeds with its own reboot

3. **Status Tracking**:
   - Each host creates a status file in `/tmp/ansible_reboot_control/` after successfully rebooting
   - The directory is cleaned up when all hosts have been processed

4. **Benefits of this Approach**:
   - Flexible control over which hosts should reboot with the `ignore_reboot` flag
   - No need for complex marker files or SSH connectivity checks
   - Clear separation of concerns between reboot logic and dependency management
   - Improved reliability with two-phase verification (file existence and network connectivity)
   - Simplified cleanup process

## Reboot Orchestration

The playbook includes a reboot role that handles system reboots when required. The role checks for the presence of the `/var/run/reboot-required` file, which indicates that a reboot is needed after package updates.

### Reboot Dependencies

In some cases, you may want to ensure that certain hosts reboot before others. For example, if you have a database server that needs to be back online before application servers reboot. This is handled through the `wait_for_inventories_hostname` variable.

### Ignoring Reboots

Some hosts may need to be excluded from reboots due to maintenance windows, critical operations, or other constraints. You can exclude a host from rebooting by setting the `ignore_reboot` variable to `true` in the host's variables.

#### How it works

1. Define the `wait_for_inventories_hostname` variable in the host vars for any host that should wait for another host to reboot first.
2. Set the `ignore_reboot` variable to `true` for any host that should not reboot, even if a reboot is required.
3. The reboot role will:
   - Check if a reboot is required
   - Skip hosts that have `ignore_reboot` set to `true`
   - Create a temporary status directory to track reboot status
   - For hosts without dependencies, reboot immediately
   - For hosts with a `wait_for_inventories_hostname` defined:
     - Wait for that host to complete its reboot (by checking for a status file)
     - Verify the host is online by checking network connectivity
     - Then proceed with its own reboot
   - Create a status file to indicate successful reboot
   - Clean up all status files when all hosts have been processed

#### Example Configuration

To make `ubuntu3` wait for `ubuntu1` to reboot first:

```yaml
# inventories/dev/host_vars/ubuntu3/main.yml
wait_for_inventories_hostname: ubuntu1
```

To prevent `ubuntu2` from rebooting:

```yaml
# inventories/dev/host_vars/ubuntu2/main.yml
ignore_reboot: true
```

The reboot role will automatically handle the dependency, ensuring that `ubuntu3` waits for `ubuntu1` to complete its reboot before proceeding with its own reboot, while `ubuntu2` will be skipped entirely.

### Testing

To test the reboot orchestration:

1. Ensure all VMs are running:
   ```
   vagrant up
   ```

2. Run the test script:
   ```
   ./tests/vagrant_reboot_test.sh
   ```

The test script will:
- Clean up any existing reboot status files
- Create reboot-required files on all VMs
- Run the playbook with the reboot tag
- Verify that all hosts have been rebooted successfully
- Check that the reboot status files have been properly cleaned up

The test is successful if:
1. All hosts are rebooted
2. ubuntu3 waits for ubuntu1 to reboot before proceeding
3. All temporary status files are cleaned up after the process

## Playbook Tags

The playbook includes the following tags for granular control:

### check
- Disables and removes unattended-upgrades
- Updates apt cache
- Lists available package updates

### security
- Applies security updates only
- Removes unused packages (`autoremove`)
- Cleans the package cache (`autoclean`)
- Checks for required reboots
- Lists packages requiring reboot

### update
- Performs full system update
- Removes unused packages (`autoremove`)
- Cleans the package cache (`autoclean`)
- Checks for required reboots
- Lists packages requiring reboot

### reboot
- Checks if reboot is required
- Lists packages requiring reboot
- Supports excluding hosts from rebooting with `ignore_reboot: true`
- Supports dependent reboots using `wait_for_inventories_hostname`
- Uses a two-phase verification for dependent hosts:
  - Checks for a status file indicating the dependent host has rebooted
  - Verifies network connectivity to ensure the host is fully operational
- Performs controlled reboots with proper timeouts

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
ansible-vault encrypt_string 'your_password' --name 'ansible_password'

# Encrypt sudo password
ansible-vault encrypt_string 'your_sudo_password' --name 'ansible_become_password'
```

### Reboot Examples
```bash
# Reboot all hosts respecting priorities and wait conditions
ansible-playbook -i inventories/dev/hosts.yml site.yml -t reboot

# Reboot specific hosts
ansible-playbook -i inventories/dev/hosts.yml site.yml -t reboot --limit ubuntu1,ubuntu3

# Check reboot status without actually rebooting (dry run)
ansible-playbook -i inventories/dev/hosts.yml site.yml -t reboot --check
```

### Run Commands
```bash
# Test all hosts
ansible all -i inventories/dev/hosts.yml -m ping

# Run specific tags
# Run check and security updates only
ansible-playbook -i inventories/dev/hosts.yml site.yml -t check,security -b

# Run full playbook
ansible-playbook -i inventories/dev/hosts.yml site.yml

# Run on specific host with privilege escalation
ansible-playbook -i inventories/dev/hosts.yml site.yml \
  --limit ubuntu1 -b
```

## Security Best Practices

1. Always encrypt sensitive data with Ansible Vault
2. Store vault passwords securely, never in version control
3. Use SSH key authentication when possible
4. Configure sudo access with appropriate restrictions
5. Regularly rotate passwords and update vault values
6. Use separate users for different roles/responsibilities