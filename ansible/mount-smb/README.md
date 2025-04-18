# Mount Windows SMB Share with Ansible and Vagrant

This project demonstrates how to use Vagrant and Ansible to automatically mount a Windows SMB share onto an Ubuntu virtual machine.

## Overview

1.  **Vagrant (`Vagrantfile`)**: Sets up two VMs:
    *   `windows`: A Windows Server 2019 VM.
    *   `ubuntu`: An Ubuntu 22.04 VM.
    The `Vagrantfile` includes a PowerShell provisioner for the `windows` VM to:
        *   Create a directory (`C:\Test`).
        *   Share the directory as `Test` via SMB with full access for the `vagrant` user.
        *   Configure Windows Firewall to allow SMB connections and ICMP (ping).
2.  **Ansible (`site.yml`, `inventories/`, `roles/common/`)**: Manages the configuration of the `ubuntu` VM:
    *   Installs `cifs-utils`.
    *   Uses a role named `common` to handle tasks.
    *   The role first checks if the SMB share is already mounted.
    *   Conditionally creates a mount point directory (`/mnt/test` by default) and mounts the Windows SMB share (`//<windows_ip>/Test`) if not already mounted, based on the `operation_mode` variable.
    *   Conditionally creates a test file (`ansible_test.txt`) in the mounted share to verify write access, based on the `operation_mode` variable.
    *   Uses Ansible Vault (`.vault_pass`) to store the SMB password securely.
    *   Creates a test file (`ansible_test.txt`) in the mounted share to verify write access.

## Setup and Usage

1.  **Prerequisites**:
    *   Vagrant installed.
    *   Ansible installed.
    *   A virtualization provider supported by Vagrant (e.g., VirtualBox, Hyper-V, VMware).
2.  **Create Vault Password File**:
    Create a file named `.vault_pass` in the project root and add your desired vault password to it.
    ```bash
    echo "your_secret_password" > .vault_pass
    ```
3.  **Encrypt SMB Password**:
    You need to encrypt the SMB password (which is `vagrant` for the user created by the PowerShell provisioner) using Ansible Vault.
    *   Run the following command, replacing `your_secret_password` with the password you put in `.vault_pass`:
        ```bash
        ansible-vault encrypt_string --vault-password-file .vault_pass 'vagrant' --name 'smb_password'
        ```
    *   Copy the entire output (starting with `smb_password: !vault |`) and replace the existing `smb_password` entry in `inventories/dev/group_vars/all/main.yml`.
4.  **Start VMs and Provision**:
    ```bash
    vagrant up
    ```
    This command will create and provision both VMs. Vagrant automatically runs the Ansible playbook (`site.yml`) on the `ubuntu` VM after it's up. **Note:** By default, the `vagrant provision` step runs Ansible without specific tags, which will *not* execute the mount or test tasks due to the way the playbook is structured (using `tags: [never, ...]`). See the 'Playbook Execution and Tags' section below for running specific operations.
5.  **Verify Mount (after running with `--tags mount` or `--tags test`)**:
    *   SSH into the Ubuntu VM:
        ```bash
        vagrant ssh ubuntu
        ```
    *   Check if the share is mounted and the test file exists:
        ```bash
        mount | grep /mnt/test
        ls -l /mnt/test
        ```

## Configuration Variables

Configuration is managed in `inventories/dev/group_vars/all/main.yml`:

*   `smb_host_ip`: IP address of the Windows VM (defined in `Vagrantfile`).
*   `smb_share_name`: Name of the SMB share created on Windows.
*   `smb_user`: Username for accessing the share.
*   `smb_password`: Encrypted password for the SMB user (use `ansible-vault encrypt_string`).
*   `smb_mount_point`: Path on the Ubuntu VM where the share will be mounted.
*   `smb_fstype`: Filesystem type (`cifs`).
*   `smb_mount_uid`: User ID to own files/directories on the mounted share.
*   `smb_mount_gid`: Group ID to own files/directories on the mounted share.

## Playbook Execution and Tags

The `site.yml` playbook includes the `common` role multiple times, controlling which tasks run via Ansible tags and an `operation_mode` variable passed to the role.

*   **Check Mount Status**: The check for an existing mount runs *before* mount or test operations when using the `mount` or `test` tags.
*   **Mount Operation (`--tags mount`)**: Runs the check tasks and then the tasks to create the mount point and mount the SMB share (if not already mounted).
    ```bash
    cd /path/to/mount-smb # Navigate to the project directory
    ansible-playbook -i inventories/dev/hosts.yml site.yml --vault-password-file .vault_pass --tags mount
    ```
*   **Test Operation (`--tags test`)**: Runs the check tasks and then the task to create a test file on the (presumably already mounted) share.
    ```bash
    cd /path/to/mount-smb # Navigate to the project directory
    ansible-playbook -i inventories/dev/hosts.yml site.yml --vault-password-file .vault_pass --tags test
    ```
*   **Unmount Operation (`--tags unmount`)**: Runs the check tasks and then the tasks to remove the test file and unmount the SMB share (if currently mounted).
    ```bash
    cd /path/to/mount-smb # Navigate to the project directory
    ansible-playbook -i inventories/dev/hosts.yml site.yml --vault-password-file .vault_pass --tags unmount
    ```
*   **Default Run (No Tags)**: Running `ansible-playbook` without tags (or via `vagrant provision`) will only gather facts, as the role inclusions in `site.yml` are tagged with `never` to prevent accidental execution outside the specific `mount`, `test`, or `unmount` tags.