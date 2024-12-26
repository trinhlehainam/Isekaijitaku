# Forgejo Runner Setup Guide

This guide explains how to set up and register a Forgejo runner for your CI/CD workflows.

## Prerequisites
- Docker and Docker Compose installed
- Access to Forgejo dashboard with admin privileges
- The Forgejo instance running via docker-compose

## Steps to Register Runner

### 1. Register Runner on Forgejo Instance

There are two ways to register a runner:

#### Option 1: Using Runner Token (from Web UI)
1. Log in to your Forgejo dashboard
2. Go to Site Administration → Actions → Runners
3. Click "Create new runner token"
4. Copy the generated token

#### Option 2: Using Runner Secret (CLI Method)
1. Generate a 40-character hexadecimal secret string:

```bash
# Method 1: Using openssl (recommended)
# Generate 20 random bytes and convert to 40 hex characters
openssl rand -hex 20

# Method 2: Using /dev/urandom and hexdump
head -c 20 /dev/urandom | hexdump -v -e '/1 "%02x"'
```

The generated secret will be a 40-character hexadecimal string where:
- First 16 characters: Runner identifier (first 8 bytes)
- Last 24 characters: Actual secret (last 12 bytes)

Example output: `7c31591e8b67225a116d4a4519ea8e507e08f71f`

> Note: Save both parts of the secret. You can update the runner later by keeping the same 16-character identifier and only changing the 24-character secret portion.

To update an existing runner's secret:
```bash
# Generate initial 40-character secret
FULL_SECRET=$(openssl rand -hex 20)

# Extract runner ID (first 16 characters) using cut or head
RUNNER_ID=$(echo $FULL_SECRET | cut -c1-16)
# OR using head
RUNNER_ID=$(echo $FULL_SECRET | head -c16)

# Generate new 24-character secret
NEW_SECRET=$(openssl rand -hex 12)  # Generates 24 characters (12 bytes)

# Combine runner ID with new secret
NEW_FULL_SECRET="${RUNNER_ID}${NEW_SECRET}"
echo "Original Secret: $FULL_SECRET"
echo "Runner ID: $RUNNER_ID"
echo "New Full Secret: $NEW_FULL_SECRET"

# Register the runner with the new secret
docker compose exec forgejo forgejo forgejo-cli actions register \
  --name "your-runner-name" \
  --scope "myorganization" \
  --secret "${NEW_FULL_SECRET}"
```

2. Register the runner on your Forgejo instance:
```bash
# Execute this command inside the Forgejo container
docker compose exec forgejo forgejo forgejo-cli actions register \
  --name "your-runner-name" \
  --scope "myorganization" \
  --secret "7c31591e8b67225a116d4a4519ea8e507e08f71f"
```

> Note: The `actions register` command registers the runner with the Forgejo instance, allowing it to accept this runner when it connects.

### 2. Set Up Environment Variables

Create a `.env` file in your Forgejo directory:
```bash
# Runner Registration
FORGEJO_INSTANCE_URL=http://forgejo:3000
RUNNER_NAME=your-runner-name
# Choose one of these authentication methods:
RUNNER_TOKEN=your-runner-token
# OR
RUNNER_SECRET=7c31591e8b67225a116d4a4519ea8e507e08f71f

# Runner Labels
RUNNER_LABELS="docker:docker://node:20-bullseye,ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04,ubuntu-20.04:docker://ghcr.io/catthehacker/ubuntu:act-20.04,ubuntu-18.04:docker://ghcr.io/catthehacker/ubuntu:act-18.04"
```

### 3. Configure Runner Authentication

You can configure the runner using either the token or secret method:

#### Using Runner Token
```bash
# Using environment variables
docker compose run --rm forgejo-runner register --no-interactive \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --instance "${FORGEJO_INSTANCE_URL}" \
  --labels "${RUNNER_LABELS}"
```

#### Using Runner Secret
```bash
# Using environment variables
# This command configures the runner to connect using the previously registered secret
docker compose run --rm forgejo-runner create-runner-file \
  --instance "${FORGEJO_INSTANCE_URL}" \
  --secret "${RUNNER_SECRET}" \
  --connect
```

> Note: The `create-runner-file` command configures the runner with credentials that allow it to start picking up tasks from the Forgejo instance as soon as it comes online.

### 4. Generate Configuration

