FROM tailscale/tailscale:v1.78.3 as build

FROM semaphoreui/semaphore:v2.11.3

COPY --from=build /usr/local/bin/tailscale /usr/local/bin/tailscale