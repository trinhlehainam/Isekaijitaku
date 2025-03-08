# Forgejo Backup System

This document describes the backup functionality for Forgejo and PostgreSQL databases in a Docker-based deployment. The system implements a hierarchical error handling approach with service state preservation that ensures data consistency, robust failure recovery, and intelligent service restoration.

## Backup Architecture

The backup process employs a sophisticated error handling structure with the following key features:

1. **Hierarchical Error Handling**: Three-level nested block/rescue structure (overall process → component process → individual tasks) that captures and tracks failures at each level.

2. **Component Isolation**: Each backup component (Forgejo and PostgreSQL) executes in its own block with independent error handling, allowing one component to fail without affecting the execution of the other.

3. **Smart Service State Preservation**: Captures detailed container state information before shutdown to enable precise service recovery.

4. **Container Health Detection**: Provides accurate container health status detection with support for multiple health states (healthy, starting, unhealthy).

5. **State-Aware Service Recovery**: Uses captured service state information to intelligently restore services to their original running state after backup operations.

6. **Detailed Error Reporting**: Captures specific error information at each level and includes it in the backup report.

7. **Resource Cleanup Guarantees**: Always sections ensure cleanup tasks execute regardless of success or failure.

## Backup Process Flow

The backup process follows these steps:

1. Checks and captures detailed service state information using Docker's native container inspection
2. Stops all Forgejo services to ensure data consistency while preserving their original state
3. Sets up backup variables including timestamps and file paths
4. Launches a dedicated Forgejo backup container that remains active during the backup process
5. Runs the Forgejo dump command in the backup container using predefined paths
6. Backs up the PostgreSQL database using `pg_dump` with the custom format (-Fc)
7. Copies the backup files from containers to the host system using consistent path references
8. Verifies container existence before performing cleanup operations
9. Cleans up temporary files in containers
10. Creates a backup report with detailed component status and error information
11. Notifies the service recovery handler to restore services to their original state
12. Recovers services to their original state (running or stopped) based on preserved state information

## Running Backups

To run a backup with automatic service recovery afterward:

```bash
ansible-playbook site.yml -i inventories/production/hosts.yml -t backup
```

The system will intelligently recover services to their original state after backup completion, regardless of success or failure. This ensures services are properly restored to their pre-backup state, maintaining the expected service availability through state-aware recovery handlers.

### Configuration Options

The backup system supports the following configuration options:

| Variable | Description | Default |
|----------|-------------|---------|
| `forgejo_backup_dir` | Directory where backups are stored | `<forgejo_project_src>/backups` |
| `forgejo_backup_filename` | Filename for Forgejo application backup | `forgejo-app-dump.zip` |
| `postgres_backup_filename` | Filename for PostgreSQL database backup | `forgejo-db-backup.dump` |

You can set these variables in your inventory files or pass them as extra vars when running the playbook.

### Backup File Structure

Backups are stored in the configured backup directory (default: `backups` directory within the Forgejo project directory). Each backup is stored in a timestamped directory with the following structure:

```
<forgejo_backup_dir>/
  └── YYYYMMDD-HHMMSS/
      ├── BACKUP_REPORT.md    # Detailed backup status report
      ├── forgejo-app-dump.zip  # Forgejo application data dump
      └── forgejo-db-backup.dump  # PostgreSQL database dump
```

## Backup Technology

The backup system integrates multiple technologies to ensure reliable backups:

- **Docker Compose V2**: Controls service lifecycle and launches backup containers
- **Docker Container Exec**: Executes backup commands within running containers
- **Forgejo dump**: Creates consistent application snapshots with official tooling
- **pg_dump**: Generates consistent PostgreSQL backups in custom format (-Fc) for optimal restoration
- **docker cp**: Transfers backup files from containers to the host filesystem
- **Container lifecycle management**: Manages dedicated backup containers with controlled lifecycles
- **Ansible handlers**: Provides reliable service restoration even after failures through task inclusion
- **Hierarchical error handling**: Employs block/rescue/always structures for robust failure management
- **Centralized backup paths**: Uses variables to consistently define and reference backup file paths
- **Container existence verification**: Checks for container existence before attempting cleanup operations
- **Force handlers execution**: Ensures service restoration handlers run even when the playbook fails

