# Mount Point Monitor

A Docker-based solution that monitors multiple mount points and integrates with docker-autoheal for automatic recovery. Other services can depend on mountcheck to ensure their volumes are properly mounted before starting.

## Features

- Continuous monitoring of multiple mount points
- Integration with docker-autoheal for automatic recovery
- Separate health check mechanism for Docker's health check system
- Read-only mount points for security
- Minimal privilege container execution

## How It Works

1. The monitor checks for `.mount` files in specified mount points
2. If a `.mount` file is missing, it indicates the mount point is not properly mounted
3. Docker's health check system monitors the container's health
4. Other services can wait for mountcheck to be healthy before starting
5. docker-autoheal automatically restarts unhealthy containers

## Setup

1. Create `.mount` files in your mount points:
   ```bash
   touch /your/mount/point1/.mount
   touch /your/mount/point2/.mount
   ```

2. Update mount points in `docker-compose.yaml`:
   ```yaml
   volumes:
     - /your/mount/point1:/mnt/point1:ro
     - /your/mount/point2:/mnt/point2:ro
   ```

3. Start the container:
   ```bash
   docker-compose up -d
   ```

## Configuration

### Mount Points
- Mount points are mounted read-only under `/mnt/`
- Each mount point should contain a `.mount` file
- Add or remove mount points by modifying the volumes in `docker-compose.yaml`

### Check Interval
- Monitor check interval: 10 seconds (configurable in `mountcheck.sh`)
- Health check interval: 10 seconds (configurable in `docker-compose.yaml`)

### Container Health
- Container is considered unhealthy after 3 failed health checks
- Health check timeout: 10 seconds
- Automatic restart on failure via docker-autoheal

## Files

- `docker-compose.yaml`: Container configuration and health check settings
- `mountcheck.sh`: Main monitoring script that runs continuously
- `healthcheck.sh`: Single-run health check script for Docker's health check system

## Requirements

- Docker
- docker-compose
- docker-autoheal (for automatic container recovery)

## Security

- Container runs as non-root user
- Mount points are read-only
- No new privileges allowed
- Container runs in read-only mode

## Logging

- INFO: Normal operation messages
- ERROR: Mount point check failures

## Integration

### Docker Autoheal
This service integrates with docker-autoheal. Ensure you have the autoheal service running:
```yaml
services:
  autoheal:
    image: willfarrell/autoheal
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - AUTOHEAL_CONTAINER_LABEL=autoheal
```

### Integrating Other Services
To make your services wait for mount points to be ready, use the `depends_on` configuration with health check:

```yaml
services:
  your_service:
    image: your_image
    depends_on:
      mountcheck:
        condition: service_healthy
        restart: true
    volumes:
      - /your/mount/point:/container/path
```

This ensures that:
1. Your service only starts after mountcheck is healthy
2. Your service restarts if mountcheck becomes unhealthy
3. Mount points are verified before your service attempts to use them

## Troubleshooting

### Mount Points Not Detected
1. Verify `.mount` files exist:
   ```bash
   ls -la /your/mount/point*/.mount
   ```

2. Check mountcheck logs:
   ```bash
   docker-compose logs mountcheck
   ```

### Service Dependencies
If your service starts before mount points are ready:
1. Verify the `depends_on` configuration is correct
2. Check mountcheck's health status:
   ```bash
   docker inspect mountcheck | grep -A 10 Health
   ```

## References
- [How do I verify if an external drive is mounted before starting container](https://www.reddit.com/r/docker/comments/12rp2kt/how_do_i_verify_if_an_external_drive_is_mounted/)