# Setting up CrowdSec with Traefik in Docker

This guide explains how to set up CrowdSec security engine with Traefik proxy using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- Traefik proxy running
- Redis (recommended for caching in stream mode)
- Basic understanding of Docker networking

## Directory Structure Setup

Create necessary directories:

```bash
# Create directories for CrowdSec
mkdir -p crowdsec/data
mkdir -p crowdsec/config
mkdir -p log
mkdir -p secrets
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
    image: "traefik:v3.3.2"
    # ... existing traefik configuration ...
    command:
      # ... existing commands ...
      - "--experimental.plugins.crowdsec-bouncer.modulename=github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
      - "--experimental.plugins.crowdsec-bouncer.version=v1.3.5"
    depends_on:
      - crowdsec
    secrets:
      - crowdsec_lapi_key
    networks:
      - crowdsec
      # ... other networks ...

secrets:
  crowdsec_lapi_key:
    file: ./secrets/crowdsec_lapi_key
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
          # Stream mode configuration
          crowdsecMode: stream
          updateIntervalSeconds: 60
          updateMaxFailure: 0
          # LAPI Configuration using secrets
          crowdsecLapiKey: FIXME
          crowdsecLapiHost: crowdsec:8080
          crowdsecLapiScheme: http
          # Enable AppSec for advanced protection
          crowdsecAppsecEnabled: true
          crowdsecAppsecHost: crowdsec:7422
          crowdsecAppsecFailureBlock: true
          crowdsecAppsecUnreachableBlock: true
          # Redis Cache Configuration (Recommended for stream mode)
          redisCacheEnabled: true
          redisCacheHost: "redis:6379"
          redisCachePassword: ${REDIS_PASSWORD}
          # Trusted IPs Configuration
          forwardedHeadersTrustedIPs: 
            - "172.50.0.0/16"  # Cloudflare network
          clientTrustedIPs: 
            - "100.64.0.0/10"  # Tailscale
            - "192.168.0.0/16"  # Private Local network
          # Captcha Configuration
          # Available providers: turnstile, hcaptcha, recaptcha
          captchaProvider: turnstile
          captchaSiteKey: FIXME
          captchaSecretKey: FIXME
          captchaGracePeriodSeconds: 1800
          captchaHTMLFilePath: /captcha.html
          banHTMLFilePath: /ban.html
```

### 4. Configure Captcha

To enable captcha protection with CrowdSec:

1. Download required HTML templates:
```bash
# Download captcha.html and ban.html templates
curl -o crowdsec/captcha.html https://raw.githubusercontent.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/main/captcha.html
curl -o crowdsec/ban.html https://raw.githubusercontent.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/main/ban.html
```

2. Mount the HTML files in Traefik service. Add these volumes to your `docker-compose.yaml` under the Traefik service:
```yaml
    volumes:
      # ... existing volumes ...
      # NOTE: make sure to download crowdsec's captcha and ban pages before starting Traefik
      - "./crowdsec/captcha.html:/captcha.html"
      - "./crowdsec/ban.html:/ban.html"
```

3. After CrowdSec container is created, modify the default `profiles.yaml` by adding one of these configurations at the top of the file:

Option 1 - Basic Captcha:
```yaml
name: captcha_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip" && Alert.GetScenario() contains "http"
## Any scenario with http in its name will trigger a captcha challenge
decisions:
  - type: captcha
    duration: 4h
on_success: break
---
```

Option 2 - Limited Captcha with Ban Fallback:
```yaml
name: captcha_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip" && Alert.GetScenario() contains "http" && GetDecisionsSinceCount(Alert.GetValue(), "24h") <= 3
## Same as above but only 3 captcha decision per 24 hours before ban
decisions:
  - type: captcha
    duration: 4h
on_success: break
---
```

The second option is recommended as it prevents abuse by limiting the number of captcha challenges before implementing a ban.

4. Update the bouncer middleware configuration in `config/dynamic/crowdsec-middleware.yaml`:

```yaml
http:
  middlewares:
    crowdsec:
      plugin:
        bouncer:
          # ...
          # Captcha Configuration
          captchaProvider: turnstile  # Available: turnstile, hcaptcha, recaptcha
          captchaSiteKey: FIXME
          captchaSecretKey: FIXME
          captchaGracePeriodSeconds: 1800
          captchaHTMLFilePath: /captcha.html
          banHTMLFilePath: /ban.html
```

