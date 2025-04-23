# Forgejo Backup System

This document describes the backup functionality for Forgejo and PostgreSQL databases in a Docker-based deployment. The system implements a hierarchical error handling approach with service state preservation that ensures data consistency, robust failure handling, and intelligent service state rollback.

## Backup Architecture

The backup process employs a sophisticated error handling structure with the following key features:

1.  **Hierarchical Error Handling**: Nested block/rescue structure captures and tracks failures.
2.  **Component Isolation**: Forgejo and PostgreSQL backups execute in their own blocks with independent error handling.
3.  **Smart Service State Preservation**: Captures container state before shutdown for precise recovery.
4.  **Container Health Detection**: Provides accurate health status detection (healthy, starting, unhealthy).
5.  **State-Aware Service Rollback**: Uses captured state to intelligently return services to their original running state via handlers.
6.  **Direct Backup with Rollback**: Backups are stored directly in `forgejo_backup_dir`. Existing content is moved to a `rollback` subdirectory before a new backup starts.
7.  **Automatic Restore on Failure**: If the backup fails, the previous state from the `rollback` directory is automatically restored.
8.  **Detailed Error Reporting**: Captures specific errors and includes them in the backup report.
9.  **Resource Cleanup Guarantees**: `always` sections ensure cleanup tasks execute.

## Backup Process Flow

The backup process follows these steps:

1.  Checks and captures detailed service state information.
2.  Stops Forgejo services, preserving their original state.
3.  Sets up backup variables and file paths.
4.  **Rollback Preparation**: Checks `forgejo_backup_dir` for existing content. If found, moves it into a `rollback` subdirectory.
5.  Launches dedicated containers for Forgejo and PostgreSQL backups.
6.  Runs the Forgejo dump command.
7.  Runs the PostgreSQL `pg_dump` command.
8.  Copies backup files (`forgejo-app-dump.zip`, `forgejo-db-backup.dump`) directly into `forgejo_backup_dir`.
9.  Verifies container existence before cleanup.
10. Cleans up temporary files and containers.
11. Creates a `BACKUP_REPORT.md` in `forgejo_backup_dir` with component status.
12. **On Success**: Notifies the service rollback handler.
13. **On Failure**: Cleans up partial backup files, restores content from the `rollback` directory, removes the `rollback` directory, and then notifies the service rollback handler.
14. Rolls back services to their original state via the handler.

## Running the Backup

The backup functionality is implemented as part of the `forgejo-rootless/roles/common` Ansible role and is invoked through the main `site.yml` playbook using tags.

**Example Command:**

```bash
ansible-playbook -i inventories/dev site.yml -t backup
```

Replace `inventories/dev` with your target inventory file or directory.

This command executes only the play within `site.yml` tagged with `backup`. This play specifically includes the `common` role and sets the `operation_mode` variable to `backup` internally, triggering the tasks defined in `roles/common/tasks/backup.yml`.

### Related Tasks

The backup process is tightly integrated with the upgrade task:

*   **Upgrade (`upgrade.yml`):** When you run an upgrade using the `upgrade` tag (`ansible-playbook -i <inventory> site.yml -t upgrade`), the `backup.yml` task is automatically executed as the first step. This ensures a reliable backup is created before any changes are made to the application.

Other tasks like `restore`, `check`, and `deploy` are executed using their respective tags (`restore`, `check`, `deploy`) but do not directly include the `backup.yml` script during their operation. The `restore` task, however, relies on the existence of a backup created by `backup.yml`.

### Default Backup Location

If the `forgejo_backup_dir` variable is not explicitly set in your inventory, the `main.yml` task within the role will default to using `{{ ansible_user_dir }}/Backup/{{ project_name }}` on the target host (where `ansible_user_dir` is the home directory of the Ansible user and `project_name` is likely 'forgejo-rootless').

## Running Backups

To run a backup with automatic service recovery afterward:

```bash
ansible-playbook site.yml -i inventories/production/hosts.yml -t backup
```

The system will intelligently roll back services to their original state after backup completion, regardless of success or failure. This ensures services are properly returned to their pre-backup state, maintaining the expected service availability through state-aware rollback handlers.

### Configuration Options

The backup system uses several variables typically defined in Ansible inventory files (`host_vars` or `group_vars`). Key variables include:

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

(Note: The backup of `docker-compose.yml` and `secrets` has been removed from this process.)

