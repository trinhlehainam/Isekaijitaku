# Forgejo Backup System

This document describes the backup functionality for Forgejo and PostgreSQL databases in a Docker-based deployment. The backup system implements a best practice approach that ensures data consistency and reliability while minimizing service disruption.

## Backup Approach

The backup process performs the following steps:

1. Stops all Forgejo services to ensure data consistency
2. Launches a dedicated Forgejo backup container that remains active only during the backup process
3. Runs the Forgejo dump command in the backup container, storing the backup in the container's volume-mounted directory
4. Backs up the PostgreSQL database using `pg_dump` with the custom format (-Fc)
5. Copies the backup files from containers to the host system using direct Docker copy commands
6. Cleans up the temporary backup container after copying backup files
7. Creates a backup report with component status information
8. Restarts services (in standard mode) or leaves them stopped (in update mode)
9. Verifies service health after restart

## Running Backups

### Standard Mode

To run a backup with automatic service restart afterward:

```bash
ansible-playbook site.yml -i inventories/production/hosts.yml -t backup
```

### Update Mode

To run a backup and keep services stopped (useful for maintenance or updates):

```bash
ansible-playbook site.yml -i inventories/production/hosts.yml -t backup -e "update_mode=true"
```

### Configuration Options

The backup system supports the following configuration options:

| Variable | Description | Default |
|----------|-------------|---------|
| `forgejo_backup_dir` | Directory where backups are stored | `<forgejo_project_src>/backups` |
| `update_mode` | If true, services remain stopped after backup | `false` |

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

The backup system uses the following technologies to ensure reliable backups:

- **Docker Compose V2**: For stopping services and launching backup containers
- **Docker Container Exec**: For executing backup commands in running containers
- **Forgejo dump**: Official Forgejo backup command that creates a consistent snapshot
- **pg_dump**: PostgreSQL utility to create a consistent database backup in custom format
- **docker cp**: For copying backup files from containers to the host system
- **Container lifecycle management**: Uses dedicated backup containers with controlled lifecycles to prevent memory issues

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