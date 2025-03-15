# Forgejo Rootless Restore Process

This document outlines the Forgejo rootless service restore process implemented in the Ansible roles.

## Overview

The restore process is designed to recover Forgejo and PostgreSQL services from previously created backups. It follows a comprehensive approach to ensure proper service restoration:

1. Verifies backup files exist before attempting restoration
2. Completely removes all running services to ensure a clean slate
3. Backs up current data directories before removing them
4. Restores the PostgreSQL database using direct shell commands
5. Extracts and moves Forgejo application data to the appropriate locations
6. Starts services again after successful restoration
7. Generates a detailed timestamped restoration report

## Prerequisites

- A valid backup directory containing at least one of:
  - PostgreSQL backup file (`forgejo-db-backup.dump`)
  - Forgejo application backup file (`forgejo-app-dump.zip`)
- The Forgejo rootless Docker Compose environment properly configured
- `unzip` utility installed on the target system (automatically installed by Vagrant)

## Execution Process

The restore process works in the following sequence:

### Initial Verification
- Validates the backup path exists and contains required backup files
- Creates a timestamp for the restoration operation
- Sets initial success/failure status variables

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
- Lists all restored files with their status
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
- Status of each component (PostgreSQL, Forgejo, Configuration)
- List of all restored files with their paths and status
- Overall restoration status
- Any error messages or failures

## Important Notes

1. The restore process will **completely replace** current data. Always review the backup contents before restoring.
2. Both partial (single component) and full (all components) restores are supported.
3. Original data directories are automatically backed up before removal as a safety measure.
4. Services are automatically restarted after successful restoration.
5. The PostgreSQL database is restored using a clean approach, with existing objects dropped before recreation.
6. The restore process verifies that all required files exist in the backup before proceeding with the restore.
7. Temporary extraction directories are automatically cleaned up after successful restoration.

## References
- [[Upgrade PostgreSQL in Docker]]
- [Gitea Backup and Restore](https://gitea.com/gitea/docs/src/branch/main/docs/administration/backup-and-restore.md#restore-command-restore)
- [Forgejo Upgrade and Restore](https://forgejo.org/docs/latest/admin/upgrade/#verify-forgejo-works)