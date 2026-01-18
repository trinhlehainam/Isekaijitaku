---
aliases:
  - "Semaphore Docker Container Configuration"
tags:
  - manifest
---

# Semaphore Docker Container Configuration

This document explains how to configure and run the Semaphore Docker container with custom arguments.

## Current Configuration

The Semaphore container uses a shell script entrypoint that:
1. Exports necessary environment variables from secrets
2. Uses `exec "$@"` to properly execute the provided command

The default command in docker-compose.yaml is:
```yaml
command: ["/sbin/tini", "--", "/usr/local/bin/server-wrapper"]
```

## Running Semaphore with Custom Arguments

To run the Semaphore container with `/usr/local/bin/semaphore` as an argument to the server-wrapper, use the following command:

```bash
docker compose run --rm semaphore /sbin/tini -- /usr/local/bin/server-wrapper /usr/local/bin/semaphore
```

This command will:
1. Execute the entrypoint script which sets up the environment variables
2. Use `exec "$@"` to replace the shell with the specified command
3. Run `tini` as the init process
4. Pass `/usr/local/bin/semaphore` as an argument to the server-wrapper

## How It Works

1. The entrypoint in `docker-compose.yaml` is configured as:
   ```yaml
   entrypoint:
     - /bin/sh
     - -c
     - |
       export SEMAPHORE_ADMIN_PASSWORD=$$(cat /run/secrets/semaphore_admin_password)
       export SEMAPHORE_DB_PASS=$$(cat /run/secrets/db_password)
       export SEMAPHORE_ACCESS_KEY_ENCRYPTION=$$(cat /run/secrets/semaphore_access_key_encryption)
       exec "$@"
   ```

2. The default command is set to:
   ```yaml
   command: ["/sbin/tini", "--", "/usr/local/bin/server-wrapper"]
   ```

3. When overriding the command with `docker compose run`, the entire command line after the service name replaces the default command and is passed to `exec "$@"` in the entrypoint script.

4. The `exec` command is crucial here because:
   - It replaces the current shell process with the specified command
   - This ensures `tini` runs as PID 1 (the main process) in the container
   - Running `tini` as PID 1 is necessary for proper signal handling and zombie process reaping
   - Without `exec`, `tini` would run as a child process and couldn't function properly as an init system

For example, the process hierarchy with `exec` looks like this:
```
PID 1: /sbin/tini
└── /usr/local/bin/server-wrapper
    └── /usr/local/bin/semaphore
```

Without `exec`, it would incorrectly look like this:
```
PID 1: /bin/sh
└── /sbin/tini
    └── /usr/local/bin/server-wrapper
        └── /usr/local/bin/semaphore
```

## Config Folder Setup

Before running the Semaphore container, you need to set up the config folder with the correct ownership:

```bash
# Create config directory if it doesn't exist
mkdir -p config

# Set ownership to UID 1001 (Semaphore service user)
chown -R 1001:1001 config

# Set appropriate permissions
chmod 755 config
```

This setup is necessary because:
- Semaphore runs as user with UID 1001 inside the container
- The config folder is mounted at `/etc/semaphore` in the container
- Proper ownership ensures Semaphore can read and write configuration files

## Forgejo Webhook Integration

This section describes how to set up webhook integration between Forgejo and Semaphore to automatically trigger Semaphore tasks when code changes are pushed to Forgejo repositories.

### Configuration Steps

1. **Create Forgejo Webhook Secret in Semaphore UI**:
   - Navigate to Semaphore UI and go to **Administration > Key Store**
   - Click **New Key** and select **Password (Webhook Secret)** as the type
   - Enter a meaningful name (e.g., `forgejo_webhook_secret`)
   - Generate or input a secure secret string
   - Save the new key

2. **Add a New Integration**:
   - Go to **Administration > Integrations**
   - Click **New Integration**
   - Select **Github Webhooks** as the authentication method
   - Under the Vault Password option, choose the Forgejo Webhook Secret you created in the previous step
   - Provide a name for the integration
   - Toggle on **Use project alias** to enable the Integration Matcher feature
   - Save the integration