### Service State Preservation and Recovery

The backup system includes a sophisticated service state preservation and recovery mechanism:

1. **Service State Capture**: Before stopping services, the system captures detailed information about the running containers:
   - Container IDs and names
   - Service names from Docker Compose labels
   - Running state (running or stopped)
   - Health status (healthy, starting, unhealthy)
   - Other metadata such as uptime and image information

2. **State-Aware Recovery Handler**: After backup completion, a specialized handler restores each service to its original state:

```yaml
- name: Recover services
  community.docker.docker_compose_v2:
    project_src: "{{ forgejo_project_src }}"
    services: "{{ item.service }}"
    state: "{{ 'present' if item.state == 'running' else 'stopped' }}"
  when: forgejo_project_src is defined and check_result is defined and check_result.services is defined
  loop: "{{ check_result.services }}"
  loop_control:
    label: "{{ item.service }}"
```

This handler uses container state information preserved in `check_result.services` to determine whether each service should be running or stopped after backup.

3. **Health State Detection**: The system detects container health status using Docker's native health checks:
   - `healthy`: Container is running and passing health checks
   - `starting`: Container is running but health checks are still in progress
   - `unhealthy`: Container is running but failing health checks

The playbook is configured with `force_handlers: true` to ensure that state recovery is executed even when the playbook fails, which is essential for service restoration after backup failures:

```yaml
- name: Backup Forgejo Rootless services
  hosts: all
  gather_facts: true
  tags: [never, backup]
  force_handlers: true
  # Rest of the playbook...
```

This configuration guarantees that services will always be restored to their original state after backup operations, maintaining system consistency.

### Docker Compose Entrypoint Behavior

When using a custom entrypoint in docker-compose.yml that forwards arguments with `"$@"` like this:

```yaml
entrypoint:
  - /bin/sh
  - -c
  - |
    # Setup code...
    /usr/bin/dumb-init -- /usr/local/bin/docker-entrypoint.sh "$@"
```

There's a specific behavior with `docker compose run` that must be accounted for:

1. When using `docker compose run service_name command`, the **first word** of the command is ignored/skipped when passed to `"$@"`
2. To work around this, prefix your actual command with a dummy word:
   ```bash
   # INCORRECT - 'forgejo' will be ignored, only 'dump' passed to entrypoint
   docker compose run forgejo forgejo dump
   
   # CORRECT - 'dummy' will be ignored, 'forgejo dump' passed to entrypoint
   docker compose run forgejo dummy forgejo dump
   ```

This behavior only affects `docker compose run` commands and not other Docker Compose operations.

## Restore Process

To restore from a backup:

1. Stop the Forgejo service:
   ```bash
   cd /path/to/forgejo-rootless
   docker compose stop forgejo
   ```

2. Restore PostgreSQL database:
   ```bash
   docker compose exec forgejo-db pg_restore -Fc -c -U <db_user> -d <db_name> /path/to/forgejo-db-backup.dump
   ```

3. Restore Forgejo data (if needed):
   ```bash
   docker compose run --rm forgejo sh -c "forgejo restore -f /path/to/forgejo-app-dump.zip"
   ```

4. Restart services:
   ```bash
   docker compose up -d
   ```

## References

- [Gitea Backup and Restore Documentation](https://gitea.com/gitea/docs/src/branch/main/docs/administration/backup-and-restore.md)
- [Forgejo Upgrade and Backup Documentation](https://forgejo.org/docs/latest/admin/upgrade/#backup)
- [Gitea Ansible Role Backup](https://github.com/roles-ansible/ansible_role_gitea/blob/main/tasks/backup.yml)