# Ansible Project Structure and Role Sharing

This document details a recommended structure for managing multiple Ansible projects within a single repository, specifically addressing how to effectively share common roles across these projects.

[Ansible Role Documentation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#storing-and-finding-roles)

## Repository Structure

This section illustrates the directory layout designed to centralize shared roles while keeping individual projects organized.

To facilitate role sharing, we adopt the following directory structure:

```
ansible-repo/          # Repository root
├── roles/             # Centralized shared roles directory
│   ├── common/        # Example shared role
│   └── requirements.yml # External role dependencies (galaxy, git)
├── ansible.cfg        # Root configuration (used by Semaphore UI, defines shared roles_path)
├── project1/          # Individual Ansible project (e.g., forgejo-rootless)
└── project2/          # Another Ansible project
```

## Ansible Role Lookup Order

Understanding how Ansible locates roles is fundamental to making the shared structure work correctly. This section outlines the precise order Ansible uses to search for roles during playbook execution.

When executing an `ansible-playbook` command, Ansible searches for roles in a specific order based on the [official documentation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#storing-and-finding-roles):

1.  Roles within Ansible Collections.
2.  In a directory named `roles/` relative to the playbook file being executed.
3.  In directories specified by the `roles_path` setting in the effective `ansible.cfg` file. If not explicitly set, the default search path is `~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles`.
4.  In the directory where the playbook file itself is located.

## Configuration for Shared Roles

Proper configuration via `ansible.cfg` files is necessary to bridge the gap between the centralized roles directory and individual project execution contexts. This section explains the required settings for different scenarios.

When running a playbook from within a specific project directory (e.g., `ansible-repo/project1/`), like:

```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml -t deploy
```

Ansible, by default, **does not** automatically look in the central `ansible-repo/roles/` directory.

To ensure shared roles are found when running commands from the *repository root* (as might be done by CI/CD systems like Semaphore), the root `ansible.cfg` should include:

```ini
# Inside ansible-repo/ansible.cfg
[defaults]
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
# Other settings...
```

This tells Ansible to look in the `./roles` directory (relative to the root `ansible.cfg`) in addition to the system defaults. This approach is suitable for CI/CD environments like Semaphore, which typically execute commands from the repository root.

*Example command run from `ansible-repo/` (repository root):*
```bash
ansible-playbook -i project1/inventories/dev/hosts.yml project1/playbooks/site.yml -t deploy
# Note the full paths relative to the root
```

**Important for Local Development:** For running playbooks *locally from within a project subdirectory* (e.g., executing `ansible-playbook` while the current working directory is `ansible-repo/project1/`), that project requires its own specific `ansible.cfg`. This configuration must point back to the shared roles directory using a relative path, while also allowing for project-specific roles:

```ini
# Inside ansible-repo/project1/ansible.cfg
[defaults]
roles_path = ../roles:./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
# The `../roles` entry directs Ansible to the shared roles directory located one level above the project directory.
# The `./roles` entry allows the use of roles defined specifically within the project itself.
```

*Example command run from `ansible-repo/project1/` (project subdirectory):*
```bash
ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml -t deploy
# Paths are relative to the project directory
```

This dual configuration (`ansible.cfg` at the root and within each project) ensures roles are discoverable regardless of whether the playbook is executed from the repository root or a project subdirectory.

## Semaphore UI Role & Collection Dependency Lookup

It's important to note that Semaphore UI employs its own specific mechanism for discovering role and collection dependencies defined in `requirements.yml` files *before* executing a playbook. This dependency installation step is separate from Ansible's runtime role lookup described earlier.

Semaphore searches for dependency files in the following order (as implemented in [PR #2687](https://github.com/semaphoreui/semaphore/pull/2687)):

1.  `<playbook_dir>/collections/requirements.yml`
2.  `<playbook_dir>/roles/requirements.yml`
3.  `<repo_dir>/collections/requirements.yml`
4.  `<repo_dir>/roles/requirements.yml`

Where:
*   `<playbook_dir>` is the directory containing the playbook being executed.
*   `<repo_dir>` is the root directory of the repository.

This allows for defining dependencies both at the project level (within the playbook's directory structure) and globally at the repository level (in the root `roles/` or `collections/` directories). Once dependencies are installed by Semaphore using these files, the standard Ansible role lookup logic (using `ansible.cfg`) applies during playbook execution to find the actual roles.