3. **Add a New Alias**:
   - After saving the integration, return to the main **Integrations** page
   - Click **Add Alias** directly from this page
   - Semaphore will immediately generate a complete webhook URL automatically
   - Copy this generated URL - it's what you'll use as the Target URL in Forgejo

4. **Configure Forgejo Repository Webhook**:
   - Navigate to your Forgejo repository
   - Go to **Settings > Webhooks**
   - Click **Add Webhook**
   - In the **Target URL** field, paste the exact URL that Semaphore generated for your Project Alias
   - In the **Secret** field, enter the same webhook secret you created in step 1
   - Select the events that should trigger the webhook (typically push events)
   - Save the webhook configuration

### How It Works

When code changes are pushed to your Forgejo repository:

1. Forgejo sends a webhook payload to the specified Semaphore endpoint
2. Semaphore validates the webhook signature using the shared secret
3. If validation succeeds, Semaphore identifies the repository and matches it to configured projects
4. Semaphore triggers the appropriate task templates based on the repository and event type

### Configuring Integration Matchers

After setting up the basic webhook integration, you'll need to configure matchers to connect incoming webhook payloads to specific Semaphore projects:

1. In your integration settings, click **New Matcher**
2. Select the Semaphore project you want to connect
3. Configure the matcher with the following options:
   - **Body Data Format**: Choose the type of data to match (JSON, String)
   - **Key**: The key in the webhook payload to match against
   - **Comparison Method**: Choose how to compare the values (==, !=, Contains)
   - **Value**: The value to match

**Working with Nested JSON Keys**:

Forgejo webhook payloads often contain nested JSON objects. To match values in nested objects:

- Use dot notation to define the path to the nested key
- For example, to match `{ key1: { key2: { key3: "value" } } }`, enter `key1.key2.key3` in the Key field
- The matcher will navigate through the JSON structure to find and compare the nested value

**Example: Matching Renovate Bot Commits**

Here's a practical example of triggering Semaphore tasks when receiving webhook payloads from Renovate Bot updates:

When Renovate Bot pushes a commit, Forgejo sends a webhook payload that includes commit information like this:

```json
{
  "ref": "refs/heads/main",
  "head_commit": {
    "message": "chore(deps): update node.js to v22\n",
    // other fields...
  },
  // other fields...
}
```

To trigger a Node.js update task only when Renovate updates Node.js:

1. Configure your matcher with these settings:
   - **Body Data Format**: JSON
   - **Key**: `head_commit.message`
   - **Comparison Method**: Contains
   - **Value**: `chore(deps): update node.js`

2. The matcher will:
   - Extract the commit message from the nested JSON structure
   - Check if it contains the string "chore(deps): update node.js"
   - Only trigger the task if the condition is met

This allows you to create specific task templates for different types of updates (Node.js, Python, Docker, etc.) and have them triggered automatically based on the commit message content.

This integration allows automated CI/CD pipelines to run in Semaphore directly from your Forgejo repositories without manual intervention.

## Tailscale Integration

This section explains how to integrate Semaphore with Tailscale for secure networking.

### Prerequisites

