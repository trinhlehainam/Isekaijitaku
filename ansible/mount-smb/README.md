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
2.  **Ansible (`site.yml`, `inventories/`)**: Manages the configuration of the `ubuntu` VM:
    *   Installs `cifs-utils`.
    *   Creates a mount point directory (`/mnt/test` by default).
    *   Mounts the Windows SMB share (`//<windows_ip>/Test`) to the specified mount point.
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
    This command will create and provision both VMs. Vagrant automatically runs the Ansible playbook (`site.yml`) on the `ubuntu` VM after it's up.
5.  **Verify Mount**:
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