# Forgejo Backup and Restore

This document provides detailed information about backing up and restoring a Forgejo instance deployed with this Ansible role.

## Overview

The backup system creates consistent backups of both Forgejo and its PostgreSQL database. Following official Gitea/Forgejo recommendations, the implementation ensures that the Forgejo service is completely shut down during the entire backup process to avoid race conditions and data inconsistency, while performing backups through the container with custom commands and using Docker's copy capabilities.

## Backup Consistency

According to Gitea/Forgejo documentation:

> To ensure the consistency of the Gitea instance, it must be shutdown during backup.
>
> Gitea consists of a database, files and git repositories, all of which change when it is used. For instance, when a migration is in progress, a transaction is created in the database while the git repository is being copied over. If the backup happens in the middle of the migration, the git repository may be incomplete although the database claims otherwise because it was dumped afterwards. The only way to avoid such race conditions is by stopping the Gitea instance during the backups.

Our implementation follows this guidance by:
1. Completely stopping the primary Forgejo service
2. Using the Forgejo container with a custom command (not launching the server)
3. Creating backups within the container and copying them out using Docker's copy mechanism
4. Only restarting the Forgejo service after backup completion (unless in update mode)

## The Docker Container Copy Approach

The implementation leverages both Docker's command execution and container copy capabilities:

1. **During Normal Operation:**
   - The Forgejo container launches the server with `web` command
   - Full network exposure and all services running

2. **During Backup:**
   - The Forgejo server is completely stopped
   - A temporary Forgejo container instance is launched with backup commands
   - The commands create backup archives within the container
   - The archives are then copied from the container to the host using Docker's container copy feature
   - File ownership and permissions are properly set on the host
   - Temporary files inside containers are cleaned up
   - No services are running or exposed during the backup

This approach ensures complete data consistency while providing efficient file transfer using Docker's native capabilities.

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `forgejo_backup_location` | Directory where backups are stored | `{{ forgejo_project_src }}/backups` |
| `forgejo_backup_keep_days` | Number of days to keep backups before automatic deletion | `7` |
| `forgejo_update_mode` | When true, service remains stopped after successful backup | `false` |

## Backup Modes

### Standard Mode

In standard mode (`forgejo_update_mode: false`), the backup process:

1. Stops the primary Forgejo service
2. Runs temporary Forgejo container with backup commands
3. Creates backups within containers and copies them to the host
4. Restarts the primary Forgejo service
5. Confirms service health
6. Generates a backup report

This mode is ideal for routine backups where you want the service to return to operation immediately after the backup is completed.

### Update Mode

In update mode (`forgejo_update_mode: true`), the backup process:

1. Stops the primary Forgejo service
2. Runs temporary Forgejo container with backup commands
3. Creates backups within containers and copies them to the host
4. Keeps the primary service stopped if backup is successful
5. Restarts the primary service only if backup fails
6. Generates a backup report

This mode is designed specifically for updates and maintenance where you want to perform additional tasks after the backup while the service is down. The service will automatically restart if the backup process fails, ensuring that a failing backup doesn't leave the service in an unintended stopped state.

## Backup Method

The backup approach uses Docker container commands and copy operations:

1. **PostgreSQL:**
   - The database container runs a tar command to create a backup of the PostgreSQL data directory
   - The backup file remains in the container's temp directory
   - Ansible then uses `docker_container_copy_into` to copy the backup file from the container to the host
   - File ownership and permissions are set correctly on the host
   - This produces a binary backup that includes all databases, users, and configuration

2. **Forgejo:**
   - A temporary Forgejo container instance runs a tar command to create a backup of the Forgejo data directory
   - The backup file remains in the container's temp directory
   - Ansible then uses `docker_container_copy_into` to copy the backup file from the container to the host
   - File ownership and permissions are set correctly on the host
   - Creates a compressed tarball containing all repositories, configuration, and application data
   - Preserves file permissions and ownership

This approach ensures complete consistency as the primary Forgejo service remains stopped during the backup process, preventing any possible race conditions, while efficiently transferring files using Docker's native copy capabilities.

## Backup Files

Each backup is stored in a unified timestamp-based directory structure:

```
backups/
└── backup_20250305194527/
    ├── app/
    │   └── forgejo-data.tar.gz    # Complete Forgejo data backup
    ├── db/
    │   └── postgres-data.tar.gz   # PostgreSQL data backup
    └── backup-report.txt          # Backup details and status
```

This organized structure provides:
- Clear association between related backup files
- Easy identification of complete backup sets
- Simple restoration from a single directory
- Straightforward backup rotation (entire directories are pruned based on age)

## Running a Backup

### Standard Backup

To run a standard backup with service restart:

```bash
ansible-playbook site.yml -i inventories/[env]/hosts.yml --tags "backup"
```

### Pre-Update Backup

To run a backup before updates, keeping the service stopped:

```bash
ansible-playbook site.yml -i inventories/[env]/hosts.yml --tags "update"
```

This command uses the pre-configured update mode in the playbook, which automatically sets `forgejo_update_mode: true`.

Alternatively, you can explicitly set the update mode for a backup:

```bash
ansible-playbook site.yml -i inventories/[env]/hosts.yml --tags "backup" -e "forgejo_update_mode=true"
```

## Restoring from Backup

To restore from a backup, follow these steps:

1. Stop the Forgejo containers:
   ```bash
   cd [forgejo_project_src]
   docker-compose down
   ```

2. Restore the PostgreSQL data:
   ```bash
   # Extract PostgreSQL backup
   mkdir -p /tmp/postgres-restore
   tar -xzf [forgejo_backup_dir]/backup_[timestamp]/db/postgres-data.tar.gz -C /tmp/postgres-restore
   
   # Copy the data to your PostgreSQL data directory
   cp -r /tmp/postgres-restore/data/* [postgres_data_dir]/
   ```

3. Restore Forgejo data:
   ```bash
   # Extract the Forgejo data tarball
   mkdir -p /tmp/forgejo-restore
   tar -xzf [forgejo_backup_dir]/backup_[timestamp]/app/forgejo-data.tar.gz -C /tmp/forgejo-restore
   
   # Copy the data to your Forgejo data directory
   cp -r /tmp/forgejo-restore/gitea/* [forgejo_data_dir]/
   ```

4. Start the Forgejo containers:
   ```bash
   docker-compose up -d
   ```

## Technical Implementation

The backup process uses Docker container commands and native copy operations:

- **Service Management**
  - Regular Forgejo service is completely stopped during backup
  - Temporary container with backup commands executes instead of launching the server
  - This leverages the docker-entrypoint.sh behavior where passing a command executes that command instead of starting the server

- **Container-Based Backup with Docker Copy**
  - Uses `community.docker.docker_compose_v2` with commands to run tar operations inside containers
  - Creates tar archives of data directories within the containers
  - Uses `community.docker.docker_container_copy_into` to copy backup files from containers to the host
  - Sets proper ownership and permissions on the backup files
  - Cleans up temporary files from containers after backup

- **Data Consistency**
  - Regular Forgejo service remains completely stopped during backup
  - Database operations are performed within the database container itself
  - Temporary Forgejo container only performs backup operations, never runs the actual server
  - Complete isolation from network requests during backup

- **Zero Downtime for Database**
  - The PostgreSQL container remains running during backup
  - Database backups are created using commands inside the container
  - No need to restart PostgreSQL, avoiding long startup times

- **Unified Backup Storage**
  - All backup files are stored in a single timestamp-based directory
  - Backup rotation removes entire directories rather than individual files
  - Complete backup sets are preserved together for easier management

- **Error Handling and Reporting**
  - Each operation has robust error handling with proper error reporting
  - Success conditions are carefully tracked at each step
  - Operations are isolated in blocks with rescue handlers

This implementation follows Ansible best practices by leveraging Docker's native capabilities in a controlled manner, making the backup process both reliable and secure while maintaining simplicity and efficiency.

## Backup Report

Each backup generates a report containing:
- Timestamp of the backup
- Complete backup directory path
- Backup method details
- List of backup files included in the set
- Success/failure status
- Backup mode (standard or update)
- Service status after backup completion
- Service health check results (if applicable)

These reports are stored within the backup directory itself and provide a valuable audit trail of backup activity.
