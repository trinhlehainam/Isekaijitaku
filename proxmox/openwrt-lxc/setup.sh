#!/bin/bash

# https://gist.github.com/suuhm/053f819b000bee4af922d66ff6c5d32e 
# https://dft.wiki/?p=3271

LXC_ID=101
LXC_HOSTNAME=openwrt-lxc
IMAGE_PATH=/var/lib/vz/template/cache/openwrt-lxc-image.tar.xz
ARCH=amd64 # arm64 | amd64
DISK_AMOUNT=0.512
MEMORY_AMOUNT=256
CORES=1

pct create "$LXC_ID" "$IMAGE_PATH" --arch "$ARCH"  --hostname "$LXC_HOSTNAME" --rootfs local-lvm:"$DISK_AMOUNT" --memory "$MEMORY_AMOUNT" --cores "$CORES" --ostype unmanaged --unprivileged 1
