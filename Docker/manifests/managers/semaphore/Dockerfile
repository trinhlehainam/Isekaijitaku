FROM tailscale/tailscale:v1.78.3 as tailscale

FROM semaphoreui/semaphore:v2.11.3

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale