# Customizing APT Timer Settings

This guide explains how to customize the timing of APT updates and upgrades using systemd timer overrides.

## APT Daily Updates Timer

To customize when APT checks for updates:

1. Create a systemd override for the apt-daily timer:
```bash
sudo systemctl edit apt-daily.timer
```

2. Add the following configuration (example for 2 AM JST):
```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* 02:00:00 Asia/Tokyo
RandomizedDelaySec=1m
```

## APT Upgrade Timer

To customize when APT performs upgrades:

1. Create a systemd override for the apt-daily-upgrade timer:
```bash
sudo systemctl edit apt-daily-upgrade.timer
```

2. Add the following configuration (example for weekends 2-4 AM JST):
```ini
[Timer]
OnCalendar=
OnCalendar=Sat,Sun *-*-* 02:00:00 Asia/Tokyo
RandomizedDelaySec=2h
```

## Notification System Setup

The notification system consists of three components:

1. **Notification Script** (`unattended-upgrades-notify.sh`):
   - Monitors unattended upgrade logs
   - Sends notifications via:
     - Gotify for successful updates and errors
     - Healthchecks for monitoring script execution
   - Checks for system reboot requirements

2. **Path Unit** (`unattended-upgrades-notify.path`):
   - Monitors `/var/lib/apt/periodic/upgrade-stamp` for changes
   - This stamp file is updated by `apt-daily-upgrade.service` only after a successful unattended upgrade
   - Ensures notifications are only triggered for successful upgrades

3. **Service Unit** (`unattended-upgrades-notify.service`):
   - Executes when triggered by the path unit
   - Runs the notification script
   - Operates independently of unattended-upgrades

### How It Works

1. The upgrade process chain:
   - `apt-daily-upgrade.timer` activates at scheduled times (configurable, see timer settings above)
   - Timer triggers `apt-daily-upgrade.service`
   - The service executes the unattended upgrade process
   - On successful upgrade, it updates `/var/lib/apt/periodic/upgrade-stamp`
   - If upgrade fails or is skipped, the stamp file remains unchanged

2. The notification chain:
   - The path unit monitors the stamp file
   - When a successful upgrade updates the stamp
   - It triggers the notification service
   - Service waits for network services to be ready
   - Notifications are sent via Gotify and Healthchecks

### Service Dependencies

The notification service requires:
- Network connectivity (through network.target and network-online.target)
- Network service managers (systemd-networkd.service, NetworkManager.service, or connman.service)
- Completion of apt-daily-upgrade.service

This ensures notifications are only sent when:
1. The network is fully available
2. The upgrade process has completed
3. The system can reach notification endpoints

### Installation

1. Copy the script to system bin:
```bash
sudo cp unattended-upgrades-notify.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/unattended-upgrades-notify.sh
```

2. Install systemd units:
```bash
sudo cp unattended-upgrades-notify.path /etc/systemd/system/
sudo cp unattended-upgrades-notify.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now unattended-upgrades-notify.path
```

3. Configure notification endpoints:
   Edit the script and set your notification endpoints:

```bash
HEALTHCHECKS_BASE_URL="https://healthchecks.yourdomain"
HEALTHCHECKS_UUID="your-uuid"
GOTIFY_URL="https://gotify.yourdomain"
GOTIFY_TOKEN="your-token"
GOTIFY_HOSTNAME="your-hostname"
```

## Testing

To safely test the notification system without interfering with the actual upgrade stamp:

1. Create a temporary test file and modify the path unit:
```bash
# Create test file
sudo touch /tmp/test-upgrade-stamp

# Temporarily modify the path unit
sudo systemctl edit --full unattended-upgrades-notify.path
```

Add these contents to the path unit:
```ini
[Unit]
Description=Watch for unattended upgrades stamp file changes

[Path]
PathChanged=/tmp/test-upgrade-stamp

[Install]
WantedBy=multi-user.target
```

2. Reload and restart the path unit:
```bash
sudo systemctl daemon-reload
sudo systemctl restart unattended-upgrades-notify.path
```

3. Test the notification:
```bash
# Trigger the notification by updating the test file
sudo touch /tmp/test-upgrade-stamp
```

4. After confirming it works, restore the original path:
```bash
# Remove the override
sudo systemctl revert unattended-upgrades-notify.path

# Reload and restart with original configuration
sudo systemctl daemon-reload
sudo systemctl restart unattended-upgrades-notify.path
```

## Applying Changes

After making changes:
```bash
sudo systemctl daemon-reload
sudo systemctl restart apt-daily.timer apt-daily-upgrade.timer
```

## Verify Timer Settings

Check timer status:
```bash
systemctl status apt-daily.timer
systemctl status apt-daily-upgrade.timer
```

View next scheduled times:
```bash
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer
```

## Notes
- `OnCalendar`: Specifies when the timer should trigger
- `RandomizedDelaySec`: Adds random delay to prevent system load spikes
  - 1m (1 minute) for updates
  - 2h (2 hours) for upgrades
- Time zone must be specified in the format `Area/City` (e.g., `Asia/Tokyo`)

## References
- [UnattendedUpgrades](https://wiki.debian.org/UnattendedUpgrades)