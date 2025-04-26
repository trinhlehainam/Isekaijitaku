# Forgejo Backup System

This document describes the backup functionality for Forgejo and PostgreSQL databases in a Docker-based deployment. The system implements a hierarchical error handling approach with service state preservation that ensures data consistency, failure handling, and service state rollback.

## Prerequisites and Configuration

The backup system relies on several variables typically defined in Ansible inventory files (`host_vars` or `group_vars`). Ensure these are correctly set for your environment:

| Variable                 | Description                                                                                                   | Example Value (from dev host_vars)          |
| :----------------------- | :------------------------------------------------------------------------------------------------------------ | :------------------------------------------ |
| `forgejo_backup_dir`     | Host directory where backup files and the `rollback` directory are stored.                                    | `/home/vagrant/backup/docker/forgejo-rootless` |
| `forgejo_backup_filename`| Filename for the Forgejo application dump.                                                                    | `forgejo-app-dump.zip` (Default)           |
| `postgres_backup_filename`| Filename for the PostgreSQL database dump.                                                                    | `forgejo-db-backup.dump` (Default)         |
| `forgejo_db_user`        | Username for the PostgreSQL database connection (used by `pg_dump`). Must be defined somewhere.                 | *(Not defined in dev host_vars)*            |
| `forgejo_db_name`        | Name of the PostgreSQL database to back up (used by `pg_dump`). Must be defined somewhere.                    | *(Not defined in dev host_vars)*            |
| `db_password`            | Password for the `forgejo_db_user`. Must be defined, often vaulted.                                           | *(Vaulted)*                                 |
| `use_kopia`              | Boolean flag to enable/disable Kopia snapshot tasks for the backup directory.                                 | `true`                                      |
| `kopia_backup_data_dir`  | Base directory path within Kopia's configuration where data source paths are relative to.                      | `/data`                                     |
| `kopia_forgejo_backup_dir` | The full path Kopia uses to identify the Forgejo backup directory for snapshotting policies and actions.        | `/data/{{ forgejo_backup_dir }}`            |

Set these variables in your inventory files or pass them as extra vars when running the playbook.

## Running the Backup

The backup functionality is implemented as part of the `forgejo-rootless/roles/common` Ansible role and is invoked through the main `site.yml` playbook using tags.

**Example Command:**

```bash
ansible-playbook -i inventories/dev site.yml -t backup
```

Replace `inventories/dev` with your target inventory file or directory.

This command executes only the play within `site.yml` tagged with `backup`. This play specifically includes the `common` role and sets the `operation_mode` variable to `backup` internally, triggering the tasks defined in `roles/common/tasks/backup.yml`.

### Integration with Upgrade

The backup process is tightly integrated with the upgrade task:

*   **Upgrade (`upgrade.yml`):** When you run an upgrade using the `upgrade` tag (`ansible-playbook -i <inventory> site.yml -t upgrade`), the `backup.yml` task is automatically executed as the first step. This ensures a reliable backup is created before any changes are made to the application.

Other tasks like `restore`, `check`, and `deploy` are executed using their respective tags (`restore`, `check`, `deploy`) but do not directly include the `backup.yml` script during their operation. The `restore` task, however, relies on the existence of a backup created by `backup.yml`.

### Default Backup Location

If the `forgejo_backup_dir` variable is not explicitly set in your inventory, the `main.yml` task within the role will default to using `{{ ansible_user_dir }}/Backup/{{ project_name }}` on the target host (where `ansible_user_dir` is the home directory of the Ansible user and `project_name` is likely 'forgejo-rootless').

## Implementation Details

The backup process utilizes nested Ansible `block/rescue/always` structures to manage execution flow and handle errors at different levels. Failures within the Forgejo application backup or the PostgreSQL database backup are caught individually, allowing for component-specific error reporting. A higher-level block encompasses the entire backup sequence, catching broader failures. Before initiating the backup, the system captures the current state (running, stopped, health) of relevant Docker containers using `community.docker.docker_container_info`. This captured state is crucial for the post-backup restoration phase, ensuring services are returned precisely to their pre-backup condition.

