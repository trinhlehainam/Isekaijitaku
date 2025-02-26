# https://hub.docker.com/r/tailscale/tailscale/tags
FROM tailscale/tailscale:v1.80.0 as tailscale

# https://hub.docker.com/r/semaphoreui/semaphore/tags
FROM semaphoreui/semaphore:v2.12.14

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale