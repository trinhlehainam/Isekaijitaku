# Setting up CrowdSec with Traefik in Docker

This guide explains how to set up CrowdSec security engine with Traefik proxy using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- Traefik proxy running
- Redis (optional, for caching)
- Basic understanding of Docker networking

## Directory Structure Setup

Create necessary directories:

```bash
# Create directories for CrowdSec
mkdir -p crowdsec/data
mkdir -p crowdsec/config
mkdir -p log
```

## Configuration Files

### 1. Create acquis.yaml

Create `crowdsec/acquis.yaml` with the following content:

```yaml
---
filenames:
  - /var/log/traefik/access.log
labels:
  type: traefik
```

### 2. Docker Compose Configuration

Add CrowdSec service to your `docker-compose.yaml`:

```yaml
services:
  crowdsec:
    image: crowdsecurity/crowdsec:v1.6.4
    container_name: "crowdsec"
    restart: unless-stopped
    environment:
      COLLECTIONS: crowdsecurity/traefik crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules
      CUSTOM_HOSTNAME: crowdsec
    volumes:
      - ./crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml:ro
      - ./log/access.log:/var/log/traefik/access.log:ro
      - ./crowdsec/data:/var/lib/crowdsec/data/
      - ./crowdsec/config:/etc/crowdsec/
    networks:
      - crowdsec
    labels:
      - "traefik.enable=false"
```

### 3. Configure Traefik

#### A. Plugin Configuration in Traefik Service

Update Traefik service configuration in `docker-compose.yaml`:

```yaml
services:
  traefik:
    # ... existing traefik configuration ...
    command:
      # ... existing commands ...
      - "--experimental.plugins.crowdsec-bouncer.modulename=github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
      - "--experimental.plugins.crowdsec-bouncer.version=v1.3.5"
    depends_on:
      - crowdsec
    networks:
      - crowdsec
      # ... other networks ...
```

#### B. Create CrowdSec Middleware Configuration

Create `config/dynamic/crowdsec-middleware.yaml`:

```yaml
http:
  middlewares:
    crowdsec:
      plugin:
        bouncer:
          enabled: true
          logLevel: DEBUG
          updateIntervalSeconds: 60
          defaultDecisionSeconds: 60
          httpTimeoutSeconds: 10
          crowdsecMode: live
          # Enable AppSec for advanced protection
          crowdsecAppsecEnabled: true
          crowdsecAppsecHost: crowdsec:7422
          crowdsecAppsecFailureBlock: true
          crowdsecAppsecUnreachableBlock: true
          # LAPI Configuration
          crowdsecLapiKey: ${BOUNCER_KEY}  # Replace with your key
          crowdsecLapiHost: crowdsec:8080
          crowdsecLapiScheme: http
          # Optional Redis Cache Configuration
          redisCacheEnabled: true
          redisCacheHost: "redis:6379"
          redisCachePassword: ${REDIS_PASSWORD}
          redisCacheDatabase: "5"
          # Trusted IPs Configuration
          forwardedHeadersTrustedIPs: 
            - "172.50.0.0/16"  # Cloudflare network
          clientTrustedIPs: 
            - "100.64.0.0/10"  # Tailscale
            - "192.168.0.0/16"  # Local network
```

## Setup Steps

1. Start the services:
   ```bash
   docker compose up -d
   ```

2. Enroll CrowdSec with the console:
   ```bash
   docker compose exec crowdsec cscli console enroll <your-enrollment-key>
   ```
   Get your enrollment key from [CrowdSec Console](https://app.crowdsec.net)

3. Generate bouncer API key:
   ```bash
   docker compose exec crowdsec cscli bouncers add traefik-bouncer
   ```
   Save the generated API key and update it in your middleware configuration

4. Add CrowdSec middleware to your services:
   ```yaml
   labels:
     - "traefik.http.middlewares.crowdsec-bouncer.plugin.crowdsec-bouncer.enabled=true"
     - "traefik.http.middlewares.crowdsec-bouncer.plugin.crowdsec-bouncer.crowdseclapikey=<your-bouncer-api-key>"
     - "traefik.http.routers.your-service.middlewares=crowdsec-bouncer@docker"
   ```

## Verification

1. Check if CrowdSec is running:
   ```bash
   docker compose ps | grep crowdsec
   ```

2. View CrowdSec logs:
   ```bash
   docker compose logs crowdsec
   ```

3. Check CrowdSec metrics:
   ```bash
   docker compose exec crowdsec cscli metrics
   ```

## Additional Security Considerations

1. Always keep CrowdSec and Traefik updated to the latest versions
2. Configure appropriate trusted IP ranges for your environment
3. Enable AppSec features for enhanced protection
4. Use Redis cache for better performance in high-traffic environments
5. Regularly monitor CrowdSec logs and metrics
6. Consider implementing allowlists for trusted IPs
7. Use secure networks and limit container access

## Troubleshooting

1. If CrowdSec is not blocking requests:
   - Check if the bouncer API key is correct
   - Verify the middleware configuration
   - Check CrowdSec logs for any errors

2. If performance is impacted:
   - Enable Redis cache
   - Adjust update intervals
   - Monitor resource usage

3. For false positives:
   - Add trusted IPs to the configuration
   - Review and adjust decision durations
   - Consider implementing custom rules
