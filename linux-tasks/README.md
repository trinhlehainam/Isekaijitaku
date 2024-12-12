# Linux Scheduled Tasks


## Tasks Included

### 1. Check Mount Points Status
- Script: `check-mount-points.sh`
- Service: `check-mount-points.service`
- Timer: `check-mount-points.timer`
- Runs every hour and checks if configured mount points are properly mounted
- Supports checking multiple mount points
- Reports status for each mount point and provides a final summary
- Integrates with Healthchecks.io for monitoring

## Installation

### Check Mount Points Setup
1. Create or copy the script file:
   ```bash
   # If you don't have the script file, create it:
   sudo nano /usr/local/bin/check-mount-points.sh
   # Copy the content from check-mount-points.sh in this repository
   # Or download it directly if available

   # If you have the script file:
   sudo cp check-mount-points.sh /usr/local/bin/

   # Set permissions
   sudo chmod +x /usr/local/bin/check-mount-points.sh
   ```

2. Create or copy the systemd service and timer files:
   ```bash
   # If you don't have the service file, create it:
   sudo nano /etc/systemd/system/check-mount-points.service
   ```
   Add this content:
   ```ini
   [Unit]
   Description=Check mount points status
   After=network.target

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/check-mount-points.sh

   [Install]
   WantedBy=multi-user.target
   ```

   ```bash
   # If you don't have the timer file, create it:
   sudo nano /etc/systemd/system/check-mount-points.timer
   ```
   Add this content:
   ```ini
   [Unit]
   Description=Run mount points check hourly

   [Timer]
   OnCalendar=hourly
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

   If you have the files, simply copy them:
   ```bash
   sudo cp check-mount-points.service /etc/systemd/system/
   sudo cp check-mount-points.timer /etc/systemd/system/
   ```

3. Configure the script:
   - Edit `/usr/local/bin/check-mount-points.sh`
   - Update the following variables:
     ```bash
     HEALTHCHECKS_URL="https://healthchesks.yourdomain"
     HEALTHCHECKS_UUID="your-healthchecks-uuid"
     MOUNT_POINTS=(
         "/path/to/mount1"
         "/path/to/mount2"
     )
     ```

4. Enable and start the timer:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable check-mount-points.timer
   sudo systemctl start check-mount-points.timer
   ```

5. Verify the setup:
   ```bash
   # Check timer status
   systemctl status check-mount-points.timer
   
   # Check next scheduled run
   systemctl list-timers check-mount-points.timer
   
   # Test the script manually
   sudo /usr/local/bin/check-mount-points.sh
   ```

## Notes
- The script uses `findmnt` to check mount points status
- Failed checks are reported to Healthchecks.io if configured
- The timer runs hourly by default, adjust the timer file if needed
- Logs can be viewed using `journalctl -u check-mount-points.service`
- Standard system directories will typically exist, but the `mkdir -p` commands ensure they're created if needed
- The `-p` flag in `mkdir` creates parent directories as needed and doesn't error if directories already exist

## References
- [findmnt command guide](https://linuxhandbook.com/findmnt-command-guide/) - Detailed guide on using the findmnt command
- [Healthchecks.io Bash guide](https://healthchecks.io/docs/bash/) - Documentation for integrating Bash scripts with Healthchecks.io
- [Blog - SystemD Timers vs. Cron Jobs](https://akashrajpurohit.com/blog/systemd-timers-vs-cron-jobs/)