1. A Tailscale account with admin access
2. Generate an OAuth client in Tailscale admin console:
   - Go to [OAuth clients page](https://login.tailscale.com/admin/settings/oauth)
   - Select the following permissions:
     - `auth_keys:write` - Required to generate auth keys for node registration
   - Generate client and securely store the client ID and secret
   - Use these credentials to generate `TS_AUTHKEY` for node registration

### Configuration Steps

1. Create a custom Dockerfile to add Tailscale CLI binary to Semaphore:
   ```dockerfile
   FROM tailscale/tailscale:v1.78.3 as tailscale

   FROM semaphoreui/semaphore:v2.11.3

   # Add only Tailscale CLI binary from the official Tailscale image
   # We don't need tailscaled as it runs in the separate container
   COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale
   ```

2. Update docker-compose.yaml to integrate with Tailscale:
   ```yaml
   services:
     tailscale:
       image: tailscale/tailscale:latest
       hostname: semaphore-tailscale  # This will be the node name in Tailscale
       volumes:
         - ./tailscale:/var/lib/tailscale  # Persist Tailscale state
         - ./tailscale/socket:/tmp/
       devices:
         - /dev/net/tun:/dev/net/tun  # Required for Tailscale VPN
       environment:
         - TS_AUTHKEY=${TS_AUTHKEY}  # Auth key generated using OAuth client
       cap_add:
         - NET_ADMIN
         - SYS_MODULE
       restart: unless-stopped
       healthcheck:
         test: ["CMD", "test", "-e", "/var/run/tailscale/tailscaled.sock"]
         interval: 5s
         timeout: 5s
         retries: 5
         start_period: 10s

     semaphore:
       build: .  # Use our custom Dockerfile
       network_mode: service:tailscale  # Share network namespace with Tailscale
       volumes:
         - ./tailscale/socket/tailscaled.sock:/var/run/tailscale/tailscaled.sock:ro  # Mount Tailscale socket
         - ./config:/etc/semaphore
       depends_on:
         tailscale:
           condition: service_healthy
           restart: true
       # ... other semaphore configurations ...
   ```

### How It Works

1. **Tailscale Binary Integration**:
   - Only the `tailscale` CLI binary is copied from the official Tailscale image
   - The `tailscaled` daemon runs in the separate Tailscale container
   - The CLI binary in Semaphore container communicates with `tailscaled` through the socket

2. **Network Integration**:
   - `network_mode: service:tailscale` shares the network namespace between Semaphore and Tailscale
   - This allows Semaphore to use Tailscale's network interface and routing
   - All Semaphore traffic can be routed through the Tailscale network

3. **Socket Communication**:
   - `/var/run/tailscale/tailscaled.sock` is mounted from the Tailscale container
   - This socket file enables the Tailscale CLI to communicate with the Tailscale daemon
   - The socket is created when Tailscale daemon starts

4. **Container Dependencies**:
   - Semaphore container waits for Tailscale container to be healthy
   - Health check verifies the existence of `tailscaled.sock`
   - Ensures socket file is available before starting Semaphore
   - Retries health check up to 5 times with 5-second intervals

### Startup Sequence

Due to Tailscale's node approval requirements, it's recommended to start services in the following order:

1. Start Tailscale container first:
   ```bash
   # Start only the Tailscale container
   docker compose up -d tailscale

   # Check Tailscale logs for the approval URL
   docker compose logs -f tailscale
   ```

2. Approve the node in Tailscale admin console:
   - Look for the approval URL in Tailscale container logs
   - Visit the URL and approve the node in your Tailscale admin console
   - Wait for the node to be fully connected

3. Start Semaphore container:
   ```bash
   # Start Semaphore after Tailscale is approved and connected
   docker compose up -d
   ```

This sequence ensures:
- Tailscale node can be properly approved before Semaphore starts
- Socket file is created and accessible
- Network connectivity is established

### Troubleshooting

If Tailscale container becomes unhealthy:
1. Check if the node requires approval in Tailscale admin console
2. Verify the OAuth credentials and auth key
3. Check Tailscale container logs:
   ```bash
   docker compose logs tailscale
   ```
4. Restart the containers in sequence if needed:
   ```bash
   docker compose down
   docker compose up -d tailscale
   # Wait for approval and connection
   docker compose up -d
   ```

### Generating Auth Key

1. Create an OAuth client with `auth_keys:write` scope
2. Use the OAuth client credentials to generate an auth key:
   ```bash
   # Using curl to generate an auth key
   curl -d "client_id=YOUR_CLIENT_ID" \
        -d "client_secret=YOUR_CLIENT_SECRET" \
        -d "scope=auth_keys:write" \
        https://api.tailscale.com/api/v2/oauth/token

   # Use the access token to generate an auth key
   curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
        -d '{"reusable": false, "ephemeral": true}' \
        https://api.tailscale.com/api/v2/tailnet/YOUR_ORG/keys

   # The response will contain your TS_AUTHKEY
   ```

### Important Notes

- Only the Tailscale CLI binary is needed in the Semaphore container
- The `tailscaled` daemon runs in the dedicated Tailscale container
- Generate auth keys using OAuth client with `auth_keys:write` scope
- The Tailscale container must start before the Semaphore container
- Consider using Docker secrets for storing sensitive Tailscale credentials
- The hostname set in the Tailscale service will be the node name in your tailnet

## Keycloak OIDC Integration

The configuration automatically injects Keycloak OpenID Connect settings through a JSON merge:

```yaml
jq '.oidc_providers = {
  "keycloak": {
    "display_name": "Sign in with keycloak",
    "provider_url": "https://keycloak.yourdomain.local/realms/your_realm_name",
    "client_id": "semaphore",
    "client_secret": "/run/secrets/keycloak_client_secret",
    "redirect_url": "https://semaphore.yourdomain.local/api/auth/oidc/keycloak/redirect"
  }
}' /etc/semaphore/config.json
```

Requirements:
- Valid Keycloak realm setup
- Client secret stored in `secrets/keycloak_client_secret`
- Proper DNS records for Keycloak and Semaphore endpoints

## Reverse Proxy Setup (Traefik)

Labels configure Traefik routing:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=proxy"
  - "traefik.http.services.semaphore.loadbalancer.server.port=3000"
  - "traefik.http.routers.semaphore-local.rule=Host(`semaphore.yourdomain.local`)"
  - "traefik.http.routers.semaphore-local.entrypoints=websecure"
  - "traefik.http.routers.semaphore-local.tls.certresolver=stepca"
```

Prerequisites:
- Existing Traefik proxy network
- Valid TLS certificate resolver
- DNS records pointing to your Traefik instance

## Secret Management

Required secrets:
- `db_password`: PostgreSQL database password
- `semaphore_admin_password`: Initial admin password
- `semaphore_access_key_encryption`: Base64-encoded 32-byte key
- `keycloak_client_secret`: Keycloak OIDC client secret

Generate encryption key:
```bash
head -c32 /dev/urandom | base64 > secrets/semaphore_access_key_encryption
```

Best practices:
- Store secrets outside version control
- Use 600 permissions for secret files
- Rotate secrets regularly

## Database Health Checks

PostgreSQL service includes comprehensive health monitoring:
```yaml
healthcheck:
  test: [ "CMD", "pg_isready", "-q", "-d", "semaphore", "-U", "semaphore" ]
  interval: 10s
  timeout: 5s
  retries: 3
```

This ensures:
- Automatic restarts on database connection failures
- Dependency ordering during startup
- Service reliability through continuous monitoring

## Important Notes

- Using `exec "$@"` in the entrypoint ensures proper signal handling and process management
- The `--rm` flag removes the container after it exits
- All environment variables and secrets defined in `docker-compose.yaml` will still be available
- The container will still have access to all configured volumes and networks
- `tini` is used as an init process to handle zombie processes and signal forwarding

## References

### Tailscale Documentation
- [Docker Guide](https://tailscale.com/blog/docker-tailscale-guide) - Comprehensive guide for using Tailscale with Docker
- [OAuth Clients](https://tailscale.com/kb/1215/oauth-clients) - Setting up and managing OAuth clients
- [API Documentation](https://github.com/tailscale/tailscale/blob/main/api.md) - Official Tailscale API documentation
- [Auth Keys](https://tailscale.com/kb/1085/auth-keys/) - Understanding Tailscale authentication keys

### Docker Resources
- [Tailscale Official Image](https://hub.docker.com/r/tailscale/tailscale) - Tailscale's official Docker image
- [Semaphore Official Image](https://hub.docker.com/r/semaphoreui/semaphore) - Semaphore's official Docker image
- [Docker Compose Network Mode](https://docs.docker.com/compose/compose-file/compose-file-v3/#network_mode) - Documentation for network_mode service configuration

### Source Code
- [Tailscale Dockerfile](https://github.com/tailscale/tailscale/blob/main/Dockerfile) - Official Tailscale Dockerfile
- [Semaphore Dockerfile](https://github.com/semaphoreui/semaphore/blob/develop/deployment/docker/server/Dockerfile) - Official Semaphore Dockerfile
