# Cloudflare Tunnel Manual Setup

This directory contains configuration files for setting up a Cloudflare Tunnel manually using Docker. The setup allows you to securely expose your local services to the internet through Cloudflare's network.

## Directory Structure

```
.
├── config/
│   └── config.yaml       # Tunnel configuration file
├── docker-compose.yaml   # Docker composition file
└── README.md            # This documentation
```

## Files Description

### docker-compose.yaml

Docker Compose configuration for running the Cloudflare tunnel service:
- Uses official Cloudflare tunnel image (`cloudflare/cloudflared`)
- Runs as a container named `cloudflared-tunnel`
- Mounts a local config directory to `/home/nonroot/.cloudflared/`
- Connects to an external Docker network named `cloudflared`

### config/config.yaml

Main configuration file for the Cloudflare tunnel:
- Defines tunnel UUID and credentials location
- Contains ingress rules for routing traffic
- Supports both domain and wildcard subdomain routing
- Includes special configurations for Nginx Proxy Manager and Traefik compatibility

## Setup Instructions

1. Replace `<PATH_TO_CONFIG_FOLDER>` in `docker-compose.yaml` with your actual config folder path

2. Set proper permissions on your config folder:
   ```bash
   sudo chown -R 65532:65532 <PATH_TO_CONFIG_FOLDER>
   ```

3. Login to Cloudflare:
   ```bash
   docker compose run --rm cloudflared-tunnel tunnel login
   ```

4. Create a new tunnel:
   ```bash
   docker compose run --rm cloudflared-tunnel tunnel create YOUR_TUNNEL_NAME
   ```
   This command will create a new tunnel and generate a UUID. You can get the UUID in two ways:
   - From the generated JSON file at `/home/nonroot/.cloudflared/UUID.json` in your config folder
   - From the Cloudflare Zero Trust Dashboard: Network > Tunnels

5. Configure `config.yaml`:
   - Replace `UUID` in both `tunnel:` and `credentials-file:` fields with your tunnel's UUID
   - The credentials file should be named `UUID.json` (e.g., if your UUID is `123e4567-e89b-12d3-a456-426614174000`, 
     the file should be named `123e4567-e89b-12d3-a456-426614174000.json`)
   - Update domain names and proxy settings
   - Configure your ingress rules as needed

6. Configure Cloudflare DNS Records:
   1. Main Domain Setup:
      - Type: `CNAME`
      - Name: `@` (or your subdomain)
      - Target: `UUID.cfargotunnel.com`
      - Proxy status: Proxied 

   2. Wildcard Subdomain Setup:
      - Type: `CNAME`
      - Name: `*`
      - Target: `@` (or your main domain)
      - Proxy status: Proxied 
      
   3. Subdomain Setup:
      - Type: `CNAME`
      - Name: `<subdomain>.<main domain>`
      - Target: `@` (or your main domain)
      - Proxy status: Proxied

   Example:
   ```
   # For domain example.com with tunnelID: 123e4567-e89b-12d3-a456-426614174000
   example.com        CNAME    123e4567-e89b-12d3-a456-426614174000.cfargotunnel.com    Proxied
   # Wildcard subdomain
   *.example.com      CNAME    example.com                                              Proxied
   # For subdomain like app.example.com
   app.example.com    CNAME    123e4567-e89b-12d3-a456-426614174000.cfargotunnel.com    Proxied
   ```

7. Start the tunnel:
   ```bash
   docker compose up -d
   ```

## Configuration Examples

### Network Setup

1. Create a shared Docker network for your proxy and Cloudflare tunnel:
   ```bash
   docker network create cloudflared
   ```

2. Make sure both your proxy (e.g., Traefik) and cloudflared containers are connected to this network:
   ```yaml
   # docker-compose.yaml for cloudflared
   services:
     cloudflared-tunnel:
       networks:
         - cloudflared

   networks:
     cloudflared:
       external: true
   ```

   ```yaml
   # docker-compose.yaml for Traefik
   services:
     traefik:
       container_name: traefik
       networks:
         - cloudflared
         - proxy  # Network for your applications
       labels:
         - "traefik.enable=true"

   networks:
     cloudflared:
       external: true
     proxy:
       external: true
   ```

### Ingress Rules Examples

Here are examples of different ingress configurations in `config.yaml`:

1. Basic domain forwarding to Traefik:
   ```yaml
   ingress:
     - hostname: "example.com"
       service: https://traefik:443
       originRequest:
         originServerName: "example.com"
         noTLSVerify: true
   ```

2. Wildcard subdomain forwarding:
   ```yaml
   ingress:
     - hostname: "*.example.com"
       service: https://traefik:443
       originRequest:
         originServerName: "example.com"
         noTLSVerify: true
   ```

3. Multiple domains with different services:
   ```yaml
   ingress:
     # Main application through Traefik
     - hostname: "app1.example.com"
       service: https://traefik:443
       originRequest:
         originServerName: "app1.example.com"
         noTLSVerify: true
     
     # Direct service access (bypassing Traefik)
     - hostname: "app2.example.com"
       service: http://direct-service:8080
       
     # Catch-all rule
     - service: http_status:404
   ```

### Important Notes for Traefik Configuration

1. Traefik Setup:
   - Traefik handles SSL/TLS with Cloudflare certificates
   - Use HTTPS (port 443) when connecting from Cloudflare tunnel
   - Configure Traefik to use Cloudflare certificates or Let's Encrypt
   - Set `noTLSVerify: true` when using self-signed certificates

2. Container Name vs IP:
   - Use container names (e.g., `traefik`) instead of IP addresses
   - Ensure all containers are on the same Docker network
   - Container names are automatically resolved within the Docker network

3. Network Configuration:
   - Create separate networks for:
     - `cloudflared`: Connecting Cloudflare tunnel to Traefik
     - `proxy`: Connecting Traefik to your applications
   ```bash
   docker network create cloudflared
   docker network create proxy
   ```

4. Fixing "Certificate not valid for any names" Error:
   There are several ways to fix this error:

   a. Using `originServerName`:
   ```yaml
   ingress:
     - hostname: "*.example.com"
       service: https://traefik:443
       originRequest:
         # anysubbdomain.example.com must exist in Cloudflare DNS records
         originServerName: "anysubdomain.example.com"
         noTLSVerify: true
   ```

   b. Using Cloudflare Origin Certificate:
   1. Generate an origin certificate in Cloudflare:
      - Go to SSL/TLS > Origin Server in your Cloudflare dashboard
      - Create a certificate for your domains
      - Install the certificate in Traefik
   
   c. Disable TLS Verification (Not recommended for production):
   ```yaml
   ingress:
     - hostname: "app.example.com"
       service: https://traefik:443
       originRequest:
         noTLSVerify: true
   ```

5. Troubleshooting:
   - Verify Traefik's dynamic configuration is properly set up
   - Check Traefik's dashboard for routing issues
   - Ensure DNS records are configured in Cloudflare
   - Monitor Traefik's access logs for connection issues
   - For certificate errors:
     - Verify the `originServerName` matches your SSL certificate's domain
     - Check if your certificate is valid and not expired
     - Ensure the certificate covers all required domains

## Important Notes

- HTTP/2 should be enabled when using with Nginx Proxy Manager
- Always use `originServerName` when connecting to services with SSL/TLS
- For production environments, use Cloudflare Origin Certificates instead of disabling TLS verification
- Consider using Cloudflare origin certificates for enhanced security
- Make sure your main domain is properly configured in Nginx
- The configuration includes examples for both direct proxy and subdomain routing

## References

- [Cloudflare Tunnel Origin Configuration Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/configuration-file/)
- [Docker Setup Guide](https://thedxt.ca/2022/10/cloudflare-tunnel-with-docker/)
- [Cloudflare Container Repository](https://hub.docker.com/r/cloudflare/cloudflared/tags)
- [GitHub - aeleos/cloudflared: Cloudflare Tunnel Instructions and Template for Unraid](https://github.com/aeleos/cloudflared?tab=readme-ov-file#certificate-not-valid-for-any-names)