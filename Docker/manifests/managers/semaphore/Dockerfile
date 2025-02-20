# https://hub.docker.com/r/tailscale/tailscale/tags
FROM tailscale/tailscale:v1.80.0 as tailscale

FROM semaphoreui/semaphore:v2.11.3

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale