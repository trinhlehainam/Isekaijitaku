# https://hub.docker.com/r/tailscale/tailscale/tags
FROM tailscale/tailscale:v1.82.0 as tailscale

# https://hub.docker.com/r/semaphoreui/semaphore/tags
FROM semaphoreui/semaphore:v2.13.7

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale