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

## Important Notes

- Using `exec "$@"` in the entrypoint ensures proper signal handling and process management
- The `--rm` flag removes the container after it exits
- All environment variables and secrets defined in `docker-compose.yaml` will still be available
- The container will still have access to all configured volumes and networks
- `tini` is used as an init process to handle zombie processes and signal forwarding
