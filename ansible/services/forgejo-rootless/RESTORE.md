# Forgejo Rootless Restore Process

This document outlines the Forgejo rootless service restore process implemented in the Ansible roles.

## Overview

The restore process is designed to recover Forgejo and PostgreSQL services from previously created backups. It follows a comprehensive approach to ensure proper service restoration:

1. Verifies backup files exist before attempting restoration
2. Stops all running services to prevent conflicts
3. Backs up current data directories before removing them
4. Restores the PostgreSQL database using Docker's native capabilities
5. Extracts and restores Forgejo application data to the appropriate locations
6. Starts services again after successful restoration
7. Generates a detailed restoration report

## Prerequisites

- A valid backup directory containing at least one of:
  - PostgreSQL backup file (`forgejo-db-backup.dump`)
  - Forgejo application backup file (`forgejo-app-dump.zip`)
- The Forgejo rootless Docker Compose environment properly configured

## Execution Process

The restore process works in the following sequence:

### Initial Verification
- Validates the backup path exists and contains required backup files
- Creates a timestamp for the restoration operation
- Sets initial success/failure status variables

### Service Management
- Checks current service status
- Stops all running Forgejo and PostgreSQL services

### Data Directory Handling
- Backs up current data directories to timestamped archive files
- Removes current data directories to prevent conflicts
- Creates fresh, empty data directories

### Database Restoration
- Starts the PostgreSQL container temporarily
- Copies the backup dump file to the container
- Executes `pg_restore` to restore the database
- Handles common error scenarios gracefully

### Application Restoration
- Creates a temporary extraction directory
- Unzips the Forgejo backup file
- Copies data and repository files to appropriate locations
- Sets proper ownership for rootless operation

### Service Restart
- Starts all services after successful restoration
- Handles failures appropriately with clear error messages

### Reporting
- Generates a detailed restoration report in Markdown format
- Includes success/failure status for each component
- Records specific error information when available

## Usage

To restore from a backup, run the following command:

```bash
ansible-playbook site.yml -e "operation=restore backup_path=/path/to/your/backup"
```

Where:
- `operation=restore` triggers the restore process
- `backup_path` specifies the full path to the backup directory

## Restoration Report

After completion, a `RESTORE_REPORT.md` file is created in the backup directory with detailed information about:

- Timestamp of the restore operation
- Status of each component (PostgreSQL, Forgejo)
- Overall restoration status
- Any error messages or failures

## Important Notes

1. The restore process will **completely replace** current data. Always review the backup contents before restoring.
2. Both partial (single component) and full (all components) restores are supported.
3. Original data directories are automatically backed up before removal as a safety measure.
4. Services are automatically restarted after successful restoration.
5. The PostgreSQL database is restored using a clean approach, with existing objects dropped before recreation.
