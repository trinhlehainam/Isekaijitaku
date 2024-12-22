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
  docker:docker://node:20-bullseye,ubuntu-22.04:docker://node:20-bullseye,ubuntu-20.04:docker://node:20-bookworm,ubuntu-18.04:docker://node:20-bookworm
  ```

### 4. Generate Configuration
After registration, generate the runner configuration:
```bash
forgejo-runner generate-config > config.yml
exit
```

### 5. Start the Runner
After completing the registration, start the runner service:
```bash
docker compose up forgejo-runner -d
```

The runner service should now be running and ready to execute CI/CD jobs.

## Labels Explanation
The configured labels allow your runner to use different Node.js environments:
- `docker`: Node 20 on Debian Bullseye
- `ubuntu-22.04`: Node 20 on Debian Bullseye
- `ubuntu-20.04`: Node 20 on Debian Bookworm
- `ubuntu-18.04`: Node 20 on Debian Bookworm

## Verification
To verify the runner is working:
1. Go to Site Administration → Actions → Runners
2. You should see your newly registered runner listed as "Online"

## Troubleshooting
If the runner doesn't appear online:
1. Check the runner logs: `docker compose logs forgejo-runner`
2. Verify the runner token was entered correctly
3. Ensure the Forgejo instance is accessible from the runner container

## References
- [Forgejo Runner Installation Guide](https://forgejo.org/docs/latest/admin/runner-installation/#oci-image-installation)
- [Forgejo Runner Configuration Guide](https://forgejo.org/docs/latest/admin/runner-installation/#configuration)
- [Forgejo Runner Docker Compose Example](https://code.forgejo.org/forgejo/runner/src/branch/main/examples/docker-compose/compose-forgejo-and-runner.yml)
- [Codeberg Actions - Running on Docker](https://docs.codeberg.org/ci/actions/#running-on-docker)