Backups are written directly into the target `forgejo_backup_dir`. To prevent data loss from failed backups overwriting good ones, any existing content within `forgejo_backup_dir` is first moved into a temporary `rollback` subdirectory. If the new backup completes successfully, this `rollback` directory is removed. If the new backup fails, the contents of the `rollback` directory are moved back into `forgejo_backup_dir`, effectively restoring the previous backup state. Cleanup tasks, such as removing temporary containers or the `rollback` directory, are placed within `always` blocks to guarantee their execution regardless of whether the preceding tasks succeeded or failed.

The actual data extraction relies on native tooling: `forgejo dump` is executed within a temporary Forgejo container to create an application-consistent snapshot, and `pg_dump` is run from a temporary PostgreSQL container to produce a database dump. File transfer from these temporary containers to the host's backup directory is achieved through Docker volume mounts configured in the `docker-compose.backup.yml` file, rather than explicit copy commands in the Ansible tasks.

Ansible handlers, combined with the pre-captured service state, ensure reliable restoration of services to their original running condition after the backup process concludes, triggered reliably due to `force_handlers: true` in the playbook configuration. Variables defined in the Ansible inventory manage critical paths and settings consistently throughout the tasks.

## Backup File Structure

Backups are stored directly in the configured backup directory (`forgejo_backup_dir`, default: `backups` within the Forgejo project directory).

If a backup runs successfully when existing files are present, the previous files will be moved into a `rollback` subdirectory:

```
<forgejo_backup_dir>/
  ├── BACKUP_REPORT.md       # Detailed backup status report
  ├── forgejo-app-dump.zip   # Forgejo application data dump
  ├── forgejo-db-backup.dump # PostgreSQL database dump
  └── rollback/              # Previous backup state (if any)
      ├── BACKUP_REPORT.md
      ├── forgejo-app-dump.zip
      └── forgejo-db-backup.dump
```

If a backup fails, the `rollback` directory contents are restored, and the `rollback` directory is removed, leaving the previous state intact.

## Integration with Kopia

This backup process generates local backup files in the `forgejo_backup_dir`. It is recommended to use a tool like Kopia to snapshot this directory for offsite or versioned backups.

**Important Kopia Note:** Ensure that Kopia has a specific policy configured for the `forgejo_backup_dir` path. If no specific policy exists, Kopia might create a default snapshot policy that does not include compression, potentially leading to larger-than-expected snapshot sizes. Configure a policy with appropriate compression (e.g., `zstd`) for this directory.

## Restore Process

To restore from a backup:

1. Stop the Forgejo service:
   ```bash
   cd /path/to/forgejo-rootless
   docker compose stop forgejo
   ```

2. Replace the contents of the Forgejo data volume (`/var/lib/forgejo` or similar) with the contents of the `forgejo-app-dump.zip` from your desired backup.

3. Replace the contents of the PostgreSQL data volume (`/var/lib/postgresql/data` or similar) by restoring the `forgejo-db-backup.dump` file using `pg_restore`. This typically involves starting a temporary PostgreSQL container, copying the dump file into it, and executing `pg_restore`.

   Example `pg_restore` command (adjust paths and credentials):
   ```bash
   pg_restore -U <db_user> -d <db_name> -c --if-exists <dump_file>
   ```

4. Restore the `docker-compose.yml` and `secrets` directory from the backup to the project directory (`/path/to/forgejo-rootless`).

5. Restart the Forgejo service:
   ```bash
   docker compose up -d forgejo
   ```

*(Note: The restore process is manual and requires careful handling of Docker volumes and database restoration commands. This section provides a general outline; specific steps may vary based on your exact volume configuration and database setup.)*

## References

- [Gitea Backup and Restore Documentation](https://gitea.com/gitea/docs/src/branch/main/docs/administration/backup-and-restore.md)
- [Forgejo Upgrade and Backup Documentation](https://forgejo.org/docs/latest/admin/upgrade/#backup)
- [Gitea Ansible Role Backup](https://github.com/roles-ansible/ansible_role_gitea/blob/main/tasks/backup.yml)
- [Kopia Snapshot Create](https://kopia.io/docs/reference/command-line/common/snapshot-create/)