---
aliases:
  - "Kopia Backup Server Ansible Deployment"
tags:
  - manifest
---

# Ansible Playbook for Kopia Deployment

This repository contains an Ansible playbook designed to deploy and manage a Kopia backup server instance using Docker and Docker Compose.

## Important Limitation: Single Repository Only

Kopia server does not currently support serving multiple repositories from a single server instance. Each Kopia server can only be connected to a single repository at a time. For more details and ongoing discussion, see the upstream issue: [kopia/kopia#2976](https://github.com/kopia/kopia/issues/2976).

## Project Structure

*   `site.yml`: The main playbook orchestrating the different operational modes.
*   `inventories/`: Contains inventory files for different environments (e.g., `dev`, `prod`).
    *   `dev/`: Development environment configuration.
    *   `prod/`: Production environment configuration.
*   `roles/`: Contains the Ansible roles.
    *   `common/`: The primary role handling Kopia deployment, checks, destruction, and upgrades.
    *   `geerlingguy.docker/`: A dependency role (must be installed separately) to ensure Docker is set up on the target host.
*   `group_vars/`: Directory for defining variables applicable to groups of hosts.
*   `host_vars/`: Directory for defining variables specific to individual hosts.
*   `ansible.cfg`: Ansible configuration file.
*   `Vagrantfile`: (Optional) For setting up a local development environment using Vagrant.

## Prerequisites

1.  **Ansible**: Ensure Ansible is installed on the control machine.
2.  **Docker**: Docker and Docker Compose (v2 plugin recommended) must be installed on the *target* host(s). The playbook uses the `geerlingguy.docker` role to attempt installation/configuration if needed.
3.  **Ansible Docker Collection**: Install the necessary Ansible collection: `ansible-galaxy collection install community.docker`.
4.  **geerlingguy.docker role**: Install the dependency role: `ansible-galaxy install geerlingguy.docker`.

## Configuration Variables

These variables need to be defined in your inventory files (e.g., `inventories/dev/group_vars/all/vars.yml` or `inventories/dev/host_vars/ubuntu.yml`).

**Required:**

*   `kopia_username`: Username for accessing the Kopia Web UI.
*   `kopia_password`: Password for the Kopia Web UI user.
*   `kopia_repo_password`: Password used to encrypt the Kopia repository data.
*   `kopia_repository_dir`: **Absolute path** on the target host where the Kopia repository data will be stored (e.g., `/mnt/backups/kopia_repo`). This directory will be created if it doesn't exist.
    > **Note:** The playbook attempts to create this directory during deployment (`deploy.yml`). If this step fails, verify that the *parent* directory does not have immutable attributes set (check with `lsattr`) and that the Ansible user has the necessary permissions, especially if this path is not a dedicated mount point.

**Optional:**

*   `service_project_src`: **Absolute path** on the target host where the `docker-compose.yml` and `secrets` directory will be created. Defaults to `{{ ansible_user_dir }}/Docker/kopia` (e.g., `/home/ubuntu/Docker/kopia`).
*   `kopia_image_tag`: The Kopia Docker image tag to use (e.g., `0.19.0`). Defaults are usually set within the role.
*   `kopia_config_dir`: Path for Kopia configuration volume. Defaults to `./config` relative to `service_project_src`.
*   `kopia_cache_dir`: Path for Kopia cache volume. Defaults to `./cache` relative to `service_project_src`.
*   `kopia_logs_dir`: Path for Kopia logs volume. Defaults to `./logs` relative to `service_project_src`.
*   `kopia_data_mount`: Path on the host to mount read-only inside the container (e.g., `/`). Defaults to `/`.
*   `use_traefik`: Set to `true` to configure Traefik labels for reverse proxying. Defaults to `false`.
*   `traefik_network_name`: Name of the Docker network Traefik uses. Defaults to `proxy`.
*   `service_name`: Base name for Traefik router rules. Defaults to `kopia`.
*   `traefik_router_public`: Set to `true` to create a public-facing Traefik rule.
*   `public_apex_domain`: Public domain suffix (e.g., `example.com`) for the public rule.
*   `traefik_router_private`: Set to `true` to create a private-facing Traefik rule.
*   `private_apex_domain`: Private domain suffix (e.g., `lan`) for the private rule.
*   `traefik_tls_resolver`: TLS resolver name for Traefik (e.g., `stepca`).

## Secret Management

The playbook handles required secrets (`kopia_username`, `kopia_password`, `kopia_repo_password`) by writing them into individual files within a `secrets/` subdirectory inside the `service_project_src` directory on the target host. These files are then used by the `docker-compose.yml` template to populate environment variables or Docker secrets for the Kopia container.

## Usage

Run the playbook using `ansible-playbook`. Use tags to specify the desired operation. Replace `inventories/dev` with your target inventory.

*   **Deploy Kopia:**
    ```bash
    ansible-playbook -i inventories/dev site.yml --tags deploy
    ```
    This creates the necessary configuration, secrets, `docker-compose.yml` (from the `roles/common/templates/docker-compose.yml.j2` template), and starts the Kopia service.

*   **Check Kopia Status:**
    ```bash
    ansible-playbook -i inventories/dev site.yml --tags check
    ```
    Verifies if the Kopia Docker service is running.

*   **Destroy Kopia:**
    ```bash
    ansible-playbook -i inventories/dev site.yml --tags destroy
    ```
    Stops and removes the Kopia Docker Compose service and potentially related volumes/networks (behavior depends on the `destroy.yml` tasks and Docker Compose configuration).

*   **Upgrade Kopia:**
    ```bash
    ansible-playbook -i inventories/dev site.yml --tags upgrade
    ```
    Pulls the latest image specified (or default) and restarts the service using Docker Compose (typically `docker compose up -d --force-recreate`).

## Generated Docker Compose (`docker-compose.yml.j2`)

The `deploy` task generates a `docker-compose.yml` file based on the `roles/common/templates/docker-compose.yml.j2` template and the provided variables. This template typically defines:

*   The Kopia service using the specified image (`kopia/kopia:<tag>`).
*   Volume mounts for configuration (`kopia_config_dir`), cache (`kopia_cache_dir`), logs (`kopia_logs_dir`), the repository (`kopia_repository_dir`), and the host data mount (`kopia_data_mount`).
*   Secret definitions mapping the files in `secrets/` to container secrets or environment variables.
*   FUSE capabilities (`SYS_ADMIN`) and device mapping (`/dev/fuse`) for snapshot browsing.
*   Network configuration (e.g., connecting to the Traefik network if `use_traefik` is true).
*   Traefik labels for reverse proxy setup if `use_traefik` is true.

## Operational Notes

### Snapshot Synchronization Delay (CLI vs. UI)

Snapshots created using the Kopia command-line interface (`kopia snapshot create ...` executed inside the container) may not immediately appear in the Web UI's snapshot list (`/snapshots`). A noticeable delay can occur.

To force the Web UI to refresh and display newly created CLI snapshots, navigate to the Snapshots page in the UI and click the synchronize (circular arrows/reload) icon.

### Executing CLI Commands Inside the Container

To run Kopia CLI commands directly, execute them inside the running container. First, identify the container name (usually derived from the project source directory name and service name, e.g., `kopia-kopia-1`). Then use `docker exec`:

```bash
docker exec -it <container_name> kopia <command> [options]
```

Alternatively, if you are in the `service_project_src` directory on the target host:

```bash
docker compose exec -it kopia kopia <command> [options]
```

Remember that paths on the host machine need to be referenced via their mount point inside the container (e.g., a host path `/home/user/data` might be `/data/home/user/data` inside the container if `/` is mounted to `/data`).

## References

*   [Kopia CLI Command Reference](https://kopia.io/docs/reference/command-line/common/)
*   [Kopia Docker Installation](https://kopia.io/docs/installation/#docker-images)
*   [Kopia Docker Compose](https://github.com/kopia/kopia/blob/master/tools/docker/docker-compose.yml)