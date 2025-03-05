# Forgejo Rootless Ansible Configuration

This Ansible configuration manages the deployment of a rootless Forgejo instance using Docker Compose.

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

- `forgejo_mailer_from`: Email address shown as sender (default: 'forgejo@example.com')
- `forgejo_mailer_protocol`: Mail protocol to use (default: 'smtps')

### Configuration in Inventory

Edit the appropriate inventory file (dev or prod) to configure the mailer. By default, sample values are provided but commented out. Uncomment and adjust the values to enable the mailer service.

Example in inventories/dev/group_vars/all/main.yml:
```yaml
# Forgejo Mailer Configuration
forgejo_mailer_smtp_addr: 'smtp.example.com'
forgejo_mailer_smtp_port: 465
forgejo_mailer_user: 'username@example.com'
forgejo_mailer_password: 'your_password'
forgejo_mailer_from: 'forgejo@example.com'
forgejo_mailer_protocol: 'smtps'
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
