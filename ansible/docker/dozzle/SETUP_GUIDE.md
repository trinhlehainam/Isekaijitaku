# Dozzle Docker Monitoring Setup Guide

This guide provides detailed instructions for setting up a Dozzle Docker monitoring system with a manager-agent architecture using Ansible.

## System Architecture

Dozzle is a real-time log viewer for Docker containers. This setup implements a manager-agent architecture where:

- **Manager Node**: Central server that collects and displays logs from all agents
- **Agent Nodes**: Servers that run Docker containers and expose their logs to the manager

The architecture allows for centralized monitoring of Docker containers across multiple hosts from a single web interface.

## Implementation Details

### Components

1. **Vagrant VMs**:
   - Three Ubuntu 22.04 (Jammy) VMs for testing
   - ubuntu1 (192.168.56.11): Manager node
   - ubuntu2 (192.168.56.12) and ubuntu3 (192.168.56.13): Agent nodes

2. **Docker**:
   - Installed using geerlingguy.docker Ansible role
   - Docker Compose for container orchestration

3. **Dozzle**:
   - Version: v8.11.7
   - Manager container exposes port 8080 for web interface
   - Agent containers expose port 7007 for manager connection

### Ansible Structure

- **Inventory**: Defines manager and agent groups with their respective hosts
- **Roles**:
  - geerlingguy.docker: External role for Docker installation
  - common: Custom role for Dozzle deployment
- **Templates**:
  - docker-compose-agent.yml.j2: Template for agent Docker Compose file
  - docker-compose-manager.yml.j2: Template for manager Docker Compose file
- **Playbook**: Orchestrates the entire deployment process

## Deployment Workflow

The deployment follows these steps:

1. **Docker Installation**:
   - Install Docker on all nodes using the geerlingguy.docker role
   - Ensure Docker service is running

2. **Agent Deployment**:
   - Deploy Dozzle agents on designated agent nodes
   - Configure agents to expose port 7007
   - Mount Docker socket to access container logs

3. **Information Collection**:
   - Collect IP addresses and ports of all agent nodes
   - Create a connection string in the format: `agent1_ip:7007,agent2_ip:7007,...`

4. **Manager Deployment**:
   - Deploy Dozzle manager with the collected agent connection string
   - Configure manager to expose port 8080 for web access
   - Mount Docker socket for local container logs

## Configuration Details

### Agent Configuration

The agent Docker Compose file includes:
- Image: amir20/dozzle:v8.11.7
- Command: agent (runs in agent mode)
- Hostname: Set to the inventory hostname
- Port: 7007 exposed for manager connection
- Docker socket mounted as read-only
- Healthcheck configured for reliability

### Manager Configuration

The manager Docker Compose file includes:
- Image: amir20/dozzle:v8.11.7
- Hostname: Set to the inventory hostname
- DOZZLE_REMOTE_AGENT environment variable: Contains connection string to all agents
- Port: 8080 exposed for web interface
- Docker socket mounted for local container logs
- Healthcheck configured for reliability

## Testing and Verification

After deployment, verify the setup by:

1. Checking container status on all nodes
2. Accessing the web interface at http://192.168.56.11:8080
3. Verifying that logs from all nodes are visible in the interface
4. Running test containers on agent nodes to confirm log collection

## Production Considerations

For production deployment, consider:

1. **Security**:
   - Implement TLS for manager-agent communication
   - Set up a reverse proxy with HTTPS for web interface
   - Implement proper authentication for web access
   - Consider network segmentation for agent-manager communication

2. **Scaling**:
   - The architecture supports adding more agent nodes as needed
   - Update the inventory and rerun the playbook to add new agents

3. **Monitoring**:
   - Set up monitoring for the Dozzle containers themselves
   - Configure alerts for agent disconnections

4. **Backup**:
   - Consider persistent storage for Dozzle if configuration needs to be preserved

## Troubleshooting

Common issues and solutions:

1. **Agent Connection Issues**:
   - Verify network connectivity between manager and agents
   - Check firewall rules to ensure port 7007 is accessible
   - Inspect agent container logs for connection errors

2. **Docker Socket Access**:
   - Ensure the Docker socket is properly mounted in containers
   - Check permissions on the Docker socket file

3. **Web Interface Not Accessible**:
   - Verify the manager container is running
   - Check if port 8080 is exposed and accessible
   - Inspect manager container logs for errors
