# Dozzle Docker Monitoring with Ansible

This Ansible project sets up a Dozzle monitoring system with a manager-agent architecture using Docker containers. Dozzle provides a real-time web interface to view and search Docker container logs across multiple hosts from a single dashboard.

## System Architecture

The setup implements a manager-agent architecture where:

- **Manager Node**: Central server that collects and displays logs from all Docker containers (local and remote)
- **Agent Nodes**: Servers that expose their Docker container logs to the manager

This architecture enables centralized log monitoring across your entire Docker infrastructure, eliminating the need to access each server individually.

## Project Structure

```
ansible/docker/dozzle/
├── inventories/                # Inventory definitions
│   ├── dev/                    # Development environment
│   │   ├── hosts.yml           # Defines manager and agent groups
│   │   └── group_vars/         # Variables for inventory groups
├── roles/
│   └── common/                 # Shared role for both manager and agent nodes
│       ├── tasks/              # Tasks for deploying Dozzle
│       └── templates/          # Docker Compose templates
│           ├── docker-compose-agent.yml.j2
│           └── docker-compose-manager.yml.j2
├── Vagrantfile                 # Creates test VMs (ubuntu1, ubuntu2, ubuntu3)
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Required roles and collections
└── site.yml                    # Main playbook
```

## Development Environment

> **Note**: The current configuration is specifically designed for development and testing using Vagrant VMs. For production deployment, additional configuration would be required.

### Test Infrastructure

The included Vagrantfile creates three Ubuntu 22.04 (Jammy) VMs:
- **ubuntu1 (192.168.56.11)**: Manager node
- **ubuntu2 (192.168.56.12)**: Agent node
- **ubuntu3 (192.168.56.13)**: Agent node

These VMs provide an isolated environment to test the Dozzle manager-agent setup without affecting your production systems.

### Software Stack

- **Docker**: Installed via geerlingguy.docker role (v7.4.5)
- **Docker Compose**: Used via the community.docker collection (v4.4.0)
- **Dozzle**: v8.11.7 (amir20/dozzle image)
- **Traefik** (Optional): For routing and TLS termination

## Prerequisites

- Ansible 2.9+
- Vagrant 2.2+ and VirtualBox 6.0+ (for testing)
- SSH access to target servers
- Traefik (optional) configured and running for proxy setup

## Quick Start

### 1. Install Required Roles and Collections

```bash
ansible-galaxy install -r requirements.yml
```

### 2. Start Test Environment

```bash
vagrant up
```

This creates the three Ubuntu VMs described above in the test infrastructure section.

### 3. Deploy Dozzle

```bash
ansible-playbook -i inventories/dev/hosts.yml site.yml
```

### 4. Access the Dashboard

After deployment, access the Dozzle web interface at:

```
http://192.168.56.11:8080
```

Or, if using Traefik:

```
https://dozzle.yourdomain.local  # Internal access
https://dozzle.yourdomain.com    # Public access
```

## Deployment Workflow

The deployment process follows these steps:

1. **Docker Installation**:
   - Docker is installed on all nodes using the geerlingguy.docker role
   - The ansible user is added to the docker group for non-root access

2. **Agent Deployment**:
   - Dozzle agents are deployed on designated agent nodes
   - Docker Compose files are created in the user's home directory under Docker/dozzle_agent/
   - Agents expose port 7007 for manager connection

3. **Manager Deployment**:
   - Agent information is collected and formatted as a connection string
   - Dozzle manager is deployed with the agent connection string
   - Docker Compose files are created in the user's home directory under Docker/dozzle/
   - Manager either exposes port 8080 for direct web access or integrates with Traefik

## Configuration Templates

The Docker Compose configurations are managed through Ansible templates:

- **Agent Configuration**: [`roles/common/templates/docker-compose-agent.yml.j2`](roles/common/templates/docker-compose-agent.yml.j2)
- **Manager Configuration**: [`roles/common/templates/docker-compose-manager.yml.j2`](roles/common/templates/docker-compose-manager.yml.j2)

These templates are processed by Ansible and deployed to each node based on its role (manager or agent).

## Key Configuration Parameters