The captcha configuration will:
- Challenge suspicious IPs with a captcha instead of immediately banning them
- Apply captcha for HTTP-related scenarios
- Set captcha duration to 4 hours
- With Option 2, limit to 3 captcha challenges per IP in 24 hours before implementing a ban
- Use custom HTML templates for captcha and ban pages

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

3. Generate bouncer API key and store it securely:
   ```bash
   # Generate the key
   docker compose exec crowdsec cscli bouncers add traefik-bouncer > secrets/crowdsec_lapi_key
   # Ensure proper permissions
   chmod 600 secrets/crowdsec_lapi_key
   ```

4. Add CrowdSec middleware to your services:
   ```yaml
   labels:
     - "traefik.http.middlewares.crowdsec-bouncer.plugin.crowdsec-bouncer.enabled=true"
     - "traefik.http.routers.your-service.middlewares=crowdsec-bouncer@docker"
   ```

## Stream Mode vs Live Mode

This setup uses **stream mode** instead of live mode for several important reasons:

1. **Better Performance**: Stream mode is recommended by the CrowdSec bouncer plugin for better performance as it maintains a local cache of decisions.

2. **Cache Consistency**: When using Redis cache with live mode, banned IPs remain in cache even after being deleted from CrowdSec server. Stream mode ensures better cache consistency by periodically syncing with the CrowdSec server.

3. **Reduced Latency**: Stream mode reduces the number of API calls to the CrowdSec server by maintaining a local cache of decisions.

4. **Higher Reliability**: Even if the CrowdSec server is temporarily unavailable, the bouncer can still function using its cached decisions.

Key configuration parameters for stream mode:
- `updateIntervalSeconds`: How often to sync decisions with CrowdSec server (default: 60)
- `updateMaxFailure`: Maximum number of failed updates before considering the service as down (default: 0)

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
4. Ensure Redis cache is properly secured with authentication
5. Regularly monitor CrowdSec logs and metrics
6. Consider implementing allowlists for trusted IPs
7. Use secure networks and limit container access
8. Properly secure the LAPI key file with appropriate permissions

## Troubleshooting

1. If CrowdSec is not blocking requests:
   - Check if the bouncer API key file exists and has correct permissions
   - Verify the middleware configuration
   - Check CrowdSec logs for any errors
   - Verify Redis cache connectivity

2. If performance is impacted:
   - Verify Redis cache is working correctly
   - Adjust update intervals in stream mode
   - Monitor resource usage
   - Check Redis cache hit/miss rates

3. For false positives:
   - Add trusted IPs to the configuration
   - Review and adjust decision durations
   - Consider implementing custom rules
   - Monitor stream mode sync logs for any issues

## References

### CrowdSec Documentation
- [CrowdSec Hub](https://hub.crowdsec.net/)
- [CrowdSec Console](https://app.crowdsec.net)
- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [CrowdSec Blog - Docker Security](https://www.crowdsec.net/blog/enhance-docker-compose-security)
- [CrowdSec Captcha Profile](https://docs.crowdsec.net/docs/profiles/captcha_profile/)
- [CrowdSec with Nginx Proxy Manager](https://www.crowdsec.net/blog/crowdsec-with-nginx-proxy-manager)

### Traefik CrowdSec Plugin
- [CrowdSec Bouncer Plugin](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin)
- [Plugin GitHub Repository](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin)
- [Plugin Examples](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/tree/main/examples)
  - [AppSec Configuration](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/blob/main/examples/appsec-enabled/README.md)
  - [Redis Cache Setup](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/blob/main/examples/redis-cache/README.md)
  - [Trusted IPs Configuration](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/blob/main/examples/trusted-ips/README.md)

### Traefik Documentation
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Traefik Plugin System](https://doc.traefik.io/traefik/plugins/)
- [Traefik Middleware](https://doc.traefik.io/traefik/middlewares/overview/)
- [Forwarded Headers](https://doc.traefik.io/traefik/routing/entrypoints/#forwarded-headers)

### Network Configuration
- [Tailscale IP Ranges](https://tailscale.com/kb/1015/100.x-addresses)
- [Private Network RFC1918](https://datatracker.ietf.org/doc/html/rfc1918)
- [Cloudflare IP Ranges](https://www.cloudflare.com/ips/)
