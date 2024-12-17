# Linux External Drive Mount Checker

## Overview
This tool provides automated monitoring of external drive mounts on Linux systems. It includes:

- Verification of device presence and mount status
- Drive health checking (if smartmontools is installed)
- Space usage reporting
- Integration with Healthchecks.io for monitoring

### Components
- Script: `check-external-drives-mounted.sh`
- Service: `check-external-drives-mounted.service`
- Timer: `check-external-drives-mounted.timer`

## Features
- Checks if external drives are properly connected and mounted
- Verifies mount points against specific devices
- Reports drive health status (requires smartmontools)
- Monitors available space and usage
- Runs hourly checks via systemd timer
- Integrates with Healthchecks.io for monitoring

## Prerequisites
- Linux system with systemd
- bash shell
- `findmnt` command (usually part of util-linux)
- Optional: `smartmontools` for drive health checking

## Installation

1. Install required packages:
   ```bash
   sudo apt-get update
   sudo apt-get install smartmontools  # Optional, for drive health checking
   ```

2. Create or copy the script file:
   ```bash
   sudo cp check-external-drives-mounted.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/check-external-drives-mounted.sh
   ```

3. Configure the script:
   Edit `/usr/local/bin/check-external-drives-mounted.sh` and update:
   ```bash
   HEALTHCHECKS_URL="https://healthchesks.yourdomain"
   HEALTHCHECKS_UUID=""
   EXTERNAL_DRIVES=(
       "/dev/sdb1:/mnt/external"    # Format: device:mountpoint
       "/dev/sdc1:/mnt/backup"      # Add your drives here
   )
   ```

4. Set up systemd service and timer:
   ```bash
   sudo cp check-external-drives-mounted.service /etc/systemd/system/
   sudo cp check-external-drives-mounted.timer /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable check-external-drives-mounted.timer
   sudo systemctl start check-external-drives-mounted.timer
   ```

## Usage

### Manual Check
Test the script manually:
```bash
sudo /usr/local/bin/check-external-drives-mounted.sh
```

### Check Service Status
```bash
# View timer status
systemctl status check-external-drives-mounted.timer

# List next scheduled runs
systemctl list-timers check-external-drives-mounted.timer

# View recent logs
journalctl -u check-external-drives-mounted.service
```

## Troubleshooting

### Common Issues

1. Drive Not Detected
   - Verify the device exists: `ls -l /dev/sdX`
   - Check dmesg for hardware issues: `dmesg | grep sdX`
   - List all block devices: `lsblk -f`

2. Mount Point Issues
   - Verify mount point exists: `ls -l /path/to/mount`
   - Check fstab entries: `cat /etc/fstab`
   - Manual mount test: `mount /dev/sdX /mount/point`
   - List all mounts: `findmnt -l`

3. Drive Health Warnings
   - Check SMART details: `smartctl -a /dev/sdX`
   - View drive logs: `smartctl -l error /dev/sdX`
   - Check drive temperature: `smartctl -A /dev/sdX | grep Temperature`

## Logs

The script logs to `/var/log/check-external-drives-mounted.log` and systemd journal. View logs:
```bash
# View script logs
tail -f /var/log/check-external-drives-mounted.log

# View systemd service logs
journalctl -u check-external-drives-mounted.service -f
```

## References
- [findmnt command guide](https://linuxhandbook.com/findmnt-command-guide/) - Detailed guide on using the findmnt command
- [Healthchecks.io Bash guide](https://healthchecks.io/docs/bash/) - Documentation for integrating Bash scripts with Healthchecks.io
- [SystemD Timers vs. Cron Jobs](https://akashrajpurohit.com/blog/systemd-timers-vs-cron-jobs/)
- [PSA: Stop using mount to list mounts](https://www.reddit.com/r/linuxadmin/comments/13fjqg2/psa_stop_using_mount_to_list_mounts/)