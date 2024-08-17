#!/bin/bash

# https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/
docker network create -d macvlan -o parent=eth0 \
  --subnet 10.10.10.0/24 \
  --gateway 10.10.10.1 \
  --ip-range 10.10.10.0/27 \
  --aux-address "host=10.10.10.3" \
  openwrt_vlan
