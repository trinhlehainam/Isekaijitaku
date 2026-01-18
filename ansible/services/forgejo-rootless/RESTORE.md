---
aliases:
  - "Forgejo Rootless Restore Process"
tags:
  - manifest
---

# Forgejo Rootless Restore Process

This document outlines the Forgejo rootless service restore process implemented in the Ansible roles.

## Overview

The restore process is designed to recover Forgejo and PostgreSQL services from previously created backups. It follows a comprehensive approach to ensure proper service restoration:

1. Verifies all required backup files exist before attempting restoration
2. Preserves existing project configuration files in a timestamped backup directory
3. Restores Docker Compose and secrets files from backup
4. Backs up current data directories before removing them
5. Restores the PostgreSQL database using direct shell commands
6. Extracts and moves Forgejo application data to the appropriate locations
7. Starts services again after successful restoration
8. Generates a detailed timestamped restoration report

## Prerequisites

- A valid backup directory containing:
  - PostgreSQL backup file (`forgejo-db-backup.dump`)
  - Forgejo application backup file (`forgejo-app-dump.zip`)
  - Docker Compose configuration file (`setup/docker-compose.yml`)
  - Secrets directory (`setup/secrets/`)
- The Forgejo rootless Docker Compose environment properly configured
- `unzip` utility installed on the target system (automatically installed by Vagrant)

## Execution Process

The restore process works in the following sequence:

### Initial Verification
- Validates that the backup path exists
- Verifies all required backup files exist (PostgreSQL dump, Forgejo data, Docker Compose, and secrets)
- Creates a timestamp for the restoration operation
- Sets initial success/failure status variables

### Project Configuration Preservation
- Creates a `setup_before_restoration/TIMESTAMP` directory to store current configuration
- Safely moves existing docker-compose.yml to the backup location
- Moves existing secrets directory to the backup location
- Preserves the exact state of the project configuration before restoration

### Project Configuration Restoration
- Copies docker-compose.yml from backup to the project directory
- Copies secrets directory from backup to the project directory
- Ensures proper file permissions and ownership

### Service Management
- Directly removes all running Docker containers to ensure clean restoration
- Uses Docker Compose to ensure consistent service management

### Data Directory Handling
- Backs up current data directories to timestamped archive files
- Removes current data directories to prevent conflicts
- Creates fresh, empty data directories

### Database Restoration
- Starts the PostgreSQL container temporarily
- Uses a direct shell command to execute pg_restore for better error handling
- Validates the restoration output to detect any issues
- Provides detailed error messages in case of failure

### Application Restoration
- Creates a temporary extraction directory
- Unzips the Forgejo backup file
- Validates that all required files exist in the backup
- Directly moves files from temporary location to destination paths for better performance
- Sets proper permissions on the configuration directory

### Service Restart
- Starts all services after successful restoration
- Waits for services to reach healthy state
- Handles failures appropriately with clear error messages

### Reporting
- Generates a detailed timestamped restoration report in Markdown format
- Includes success/failure status for each component with visual indicators
- Lists all restored files with their paths and status
- Records specific error information when available

## Usage

To restore from a backup, run the following command:

```bash
ansible-playbook site.yml --tags restore
```

This command will automatically find the most recent backup in the configured backup directory and restore from it.

If you want to restore from a specific backup directory, you can define the `forgejo_backup_dir` variable:

```bash
ansible-playbook site.yml --tags restore -e "forgejo_backup_dir=/path/to/your/backup/directory"
```

The system will then find the most recent backup timestamp within that directory and use it for restoration.

## Restoration Report

After completion, a timestamped `RESTORE_REPORT_YYYY-MM-DD_HH-MM.md` file is created in the backup directory with detailed information about:

- Timestamp of the restore operation
- Backup source path
- Project directory path
- Status of each component (PostgreSQL, Forgejo)
- List of all restored files with their paths and status
- Overall restoration status
- Any error messages or failures

## Important Notes

1. The restore process will **completely replace** current data and configuration. Always review the backup contents before restoring.
2. Both the application data and project configuration files are restored to ensure a complete recovery.
3. Original project files are preserved in the `setup_before_restoration/TIMESTAMP` directory as a safety measure.
4. Original data directories are automatically backed up before removal as a safety measure.
5. Services are automatically restarted after successful restoration.
6. The PostgreSQL database is restored using a clean approach, with existing objects dropped before recreation.
7. The restore process verifies that all required files exist in the backup before proceeding with the restore.
8. Temporary extraction directories are automatically cleaned up after successful restoration.

## References
- [[Upgrade PostgreSQL in Docker]]
- [Gitea Backup and Restore](https://gitea.com/gitea/docs/src/branch/main/docs/administration/backup-and-restore.md#restore-command-restore)
- [Forgejo Upgrade and Restore](https://forgejo.org/docs/latest/admin/upgrade/#verify-forgejo-works)