After registration, generate the runner configuration:
```bash
docker compose run --rm forgejo-runner generate-config > runner/config.yml
```

> Note: These labels use catthehacker's Docker images which are specifically designed for GitHub Actions compatibility. They include:
> - Pre-installed common tools and software
> - GitHub Actions-compatible environment variables
> - Support for most GitHub Actions workflows
> - Regular security updates

Important configuration settings in `config.yml`:
```yaml
runner:
  envs:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_CERT_PATH: /certs/client
    DOCKER_TLS_VERIFY: 1
  labels: [
    "docker:docker://node:20-bullseye",
    "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04",
    "ubuntu-20.04:docker://ghcr.io/catthehacker/ubuntu:act-20.04",
    "ubuntu-18.04:docker://ghcr.io/catthehacker/ubuntu:act-18.04"
  ]

container:
  network: "host"
  # Resource constraints using Docker options
  options: >-
    -v /certs/client:/certs/client 
    -v /usr/local/share/ca-certificates/step_root_ca.crt:/usr/local/share/ca-certificates/step_root_ca.crt 
    --cpus=2.0 
    --memory=2g 
    --memory-swap=2.5g 
    --memory-reservation=1.5g
  valid_volumes:
    - /certs/client
    - /usr/local/share/ca-certificates/step_root_ca.crt
```

> Note: These settings are crucial for:
> - Secure Docker communication using TLS
> - Proper Docker-in-Docker functionality
> - Host network access for containers
> - Correct certificate mounting
> - Labels in config.yml will override the labels stored in .runner file
> - Resource constraints:
>   - CPU: Limited to 2 out of 4 vCPUs using --cpus
>   - Memory: Hard limit of 2GB with 512MB swap using --memory
>   - Memory Reservation: Soft limit of 1.5GB using --memory-reservation
>   - These limits apply to each runner container

## Resource Constraints

The runner can be configured with resource constraints using Docker options in the `config.yml`. These options are passed directly to the `docker run` command:

### Available Resource Options
```yaml
container:
  options: >-
    --cpus=2.0            # Limit to 2 CPU cores
    --memory=2g           # Hard memory limit (2GB)
    --memory-swap=2.5g    # Total memory limit including swap (2GB + 512MB)
    --memory-reservation=1.5g  # Soft memory limit (1.5GB)
```

These constraints help:
- Control resource usage for each runner container
- Prevent resource exhaustion on the host
- Ensure fair resource sharing between runners
- Maintain stable system performance

> Note: The options string uses YAML's block scalar indicator (`>-`) for better readability of multiple Docker options.
> Each option should be on a new line for clarity.

## Labels Explanation
The configured labels provide different Ubuntu environments with pre-installed tools:
- `ubuntu-22.04`: Ubuntu 22.04 with common development tools and runtimes
- `ubuntu-20.04`: Ubuntu 20.04 with common development tools and runtimes
- `ubuntu-18.04`: Ubuntu 18.04 with common development tools and runtimes

Each environment comes with:
- Multiple versions of Python, Node.js, and other programming languages
- Common build tools and utilities
- Git and version control tools
- Docker-in-Docker support
- GitHub Actions compatibility layer

## Verification
To verify the runner is working:
1. Go to Site Administration → Actions → Runners
2. You should see your newly registered runner listed as "Online"

## Troubleshooting
If the runner doesn't appear online:
1. Check the runner logs: `docker compose logs forgejo-runner`
2. Verify the runner token was entered correctly
3. Ensure the Forgejo instance is accessible from the runner container

## Testing the Runner
To test if your runner is working correctly, you can create a test workflow in your repository:

1. Create a workflow file at `.forgejo/workflows/test.yml` in your repository:
```yaml
name: Test Runner
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-22.04  # This will use the ubuntu-22.04 label we configured
    steps:
      - name: Install local root CA
        run: |
          sudo update-ca-certificates

      - uses: actions/checkout@v3
      
      - name: Test Runner Environment
        run: |
          echo "Testing runner environment..."
          pwd
          ls -la
          docker info
          node --version
      
      - name: Test Docker
        run: |
          echo "Testing docker capabilities..."
          docker run --rm hello-world
          
      - name: Test Node.js
        run: |
          echo "Testing Node.js environment..."
          node -e "console.log('Hello from Node.js', process.version)"
```

