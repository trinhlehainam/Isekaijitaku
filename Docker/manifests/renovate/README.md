# Self-Hosting Renovate with Forgejo/Gitea

This guide explains how to set up a self-hosted Renovate instance that works with Forgejo (or Gitea). The setup involves configuring a dedicated Forgejo user and deploying Renovate with Redis for enhanced performance using Docker Compose and secrets for secure credential management.

## Prerequisites

- A running Forgejo/Gitea instance
- Docker and Docker Compose (version supporting secrets)
- Administrative access to Forgejo/Gitea
- Directory structure for secrets and Redis persistence

## Setup Process

### 1. Forgejo/Gitea Configuration

#### Create a Dedicated Bot Account

1. Log in to Forgejo/Gitea with an administrator account
2. Navigate to Site Administration → Users → Create a New Account
3. Create a new user with these recommended settings:
   - Username: `renovate`
   - Email: `renovate@yourdomain.com` (use a valid email)
   - Set a strong password
   - Ensure the account has a proper full name (e.g., "Renovate Bot")

#### Generate a Personal Access Token (PAT)

1. Log in as the newly created renovate user
2. Go to Settings → Applications → Generate New Token
3. Name your token (e.g., "Renovate Bot PAT")
4. Select the following permissions:
   - `repo` (Read and Write)
   - `user` (Read)
   - `issue` (Read and Write)
   - `organization` (Read) (for Gitea ≥ 1.20.0)
   - `read:packages` (if using Gitea packages)
5. Generate and securely store the token - you won't be able to see it again

#### Repository Configuration

For each repository you want to monitor with Renovate:

1. Enable Issues in the repository settings
2. Ensure Pull Requests are enabled
3. Add the renovate user as a collaborator with write access
 
### 2. Renovate Configuration

#### Docker Compose Setup

1. Create the required directory structure:
   ```bash
   mkdir -p ./secrets ./redis
   ```

2. Store your credentials as Docker secrets:
   ```bash
   # Save your Forgejo PAT token
   echo "your-forgejo-access-token" > ./secrets/renovate_token
   
   # Generate and save a secure Redis password
   openssl rand -base64 24 > ./secrets/redis_password
   
   # Set proper permissions
   chmod 600 ./secrets/*
   ```

3. Use the provided `docker-compose.yml` file in this directory and update the Forgejo endpoint:
   ```yaml
   # Forgejo/Gitea Configuration
   - RENOVATE_PLATFORM=gitea
   - RENOVATE_ENDPOINT=http://your-forgejo-instance:3000/api/v1
   - RENOVATE_USERNAME=renovate
   ```

4. The Docker Compose file includes:
   - Renovate service with a pinned version (39.233.2)
   - Redis service for enhanced caching
   - Docker secrets for secure credential management
   - Custom entrypoint script to handle secrets
   - Network configuration and healthcheck for Redis

5. Configure Renovate using environment variables:

   Our setup uses environment variables for Renovate configuration rather than config.js files. The Renovate entrypoint script reads the secret token from a file and sets up Redis connectivity.
   
   For a complete list of configuration options, refer to the [Renovate Self-Hosted Configuration](https://docs.renovatebot.com/self-hosted-configuration/) documentation. Environment variable names follow the pattern: `RENOVATE_` + uppercased camelCase option name.

### 3. First Run and Onboarding

1. Start the Renovate stack:
   ```bash
   docker-compose up -d
   ```

2. Monitor the logs to ensure both Redis and Renovate are connecting properly:
   ```bash
   docker-compose logs -f
   ```

3. Verify Redis connectivity in the logs and ensure Renovate can authenticate with Forgejo
4. Renovate will create an "Onboarding PR" in each repository it has access to
5. Accept the Onboarding PR to confirm that you want Renovate to monitor the repository
6. A `renovate.json` file will be added to your repository with basic configuration

## Troubleshooting

- **Authentication issues**: Verify that your PAT has all required permissions and hasn't expired
- **Repository access issues**: Ensure the Renovate user has collaborator access to repositories
- **API errors**: Check that your Forgejo/Gitea version is compatible (minimum recommended: 1.14.0)
- **Redis connectivity**: Check Redis logs with `docker-compose logs renovate-redis` if Renovate cannot connect
- **Secret handling**: Ensure secret files have proper permissions (chmod 600) and contain valid credentials
- **Log levels**: The configuration uses `LOG_LEVEL=debug` by default for detailed troubleshooting

## Platform-Specific Notes

- Gitea versions older than v1.14.0 cannot add reviewers to PRs
- Platform-native automerge requires Gitea v1.24.0+ or Forgejo v10.0.0+
- If using Gitea older than v1.16.0, you must enable [clone filters](https://docs.gitea.io/en-us/clone-filters/)

## Further Documentation

For detailed configuration and customization, refer to these official resources:

- [Renovate Gitea/Forgejo Platform Documentation](https://docs.renovatebot.com/modules/platform/gitea/)
- [Self-hosted Renovate Configuration Options](https://docs.renovatebot.com/self-hosted-configuration/)
- [Renovate Self-Hosting Examples](https://docs.renovatebot.com/examples/self-hosting/)
