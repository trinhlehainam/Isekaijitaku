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

The notification system consists of two components:

1. **Notification Script** (`unattended-upgrades-notify.sh`):
   - Monitors unattended upgrade logs
   - Sends notifications via:
     - Gotify for successful updates and errors
     - Healthchecks for monitoring script execution
   - Checks for system reboot requirements

2. **Service Unit** (`unattended-upgrades-notify.service`):
   - Executes automatically after unattended-upgrades completes
   - Ensures notifications are sent only once per upgrade session
   - Integrated with systemd dependency chain

### Installation

1. Copy the script to system bin:
```bash
sudo cp unattended-upgrades-notify.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/unattended-upgrades-notify.sh
```

2. Install systemd service:
```bash
sudo cp unattended-upgrades-notify.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable unattended-upgrades-notify.service
```

3. Configure notification endpoints:
   Edit the script and set your notification endpoints:
   ```bash
   HEALTHCHECKS_BASE_URL="https://healthchecks.yourdomain"
   HEALTHCHECKS_UUID="your-uuid"
   GOTIFY_URL="https://gotify.yourdomain"
   GOTIFY_TOKEN="your-token"
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