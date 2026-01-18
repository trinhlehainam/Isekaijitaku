---
aliases:
  - "Vaultwarden Ansible Setup"
tags:
  - manifest
---

# Vaultwarden Ansible Setup

This playbook deploys Vaultwarden using Docker Compose.

## Configuration

Variables are managed through Ansible's standard structure:

*   **Inventories**: Define hosts (e.g., `dev`, `prod`).
*   **Host Variables** (`inventories/<env>/host_vars/<hostname>/main.yml`): Host-specific settings. Secrets may be stored here in plaintext (like the example `vaultwarden_admin_token: password` in `dev`) or using Ansible Vault.
*   **Group Variables** (`inventories/<env>/group_vars/vaultwarden/vault.yml`): Group-specific settings, typically encrypted using Ansible Vault for sensitive data like API keys or primary database passwords.

## Admin Token

To set or update the Vaultwarden admin token, you first need to generate an Argon2 hash of your desired password.

1.  Create a temporary file (e.g., `admin_pwd_temp`) with your password.
2.  Run the following command:
    ```bash
    cat admin_pwd_temp | xargs echo -n | argon2 "$(openssl rand -base64 32)" -e -id -k 19456 -t 2 -p 1
    ```
3.  Copy the resulting hash.
4.  Place the hash into the `vaultwarden_admin_token` variable in the appropriate variables file (e.g., `inventories/dev/host_vars/ubuntu/main.yml`). You can store it:
     *   **Directly as a plaintext string:** `vaultwarden_admin_token: "<paste_hash_here>"` (ensure correct YAML quoting if needed).
     *   **Encrypted using Ansible Vault:** First, encrypt the hash using `ansible-vault encrypt_string --stdin-name 'vaultwarden_admin_token'`, paste the hash when prompted, then copy the entire resulting `!vault` block into your variable file.
5.  Delete the temporary password file.

**Note:** For the `dev` environment (`inventories/dev/host_vars/ubuntu/main.yml`), the `vaultwarden_admin_token` is currently set to the **plaintext Argon2 hash** derived from the example password "password".

## Secrets Management

*   Sensitive data like the main database password (`vaultwarden_db_password`) should ideally be stored in an encrypted Ansible Vault file (e.g., `inventories/<env>/group_vars/vaultwarden/vault.yml`).
*   The playbook (`roles/common/tasks/deploy.yml`) creates necessary secret files (e.g., `db_password`, `admin_token`) in the deployment directory (`{{ service_project_src }}/secrets`).
*   The `smtp_password` secret is only created if the variable `use_vaultwarden_mailer` is defined and set to `true`.