- **Agent Port**: 7007 (used for manager-agent communication)
- **Manager Web Interface Port**: 8080 (when not using Traefik)
- **Docker Socket Mount**: Required for accessing container logs
- **Agent Connection String**: Automatically generated based on agent inventory

### Traefik Integration

The setup supports integration with Traefik as a reverse proxy with the following configuration options:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `use_traefik` | Enable Traefik integration | `false` |
| `service_name` | Service name (used as subdomain) | `dozzle` |
| `traefik_router_public` | Enable public-facing router | `false` |
| `traefik_router_private` | Enable private/internal router | `false` |
| `public_apex_domain` | Root domain for public access (without subdomain) | - |
| `private_apex_domain` | Root domain for private access (without subdomain) | - |

Example inventory configuration (in `group_vars/all/main.yml`):

```yaml
# Traefik configuration
use_traefik: true

# Router configuration
traefik_router_public: true
traefik_router_private: true

# Service name (will be used as subdomain)
service_name: "dozzle"

public_apex_domain: "yourdomain"
private_apex_domain: "yourdomain.local"
```

With this configuration, Dozzle would be accessible at:
- Public URL: `https://dozzle.yourdomain`
- Private URL: `https://dozzle.yourdomain.local`

When Traefik integration is enabled:
- Direct port exposure (8080) is disabled
- The container is connected to the `proxy` network (must exist as an external network)
- Labels are added to configure Traefik routing based on the specified variables
- Both router types (public and private) require their respective apex domains to be defined
- Fixed certificate resolvers are used: `cloudflare` for public and `stepca` for private
- Fixed middleware `oauth2-admin@file` is used for both public and private routers

## Verification and Testing

After deployment, verify the setup with these steps:

1. Check container status on all nodes:
   ```bash
   # On manager node (ubuntu1)
   vagrant ssh ubuntu1 -c "docker ps | grep dozzle"
   
   # On agent nodes (ubuntu2, ubuntu3)
   vagrant ssh ubuntu2 -c "docker ps | grep dozzle-agent"
   vagrant ssh ubuntu3 -c "docker ps | grep dozzle-agent"
   ```

2. Access the web interface:
   - Direct access: http://192.168.56.11:8080
   - Via Traefik (if configured): 
     - Public: https://dozzle.yourdomain.com
     - Private: https://dozzle.yourdomain.local

3. Check logs from containers on all connected nodes appear in the interface

## Adapting for Production

To adapt this setup for production environments, consider:

1. **Security Enhancements**:
   - Implement TLS for manager-agent communication
   - Set up authentication for the web interface
   - Use Traefik for HTTPS and authentication

2. **Infrastructure Changes**:
   - Create a production inventory with your actual server hostnames/IPs
   - Implement network security measures appropriate for your environment
   - Consider high-availability configurations for critical components

3. **Configuration Management**:
   - Store sensitive configuration in encrypted Ansible vault files
   - Adjust Docker Compose templates for production-specific requirements
   - Implement proper logging and monitoring solutions

## Troubleshooting

Common issues when testing with Vagrant:

1. **VM Connectivity Issues**:
   - Ensure all VMs are running: `vagrant status`
   - Check VM network configuration: `vagrant ssh ubuntu1 -c "ip addr"`

2. **Docker Container Problems**:
   - Check container logs: `vagrant ssh ubuntu1 -c "docker logs dozzle"`
   - Verify Docker is running: `vagrant ssh ubuntu1 -c "systemctl status docker"`

3. **Agent-Manager Connection Issues**:
   - Verify network connectivity between VMs
   - Check agent configuration in the manager's environment variables
   - Inspect agent logs: `vagrant ssh ubuntu2 -c "docker logs dozzle-agent"`

4. **Traefik Integration Issues**:
   - Verify the `proxy` network exists and is properly configured
   - Check Traefik logs for routing issues
   - Confirm DNS resolution for the configured domains
   - Ensure both apex domains and service name are properly defined

## References

- [Dozzle Documentation](https://dozzle.dev/)
- [Dozzle Agent Setup Guide](https://dozzle.dev/guide/agent)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
