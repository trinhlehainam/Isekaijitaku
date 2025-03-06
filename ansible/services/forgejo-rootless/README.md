# Forgejo Rootless Ansible Configuration

This Ansible configuration manages the deployment of a rootless Forgejo instance using Docker Compose.

## Table of Contents

- [Getting Started](#getting-started)
- [Directory Configuration](#directory-configuration)
- [Deployment](#deployment)
- [Database Configuration](#database-configuration)
- [Mailer Configuration](#mailer-configuration)
- [Backup and Restore](#backup-and-restore)
- [Security Note](#security-note)

## Getting Started

### Prerequisites

- Ansible 2.9 or higher
- Target server with Docker and Docker Compose installed
- SSH access to the target server

### Quick Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd forgejo-rootless
   ```

2. Install required Ansible roles:
   ```bash
   ansible-galaxy install -r requirements.yml
   ```

3. Deploy to your target environment (dev or prod):
   ```bash
   ansible-playbook site.yml -i inventories/dev/hosts.yml
   ```

By default, Forgejo will be available at http://localhost:3000 or according to your configured domain if using Traefik.

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

### Deployment Process

The deployment process follows these steps:

1. Creates necessary directories for the Forgejo service (project source, data, configuration, secrets)
2. Ensures proper ownership and permissions for all directories
3. Creates required Docker network
4. Prepares database and mailer password files in the secrets directory
5. Generates the Docker Compose configuration file from templates
6. Starts all containers using Docker Compose
7. Logs the status of all deployed services for verification

### Service Status Logging

After deployment, the role automatically logs the status of all containers to help verify successful deployment. This information is displayed in the Ansible output as debug messages, showing each service name and its current state (e.g., running, exited).

Example output:

```
TASK [common : Log service status] ***********************************************
ok: [server] => (item=forgejo) => {
    "msg": "forgejo: running"
}
ok: [server] => (item=forgejo-db) => {
    "msg": "forgejo-db: running"
}
```

This logging helps quickly identify any issues with container startup and confirms that all required services are running as expected. Status information is obtained through Docker Compose and includes:

- Container service name (e.g., forgejo, forgejo-db)
- Current state (running, exited, etc.)
- Any startup errors or issues

## Troubleshooting

### Common Issues

1. **Database Password Issues**
   - Verify that the `db_password` variable is correctly set in your inventory
   - Check that the `.vault_pass` file is present and has the correct password (for development: `ExamplePassword1234`)
   - Ensure the secrets directory and password files have proper permissions

2. **Container Startup Failures**
   - Check service status using the debug output from the role
   - View detailed container logs: `docker logs forgejo` or `docker logs forgejo-db`
   - Verify that all required directories have correct ownership (1000:1000 for Forgejo)

3. **PostgreSQL Connection Issues**
   - Check that the database container is running: `docker ps | grep forgejo-db`
   - Verify the database password is correctly passed to both containers
   - Inspect PostgreSQL logs: `docker logs forgejo-db`

### Viewing Service Logs

To view detailed service logs after deployment:

```bash
# View Forgejo logs
docker logs forgejo

# View PostgreSQL logs
docker logs forgejo-db

# Follow logs in real-time
docker logs forgejo -f
```

## Database Configuration

Forgejo uses PostgreSQL as its database backend. The database configuration is managed through Docker containers and requires secure password handling.

### PostgreSQL Variables

- `db_user`: Database user for Forgejo (default: "forgejo")
- `db_name`: Database name for Forgejo (default: "forgejo")
- `db_password`: Encrypted password for database access
- `postgres_data_dir`: Path to store PostgreSQL data (default: "./postgres")

### Password Management

- The database password is defined in the inventory's group variables (e.g., `inventories/dev/group_vars/all/main.yml`) as an encrypted variable named `db_password`.
- For local development with Vagrant VMs, a `.vault_pass` file is provided with an example password.
- The Ansible configuration (`ansible.cfg`) is set up to automatically use this vault password file via the setting `vault_password_file = .vault_pass`.
- During deployment, the role creates a `secrets/db_password` file containing the decrypted password value.
- This file is then mounted as a Docker secret in the containers.

### Docker Integration

The PostgreSQL container is configured to use the password file:

```yaml
POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

The Forgejo container accesses the same password through environment variables:

```bash
export FORGEJO__database__PASSWD=$$(cat /run/secrets/db_password)
```

### Local Development

For local development:

1. The `.vault_pass` file contains the password used to encrypt/decrypt sensitive variables.
   - For local development with Vagrant VMs, the example password is `ExamplePassword1234`.
2. The `db_password` variable in `inventories/dev/group_vars/all/main.yml` is already encrypted using this password.
3. You don't need to create your own password file or re-encrypt the variables.

If you need to decrypt the variables manually for testing, you can use the following command:

```bash
ansible-vault decrypt --vault-password-file .vault_pass inventories/dev/group_vars/all/main.yml
```

Or to view the decrypted content without modifying the file:

```bash
ansible-vault view --vault-password-file .vault_pass inventories/dev/group_vars/all/main.yml
```

### Implementation Details

The role performs the following steps to handle database authentication:

1. Creates a `secrets` directory in the project source directory.
2. Writes the decrypted `db_password` value to `secrets/db_password`.
3. Configures the PostgreSQL container to read this password file.
4. Configures the Forgejo container to access the PostgreSQL database using this password.

## Security Note

The database and mailer passwords are stored as Docker secrets. Ensure that the secrets directory is properly secured and that access to the server is restricted to authorized personnel only.
