# Forgejo Runner Setup Guide

This guide explains how to set up and register a Forgejo runner for your CI/CD workflows.

## Prerequisites
- Docker and Docker Compose installed
- Access to Forgejo dashboard with admin privileges
- The Forgejo instance running via docker-compose

## Steps to Register Runner

### 1. Start Docker-in-Docker Service
First, start the Docker-in-Docker service that the runner will use:
```bash
docker compose up forgejo-docker-dind -d
```

### 2. Get Runner Token
1. Log in to your Forgejo dashboard
2. Go to Site Administration → Actions → Runners
3. Click "Create new runner token"
4. Copy the generated token (you'll need this in the next step)

### 3. Register the Runner

```bash
# Enter the runner container in interactive mode
docker compose run --rm -it forgejo-runner bash

# Register the runner using the token from step 2
forgejo-runner register
```

When registering, you'll be prompted for several inputs:
- Instance URL: Enter your Forgejo instance URL
  ```
  http://forgejo:3000
  ```
- Runner token: Paste the token from step 2
- Runner name: Choose a name for your runner
- Runner labels: Use these predefined labels:
  ```
  docker:docker://node:20-bullseye,ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04,ubuntu-20.04:docker://ghcr.io/catthehacker/ubuntu:act-20.04,ubuntu-18.04:docker://ghcr.io/catthehacker/ubuntu:act-18.04
  ```

> Note: These labels use catthehacker's Docker images which are specifically designed for GitHub Actions compatibility. They include:
> - Pre-installed common tools and software
> - GitHub Actions-compatible environment variables
> - Support for most GitHub Actions workflows
> - Regular security updates

### 4. Generate Configuration
After registration, generate the runner configuration:
```bash
forgejo-runner generate-config > config.yml
exit
```

Important configuration settings in `config.yml`:
```yaml
runner:
  envs:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_CERT_PATH: /certs/client
    DOCKER_TLS_VERIFY: 1
  # Override .runner labels with these labels
  labels: [
    "docker:docker://node:20-bullseye",
    "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04",
    "ubuntu-20.04:docker://ghcr.io/catthehacker/ubuntu:act-20.04",
    "ubuntu-18.04:docker://ghcr.io/catthehacker/ubuntu:act-18.04"
  ]

container:
  network: "host"
  options: -v /certs/client:/certs/client
  valid_volumes:
    - /certs/client
```

> Note: These settings are crucial for:
> - Secure Docker communication using TLS
> - Proper Docker-in-Docker functionality
> - Host network access for containers
> - Correct certificate mounting
> - Labels in config.yml will override the labels stored in .runner file
>
> **Important Network Configuration:**
> Setting `network: "host"` is crucial when containers need to access the Docker daemon. Here's why:
> - When using Docker-in-Docker (dind), containers created by the runner need to communicate with the Docker daemon
> - Some images (like catthehacker's) include Docker client and need to access Docker socket
> - Host network mode allows these containers to access the Docker daemon's Unix socket
> - Without host network mode, containers might fail to perform Docker operations
> - This is especially important for CI/CD workflows that build or manage containers

### 5. Start the Runner
After completing the registration, start the runner service:
```bash
docker compose up forgejo-runner -d
```

The runner service should now be running and ready to execute CI/CD jobs.

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

2. Commit and push this workflow file to your repository
3. Go to your repository's Actions tab to see the workflow run
4. The workflow should run successfully and show the environment information, Docker capabilities, and Node.js version

This test workflow will verify that:
- The runner can execute basic commands
- Docker-in-Docker is working correctly
- Node.js is available and functioning
- The runner can handle multi-step jobs

## References
- [Forgejo Runner Installation Guide](https://forgejo.org/docs/latest/admin/runner-installation/#oci-image-installation)
- [Forgejo Runner Configuration Guide](https://forgejo.org/docs/latest/admin/runner-installation/#configuration)
- [Forgejo Runner Docker Compose Example](https://code.forgejo.org/forgejo/runner/src/branch/main/examples/docker-compose/compose-forgejo-and-runner.yml)
- [Forgejo Actions - Choosing Labels](https://forgejo.org/docs/latest/admin/actions/#choosing-labels)
- [Codeberg Actions - Running on Docker](https://docs.codeberg.org/ci/actions/#running-on-docker)
- [CatTheHacker Docker Images](https://github.com/catthehacker/docker_images) - Pre-built Docker images for GitHub Actions
