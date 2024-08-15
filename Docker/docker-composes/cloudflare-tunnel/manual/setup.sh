#!/bin/bash

# NOTE: you may need to change folder permission of <PATH_TO_CONFIG_FOLDER> to 777 for Docker can write to it
# https://github.com/aeleos/cloudflared/issues/20

# Login
docker run -it --rm -v <PATH_TO_CONFIG_FOLDER>:/home/nonroot/.cloudflared/ cloudflare/cloudflared:2024.6.1-amd64 tunnel login 

# Create tunnel
docker run -it --rm -v <PATH_TO_CONFIG_FOLDER>:/home/nonroot/.cloudflared/ cloudflare/cloudflared:2024.6.1-amd64 tunnel create TUNNEL_NAME
