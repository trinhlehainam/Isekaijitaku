---
aliases:
  - "Nextcloud Docker Cron Job Setup"
tags:
  - manifest
---

# Nextcloud Cron Job Setup

This directory contains scripts and configuration files for managing Nextcloud cron jobs and maintenance windows in a Docker environment.

## Files Overview

- `docker-nextcloud-cron.sh`: Main script that executes the Nextcloud cron job. Features:
  - Healthchecks.io integration for monitoring
  - Background jobs status reporting
  - Comprehensive error handling
  - Detailed logging
  - Container status verification

- `docker-nextcloud-cron.service`: Systemd service unit file for running the cron job
- `docker-nextcloud-cron.timer`: Systemd timer unit for scheduling cron job execution every 5 minutes

- `set-docker-nextcloud-maintenance.sh`: Script to manage setting Nextcloud container maintenance time. Features:
  - System and container timezone configuration
  - Maintenance window time configuration
  - Time format validation
  - Timezone validation
  - Current configuration display
  - Flexible command-line options

## File Creation

To set up the Nextcloud cron job system, ensure you have the following files in place:

1. `docker-nextcloud-cron.service` (Systemd service unit):
   - Location: `/etc/systemd/system/docker-nextcloud-cron.service`
   - Purpose: Defines the service for running the cron job
   - Create this file and copy the service unit configuration

2. `docker-nextcloud-cron.timer` (Systemd timer unit):
   - Location: `/etc/systemd/system/docker-nextcloud-cron.timer`
   - Purpose: Schedules the cron job to run every 5 minutes
   - Create this file and copy the timer unit configuration

3. `docker-nextcloud-cron.sh` (Main script):
   - Location: `/usr/local/bin/docker-nextcloud-cron.sh`
   - Purpose: Executes Nextcloud cron jobs and handles monitoring
   - Create this file and copy the script content
   - Make it executable: `chmod +x /usr/local/bin/docker-nextcloud-cron.sh`

4. `set-docker-nextcloud-maintenance.sh` (Maintenance script):
   - Location: In your scripts directory
   - Purpose: Manages timezone and maintenance window settings
   - Create this file and copy the script content
   - Make it executable: `chmod +x set-docker-nextcloud-maintenance.sh`

After creating these files:
1. Reload systemd daemon: `sudo systemctl daemon-reload`
2. Enable and start the timer: 
   ```bash
   sudo systemctl enable docker-nextcloud-cron.timer
   sudo systemctl start docker-nextcloud-cron.timer
   ```

## Setup Instructions

1. Copy the scripts to appropriate locations:
   ```bash
   # Copy cron job script
   sudo cp docker-nextcloud-cron.sh /usr/local/bin/
   
   # Copy systemd files
   sudo cp docker-nextcloud-cron.{service,timer} /etc/systemd/system/
   ```

2. Make the scripts executable:
   ```bash
   sudo chmod +x /usr/local/bin/docker-nextcloud-cron.sh
   chmod +x set-docker-nextcloud-maintenance.sh
   ```

3. Configure timezone and maintenance window:
   ```bash
   # View available options
   ./set-docker-nextcloud-maintenance.sh --help
   
   # List available timezones
   timedatectl list-timezones
   
   # Examples:
   # Set both maintenance time and timezone
   ./set-docker-nextcloud-maintenance.sh "04:00" "Asia/Tokyo"
   
   # Set timezone only
   ./set-docker-nextcloud-maintenance.sh - "Europe/London"
   
   # Set maintenance time only
   ./set-docker-nextcloud-maintenance.sh "03:00"
   ```

4. Configure Healthchecks monitoring (optional):
   Edit `/usr/local/bin/docker-nextcloud-cron.sh` and update:
   ```bash
   HEALTHCHECKS_URL="https://your-healthchecks-instance"
   HEALTHCHECKS_UUID="your-uuid-here"
   ```

5. Enable and start the timer:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable docker-nextcloud-cron.timer
   sudo systemctl start docker-nextcloud-cron.timer
   ```

## Monitoring and Troubleshooting

1. Check cron job logs:
   ```bash
   sudo journalctl -u docker-nextcloud-cron.service
   # or
   sudo tail -f /var/log/docker-nextcloud-cron.log
   ```

2. Check timer status:
   ```bash
   sudo systemctl status docker-nextcloud-cron.timer
   sudo systemctl list-timers docker-nextcloud-cron.timer
   ```

3. Check Nextcloud background jobs:
   ```bash
   # Via the cron script
   sudo /usr/local/bin/docker-nextcloud-cron.sh
   
   # Or directly
   docker exec -u www-data nextcloud php occ background:queue:status
   ```

4. Verify timezone settings:
   ```bash
   # Show all current settings
   ./set-docker-nextcloud-maintenance.sh --help
   
   # Or check individual components
   timedatectl status
   ```

## References
- [Docker Nextcloud cron job](https://help.nextcloud.com/t/nextcloud-docker-container-best-way-to-run-cron-job/157734/4)
- [Nextcloud cron jobs](https://docs.nextcloud.com/server/30/admin_manual/configuration_server/background_jobs_configuration.html)
- [Nextcloud Maintenance Window Local Timer Converter](https://help.nextcloud.com/t/server-has-no-maintenance-window-start-time-configured/180480/22)
- [How to set date & time from Linux command prompt](https://www.cyberciti.biz/faq/howto-set-date-time-from-linux-command-prompt/)