You can set these variables in your inventory files or pass them as extra vars when running the playbook.

### Backup File Structure

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

## Integration with Kopia

This backup process generates local backup files in the `forgejo_backup_dir`. It is recommended to use a tool like Kopia to snapshot this directory for offsite or versioned backups.

**Important Kopia Note:** Ensure that Kopia has a specific policy configured for the `forgejo_backup_dir` path. If no specific policy exists, Kopia might create a default snapshot policy that does not include compression, potentially leading to larger-than-expected snapshot sizes. Configure a policy with appropriate compression (e.g., `zstd`) for this directory.

### Service State Preservation and Rollback

The backup system includes a sophisticated service state preservation and recovery mechanism:

1.  **Service State Capture**: Before stopping services, the system captures detailed information about the running containers:
    - Container IDs and names
    - Service names from Docker Compose labels
    - Running state (running or stopped)
    - Health status (healthy, starting, unhealthy)
    - Other metadata such as uptime and image information

2.  **State-Aware Rollback Handler**: After backup completion, a specialized handler returns each service to its original state:

```yaml
- name: Rollback services
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

3.  **Health State Detection**: The system detects container health status using Docker's native health checks:
    - `healthy`: Container is running and passing health checks
    - `starting`: Container is running but health checks are still in progress
    - `unhealthy`: Container is running but failing health checks

The playbook is configured with `force_handlers: true` to ensure that state rollback is executed even when the playbook fails, which is essential for service restoration after backup failures:

```yaml
- name: Backup Forgejo Rootless services
  hosts: all
  gather_facts: true
  tags: [never, backup]
  force_handlers: true
  # Rest of the playbook...
```

This configuration guarantees that services will always be rolled back to their original state after backup operations, maintaining system consistency.

### Docker Compose Entrypoint Behavior

#### Understanding Command Handling in Docker Compose Run

When using Docker Compose with custom entrypoints that forward arguments, a critical behavior needs to be understood, especially with the Forgejo container's entrypoint configuration:

```yaml
# Example from docker-compose.yml
entrypoint:
  - /bin/sh
  - -c
  - |
    # Setup code and environment preparation
    /usr/bin/dumb-init -- /usr/local/bin/docker-entrypoint.sh "$@"
```

#### Argument Passing Quirk

Docker Compose has a specific behavior when using the `run` command that differs from how regular command execution works:

1.  **Command Truncation**: When executing `docker compose run service_name command args`, the **first word** of the command is systematically ignored/dropped when passed to the `"$@"` shell argument placeholder in the entrypoint

2.  **Resulting Behavior**: If your entrypoint uses `"$@"` to capture and pass arguments, you'll encounter unexpected command truncation

#### Example and Solution

Consider running the Forgejo dump command:

```bash
# CORRECT APPROACH - Add a dummy placeholder that will be intentionally dropped
# The entrypoint actually receives 'forgejo dump ...' as desired
docker compose run forgejo dummy forgejo dump -f /tmp/backup/forgejo-app-dump.zip
```

#### Implementation in Ansible

The backup system uses this technique when executing commands via `docker_container_exec` within the temporary backup containers launched by `docker_compose_v2_run`:

```yaml
- name: Run pg_dump command in the backup container
  community.docker.docker_container_exec:
    container: "{{ postgres_backup_container_id }}"
    # No dummy needed here as exec doesn't have the same quirk as run
    command: >
      pg_dump ... -f {{ postgres_container_backup_filepath }}
    environment:
      PGPASSWORD: "{{ forgejo_db_password }}"

- name: Run Forgejo dump command in the backup container
  community.docker.docker_container_exec:
    container: "{{ forgejo_backup_container_id }}"
    # No dummy needed here
    command: forgejo dump -f {{ forgejo_container_backup_filepath }}
```

*(Self-correction: The original doc incorrectly stated `docker_compose_v2` was used for the dump command itself; it's actually `docker_compose_v2_run` to start the container and `docker_container_exec` to run the dump command inside it. The 'dummy' argument quirk applies primarily to `docker compose run` directly from the shell or potentially `docker_compose_v2` with a `command` argument, not `docker_container_exec`)*

#### Scope of Impact

This behavior is specifically a concern with `docker compose run` operations. Other operations like `up`, `down`, `exec`, etc., and specifically `docker_container_exec` used here, don't exhibit this argument handling quirk.

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