> Note: The first step `Install local root CA` is required when your runner needs to access services using local root CA certificates. This ensures that HTTPS connections to local services using custom certificates work properly.

2. Commit and push this workflow file to your repository
3. Go to your repository's Actions tab to see the workflow run
4. The workflow should run successfully and show the environment information, Docker capabilities, and Node.js version

This test workflow will verify that:
- The runner can execute basic commands
- Docker-in-Docker is working correctly
- Node.js is available and functioning
- The runner can handle multi-step jobs


## Local Root CA Configuration
To enable HTTPS connections using local root CA certificates:

1. In `docker-compose.yaml`, mount your root CA certificate to the Docker-in-Docker container:
```yaml
services:
  forgejo-docker-dind:
    volumes:
      - /path/to/step-ca/certs/step_root_ca.crt:/usr/local/share/ca-certificates/step_root_ca.crt:ro
```

2. Configure volume bindings in `runner/config.yml`:
```yaml
container:
  network: "host"
  # These volumes must exist in the docker-dind container as it manages runner containers
  options: >- 
    -v /certs/client:/certs/client
    -v /usr/local/share/ca-certificates/step_root_ca.crt:/usr/local/share/ca-certificates/step_root_ca.crt
  valid_volumes:
    - /certs/client
    - /usr/local/share/ca-certificates/step_root_ca.crt
```

> **Important**: The volumes specified in `runner/config.yml` must exist inside the Docker-in-Docker container because:
> - The Docker-in-Docker (dind) container is responsible for creating and managing runner containers
> - Any volumes you want to mount in runner containers must first exist in the dind container
> - The path in the dind container must match exactly with the path specified in the runner config
> - Always ensure the volumes are properly mounted in docker-compose.yaml before referencing them in runner config

3. In your workflow files, add this step before any HTTPS connections:
```yaml
- name: Install local root CA
  run: |
    sudo update-ca-certificates
```

> **Note**: The `update-ca-certificates` command is specific to Linux-based systems (Ubuntu, Debian, etc.). For other operating systems:
> - Windows: Uses a different certificate management system
> - macOS: Uses the Keychain for certificate management
> - Alpine Linux: Uses `update-ca-certificates` but might need to install `ca-certificates` package first
>
> If you need to support multiple operating systems, you'll need to handle certificate installation differently for each platform.

This configuration is necessary when:
- Your runner needs to access internal HTTPS services
- You're using a private certificate authority
- You need to clone repositories over HTTPS from local Git servers

> Note: Make sure to replace `/path/to/step-ca/certs/step_root_ca.crt` with the actual path to your root CA certificate.

> **Important Network Configuration:**
> Setting `network: "host"` is crucial when containers need to access the Docker daemon. Here's why:
> - When using Docker-in-Docker (dind), containers created by the runner need to communicate with the Docker daemon
> - Some images (like catthehacker's) include Docker client and need to access Docker socket
> - Host network mode allows these containers to access the Docker daemon's Unix socket
> - Without host network mode, containers might fail to perform Docker operations
> - This is especially important for CI/CD workflows that build or manage containers

### 5. Start the Services

1. Start the Docker-in-Docker service:
```bash
docker compose up forgejo-docker-dind -d
```

2. Start the runner service:
```bash
docker compose up forgejo-runner -d
```

## References
- [Forgejo Runner Docker Installation Guide](https://forgejo.org/docs/latest/admin/runner-installation/#oci-image-installation)
- [Forgejo Runner Installation Guide for CI/CD](https://forgejo.org/docs/latest/admin/runner-installation/#offline-registration)
- [Forgejo Runner Configuration Guide](https://forgejo.org/docs/latest/admin/runner-installation/#configuration)
- [Forgejo Runner Docker Compose Example](https://code.forgejo.org/forgejo/runner/src/branch/main/examples/docker-compose/compose-forgejo-and-runner.yml)
- [Forgejo Actions - Choosing Labels](https://forgejo.org/docs/latest/admin/actions/#choosing-labels)
- [Codeberg Actions - Running on Docker](https://docs.codeberg.org/ci/actions/#running-on-docker)
- [CatTheHacker Docker Images](https://github.com/catthehacker/docker_images) - Pre-built Docker images for GitHub Actions
- [Docker Resource Constraints](https://docs.docker.com/engine/containers/resource_constraints/)