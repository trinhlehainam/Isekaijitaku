# Forgejo Backup System

This document describes the backup functionality for Forgejo and PostgreSQL databases in a Docker-based deployment. The backup system implements a best practice approach that ensures data consistency and reliability while minimizing service disruption.

## Backup Approach

The backup process performs the following steps:

1. Discovers running containers and obtains their IDs for reliable operations
2. Stops the Forgejo container completely to avoid race conditions during backup
3. Backs up the PostgreSQL database using `pg_dump` with the custom format (-Fc)
4. Creates a Forgejo data dump using the official `forgejo dump` command
5. Copies the backup files from containers to the host system using container IDs
6. Creates a backup report with component status information
7. Restarts services (in standard mode) or leaves them stopped (in update mode)
8. Verifies service health after restart

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
      ├── forgejo_app_dump.zip  # Forgejo application data dump
      └── forgejo_db_backup.dump  # PostgreSQL database dump
```

## Backup Technology

The backup system uses the following technologies to ensure reliable backups:

- **Docker Compose V2**: For container control, service discovery, and executing commands
- **Forgejo dump**: Official Forgejo backup command that creates a consistent snapshot
- **pg_dump**: PostgreSQL utility to create a consistent database backup in custom format
- **docker cp**: For copying backup files from containers to the host system
- **Container discovery**: Dynamic container identification using service names

## Restore Process

To restore from a backup:

1. Stop the Forgejo service:
   ```bash
   cd /path/to/forgejo-rootless
   docker compose stop forgejo
   ```

2. Restore PostgreSQL database:
   ```bash
   docker compose exec forgejo-db pg_restore -Fc -c -U <db_user> -d <db_name> /path/to/forgejo_db_backup.dump
   ```

3. Restore Forgejo data (if needed):
   ```bash
   docker compose run --rm forgejo sh -c "forgejo restore -f /path/to/forgejo_dump.zip"
   ```

4. Restart services:
   ```bash
   docker compose up -d
   ```

## References

- [Gitea Backup and Restore Documentation](https://gitea.com/gitea/docs/src/branch/main/docs/administration/backup-and-restore.md)
- [Forgejo Upgrade and Backup Documentation](https://forgejo.org/docs/latest/admin/upgrade/#backup)
- [Gitea Ansible Role Backup](https://github.com/roles-ansible/ansible_role_gitea/blob/main/tasks/backup.yml)