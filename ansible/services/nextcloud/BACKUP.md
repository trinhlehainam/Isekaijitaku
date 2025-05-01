# Nextcloud Automated Backup Process

This document details the automated backup procedure for the Nextcloud service, managed via the Ansible role located in `roles/common`.

## Backup Strategy Overview

The primary goal is to create a consistent backup state by temporarily halting user activity, backing up essential configuration and data, and integrating with Kopia for offsite storage. The process utilizes Docker execution commands for maintenance mode and database dumps, alongside Ansible modules for file operations.

### Maintenance Mode Activation and Management

Before initiating file or database backups, the Ansible task `roles/common/tasks/backup.yml` places the Nextcloud instance into maintenance mode. This is achieved by executing `php occ maintenance:mode --on` within the `nextcloud` service container using `community.docker.docker_compose_v2_exec`. Concurrently, the persistent maintenance flag in `config.php` is reset via `php occ config:system:set maintenance --value=false --type=boolean`. This action prevents the instance from being permanently stuck in maintenance mode should the backup script encounter an error after enabling it. An `always` block within the main backup execution ensures that `php occ maintenance:mode --off` is executed upon completion or failure of the backup tasks, restoring user access.

### Configuration File Backup

The backup captures critical configuration artifacts necessary to restore the service structure. It copies the `docker-compose.yml` file defining the service stack, the contents of the `secrets` directory (if present), and the `opcache-recommended.ini` file. These files are placed directly within the specified `nextcloud_backup_dir`.

### PostgreSQL Database Dump

A PostgreSQL database dump is generated using `pg_dump`. The `community.docker.docker_compose_v2_exec` module runs the command `pg_dump -Fc -U {{ db_user }} {{ db_name }}` within the `nextcloud-db` container, writing the compressed-format dump file directly to the `nextcloud_backup_dir` with the filename specified by the `postgres_backup_filename` variable (defaulting to `nextcloud-db-backup.dump`).

### Kopia Snapshot Integration

Following the successful backup of configuration and the database dump to the local `nextcloud_backup_dir`, the `roles/common/tasks/kopia.yml` task list is included. This task is responsible for initiating a Kopia snapshot of the configured backup source directory (`{{ kopia_service_backup_dir }}`), ensuring the captured state is preserved according to Kopia's pre-defined policies and repository configuration.

### Rollback and Cleanup

To handle potential failures and ensure atomicity, existing contents of the `nextcloud_backup_dir` are moved to a temporary `rollback` subdirectory before the backup starts. If the overall backup process (config, database, and Kopia) fails, the original contents are moved back from the `rollback` directory, and any newly created backup artifacts (like the database dump) are removed. If the backup succeeds, the `rollback` directory is simply removed.

## Prerequisites

Before executing the backup playbook, ensure the following setup is complete:

*   **Kopia Snapshot Source Directory:** The directory specified by the `kopia_service_backup_dir` variable in your inventory **must exist on the host system**. This directory is the root path that Kopia will use as the source for creating snapshots. The Kopia service container requires appropriate access (typically via a volume mount) to this path. Failure to ensure this directory exists and is accessible will cause the Kopia snapshot task to fail.
*   **Kopia Snapshot Policies (Ignore, Retention, Compression):** It is essential to configure Kopia snapshot policies for the `kopia_service_backup_dir` path *before* running this backup playbook. This includes setting:
    *   An **ignore rule** for the `html` subdirectory (e.g., `kopia policy set /path/to/kopia_service_backup_dir --add-ignore html`). This prevents backing up the application code.
    *   Desired retention schedules (e.g., daily, weekly, monthly snapshots to keep).
    *   Compression settings.
    These policies **must be configured manually** directly via Kopia (UI or CLI) before the first backup. This Ansible role *does not* manage Kopia policies.

## Configuration Variables

The backup process relies on several variables defined in inventory files (e.g., `inventories/dev/host_vars/ubuntu/main.yml`):

*   `nextcloud_backup_dir`: Absolute path on the target host where local backup artifacts are stored before Kopia processing.
*   `service_project_src`: Path to the directory containing the `docker-compose.yml` file for the Nextcloud service.
*   `nextcloud_opcache_recommended_ini`: Full path to the PHP opcache configuration file to be backed up.
*   `db_user`: PostgreSQL username for Nextcloud.
*   `db_name`: PostgreSQL database name for Nextcloud.
*   `postgres_backup_filename`: Filename for the PostgreSQL dump file.

## Execution

To run the backup process, execute the main service playbook (`playbook.yml`) with the `backup` tag:

```bash
ansible-playbook playbook.yml -i inventories/dev --tags backup
```

## References
*   Ansible Role Task: `roles/common/tasks/backup.yml`
*   Nextcloud Backup Documentation: [https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/backup.html)
*   Nextcloud occ Commands: [https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html)
*   Nextcloud Backup: [https://help.nextcloud.com/t/101-backup-what-and-why-not-how/217496](https://help.nextcloud.com/t/101-backup-what-and-why-not-how/217496)