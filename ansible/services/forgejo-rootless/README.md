# Forgejo Rootless Ansible Configuration

This Ansible configuration manages the deployment of a rootless Forgejo instance using Docker Compose.

## Directory Configuration

Forgejo requires data and configuration directories to store its contents. These are configured with the following variables:

- `forgejo_data_dir`: Path to the data directory (default: "./data")
- `forgejo_conf_dir`: Path to the configuration directory (default: "./conf")

### Path Resolution

The role automatically handles different path formats:

- `forgejo_project_src`: Base directory for all Forgejo components (default: `{{ ansible_user_dir }}/Docker/forgejo-rootless`)

Paths for data and config directories are resolved as follows:

1. **Absolute Paths**: If a path starts with "/", it's treated as an absolute path and used as-is.
   ```yaml
   forgejo_data_dir: "/var/lib/forgejo/data"  # Used exactly as provided
   ```

2. **Relative Paths with "./"**: If a path starts with "./", it's appended to the project source with the leading "./" removed.
   ```yaml
   forgejo_data_dir: "./data"  # Resolved to "{{ forgejo_project_src }}/data"
   ```

3. **Other Paths**: Paths that don't match the above patterns default to subdirectories in the project source.
   ```yaml
   forgejo_data_dir: "data"  # Defaults to "{{ forgejo_project_src }}/data"
   ```

The role creates these directories and ensures they have the correct ownership (1000:1000) before starting the Forgejo service, which is required for the rootless container to function properly.

## Backup and Restore

The role includes comprehensive backup and restore functionality for both Forgejo and its PostgreSQL database. 

For detailed backup and restore documentation, please see [BACKUP.md](./BACKUP.md).

### Quick Reference

- **Running a standard backup**:
  ```bash
  ansible-playbook site.yml -i inventories/[env]/hosts.yml --tags "backup"
  ```

- **Running a backup before updates** (service remains stopped):
  ```bash
  ansible-playbook site.yml -i inventories/[env]/hosts.yml --tags "backup" -e "forgejo_update_mode=true"
  ```

## Mailer Configuration

The Forgejo mailer service is configured using several variables. The mailer will only be enabled if all required variables are defined. If any of the required mailer variables are missing, the mailer service will be automatically disabled in the Forgejo configuration.

### Required Variables

All of the following variables must be defined for the mailer to work:

- `forgejo_mailer_smtp_addr`: SMTP server address (e.g., 'smtp.example.com')
- `forgejo_mailer_smtp_port`: SMTP server port (e.g., 465 for SMTPS)
- `forgejo_mailer_user`: SMTP username (e.g., 'username@example.com')
- `forgejo_mailer_password`: SMTP password

### Optional Variables

These variables have default values but can be overridden:

- `forgejo_mailer_from`: Email address shown as sender (default: 'forgejo@domain.com' where domain.com is extracted from the SMTP username)
- `forgejo_mailer_protocol`: Mail protocol to use (default: 'smtps')

### Configuration in Inventory

Edit the appropriate inventory file (dev or prod) to configure the mailer. Example configuration in group_vars/all/main.yml:

```yaml
# Forgejo Mailer Configuration
forgejo_mailer_smtp_addr: 'smtp.example.com'
forgejo_mailer_smtp_port: 465
forgejo_mailer_user: 'username@example.com'
forgejo_mailer_password: 'your_password'
forgejo_mailer_from: 'forgejo@example.com'  # Optional
forgejo_mailer_protocol: 'smtps'  # Optional
```

### Implementation Details

The Ansible role creates a variable `use_forgejo_mailer` that checks if all required mailer configuration variables are defined:

```yaml
use_forgejo_mailer: "{{ forgejo_mailer_smtp_port is defined and forgejo_mailer_smtp_addr is defined and forgejo_mailer_user is defined and forgejo_mailer_password is defined }}"
```

This variable is then used in the docker-compose template to conditionally enable or disable the mailer configuration.

## Deployment

The deployment uses Docker Compose to create and manage the Forgejo containers. The configuration is templated using Ansible's Jinja2 templating system, which conditionally enables or disables features based on the provided variables.

## Security Note

The mailer password is stored as a Docker secret. Ensure that the secrets directory is properly secured and that access to the server is restricted to authorized personnel only.
