#!/bin/bash
# https://github.com/influxdata/telegraf/blob/release-1.31/plugins/inputs/proxmox/README.md#permissions

pveum user add pve-exporter@pve
pveum acl modify / -role PVEAuditor -user pve-exporter@pve
## Create a token with the PVEAuditor role
pveum user token add pve-exporter@pve monitoring -privsep 1
pveum acl modify / -role PVEAuditor -token 'pve-exporter@pve!monitoring'
