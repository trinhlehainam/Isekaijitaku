# Dozzle Docker Monitoring with Ansible

This Ansible project sets up a Dozzle monitoring system with a manager-agent architecture using Docker containers. Dozzle provides a web interface to view and search Docker container logs.

## Architecture

The setup consists of:

- **Manager Node**: Runs the main Dozzle instance that connects to agent nodes and provides a unified web interface for all container logs
- **Agent Nodes**: Run Dozzle agent instances that collect logs from their local Docker containers and expose them to the manager

## Prerequisites

- Ansible 2.9+
- Vagrant and VirtualBox (for testing)
- SSH access to target servers

## Setup Instructions

### 1. Install Required Roles and Collections

```bash
ansible-galaxy install -r requirements.yml
```

### 2. Testing with Vagrant

The project includes a Vagrantfile that creates 3 Ubuntu VMs:
- ubuntu1: Dozzle manager
- ubuntu2, ubuntu3: Dozzle agents

To start the test environment:

```bash
vagrant up
```

### 3. Deploy Dozzle

Run the playbook to deploy Dozzle to all nodes:

```bash
ansible-playbook -i inventories/dev/hosts.yml site.yml
```

The playbook will:
1. Install Docker on all servers using the geerlingguy.docker role
2. Deploy Dozzle agents on the agent nodes
3. Collect agent information (IP addresses and ports)
4. Deploy the Dozzle manager with connections to all agents

### 4. Accessing Dozzle

After deployment, access the Dozzle web interface at:

```
http://192.168.56.11:8080
```

## How It Works

1. The playbook first deploys Dozzle agents on the specified agent nodes
2. It collects the IP addresses and ports of all agents
3. It then deploys the Dozzle manager, configuring it to connect to all agents
4. The manager provides a unified web interface to view logs from all containers across all nodes

## Configuration

- Agent nodes expose port 7007 for manager connection
- Manager node exposes port 8080 for web interface access
- Docker socket is mounted to allow Dozzle to access container logs

## Troubleshooting

- Check Docker container status: `docker ps`
- View Dozzle container logs: `docker logs dozzle` or `docker logs dozzle-agent`
- Verify connectivity between manager and agent nodes
- Ensure Docker is running on all nodes

## Security Considerations

- The Docker socket is mounted inside containers, which gives Dozzle full access to the Docker daemon
- In production environments, consider implementing proper network security and access controls
- For secure external access, consider setting up a reverse proxy with TLS
