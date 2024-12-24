# Migrating from Standard to Rootless Image

This guide explains how to migrate from the standard Forgejo Docker image to the rootless image.

There are two approaches to migration:
1. Keep using the standard `/data` structure (compatibility approach)
2. Convert to rootless folder structure (recommended approach)

## Directory Structure

### Standard Image (Current)
- Work Directory: `/data/gitea`
- App Config: `/data/gitea/conf/app.ini`
- Repositories: `/data/git/repositories`
- LFS Storage: `/data/git/lfs`
- Temporary Files: `/data/gitea/tmp`

### Rootless Image (Internal Paths)
- Base Directory: `/var/lib/gitea`
  - Custom Config: `/var/lib/gitea/custom/conf/app.ini`
  - Data Directory: `/var/lib/gitea/data/`
    - Attachments: `/var/lib/gitea/data/attachments`
    - Avatars: `/var/lib/gitea/data/avatars`
    - Repo Avatars: `/var/lib/gitea/data/repo-avatars`
    - Sessions: `/var/lib/gitea/data/sessions`
    - Log Files: `/var/lib/gitea/data/log`
    - SQLite DB: `/var/lib/gitea/data/gitea.db` (if using SQLite)
  - Git Data: `/var/lib/gitea/git`
    - Repositories: `/var/lib/gitea/git/repositories`
    - LFS Objects: `/var/lib/gitea/git/lfs`
  - Temporary Files: `/tmp/gitea`

## Migration Steps

### Option 1: Keep Standard Structure (Compatibility)

This approach maintains the standard `/data` directory structure:

1. Back up your data:
   ```bash
   # Preserve file ownership and permissions during backup
   sudo cp -a ./data data_backup
   ```

2. Update docker-compose.yaml:
   ```yaml
   services:
     forgejo:
       image: codeberg.org/forgejo/forgejo:9.0.3-rootless
       environment:
         - GITEA_APP_INI=/data/gitea/conf/app.ini
         - GITEA_TEMP=/data/gitea/tmp
         - GITEA_CUSTOM=/data/gitea
       volumes:
         - ./data:/data
   ```

### Option 2: Convert to Rootless Structure (Recommended)

This approach converts your setup to use the rootless directory structure:

1. Verify target directory structure:
   ```bash
   # Create test directories
   mkdir -p test/data test/conf

   # Copy your app.ini to test environment
   cp ./data/gitea/conf/app.ini ./test/conf/app.ini

   # Start test container
   docker compose -f docker-compose.test.yaml up -d

   # Check data directory structure
   docker exec forgejo-test ls -la /var/lib/gitea/data
   # Expected output:
   # attachments/
   # avatars/
   # repo-avatars/
   # sessions/
   # log/
   # gitea.db (if using SQLite)

   # Check git repositories location
   docker exec forgejo-test ls -la /var/lib/gitea/git
   # Expected: repositories/ and lfs/

   # Check configuration location
   docker exec forgejo-test ls -la /var/lib/gitea/custom/conf
   # Expected: app.ini

   # Check temporary directory
   docker exec forgejo-test ls -la /tmp/gitea
   # Expected: empty or temporary files

   # Once verified, clean up test environment
   docker compose -f docker-compose.test.yaml down
   rm -rf test
   ```

2. Create new directory structure:
   ```bash
   # Backup your data first
   sudo cp -a ./data data_backup

   # Create temporary directory for conversion
   sudo mkdir -p ./data-new/data
   sudo mkdir -p ./conf
   
   # Set ownership and permissions
   sudo chown -R 1000:1000 ./data-new
   sudo chown -R 1000:1000 ./conf
   
   # Copy data with preserved ownership and permissions
   sudo cp -a ./data/gitea/conf/app.ini ./conf/app.ini

   # Copy user data preserving ownership and permissions (-a flag)
   sudo cp -a ./data/gitea/attachments ./data-new/data/attachments
   sudo cp -a ./data/gitea/avatars ./data-new/data/avatars
   sudo cp -a ./data/gitea/repo-avatars ./data-new/data/repo-avatars
   sudo cp -a ./data/gitea/sessions ./data-new/data/sessions
   sudo cp -a ./data/gitea/log ./data-new/data/log
   [[ -f ./data/gitea/gitea.db ]] && sudo cp -a ./data/gitea/gitea.db ./data-new/data/

   # Fix log directory ownership (might be owned by root in standard image)
   sudo chown -R 1000:1000 ./data-new/data/log

   # Copy git repositories and LFS objects
   sudo mkdir -p ./data-new/git
   sudo chown -R 1000:1000 ./data-new/git
   sudo cp -a ./data/git/repositories ./data-new/git/repositories
   sudo cp -a ./data/git/lfs ./data-new/git/lfs
   
   # Backup old data and move new structure in place
   sudo mv ./data ./data-old
   sudo mv ./data-new ./data
   
   ```

3. Update paths in app.ini:
   Using vim to replace paths:
   ```bash
   # Open app.ini with vim
   vi ./conf/app.ini

   # In vim command mode, run these commands:
   # Replace /data/gitea with /var/lib/gitea
   :%s/\/data\/gitea/\/var\/lib\/gitea/g
   # Replace /data/git with /var/lib/gitea/git
   :%s/\/data\/git/\/var\/lib\/gitea\/git/g
   # Replace /data/gitea/tmp/local-repo with /tmp/gitea/local-repo
   :%s/\/data\/gitea\/tmp\/local-repo/\/tmp\/gitea\/local-repo/g
   # Replace /data/gitea/uploads with /tmp/gitea/uploads
   :%s/\/data\/gitea\/uploads/\/tmp\/gitea\/uploads/g
   ```

   Here are all the paths that will be updated:

   ```ini
   WORK_PATH = /var/lib/gitea                        # was: /data/gitea

   [repository]
   ROOT = /var/lib/gitea/git/repositories                    # was: /data/git/repositories

   [repository.local]
   LOCAL_COPY_PATH = /tmp/gitea/local-repo                  # was: /data/gitea/tmp/local-repo

   [repository.upload]
   TEMP_PATH = /tmp/gitea/uploads                  # was: /data/gitea/uploads

   [server]
   APP_DATA_PATH = /var/lib/gitea                      # was: /data/gitea
   ; In rootless gitea container only internal ssh server is supported
   START_SSH_SERVER = true
   SSH_PORT = 2222
   SSH_LISTEN_PORT = 2222
   BUILTIN_SSH_SERVER_USER = git

   [database]
   PATH = /var/lib/gitea/data/gitea.db                      # was: /data/gitea/gitea.db

   [indexer]
   ISSUE_INDEXER_PATH = /var/lib/gitea/indexers/issues.bleve  # was: /data/gitea/indexers/issues.bleve

   [session]
   PROVIDER_CONFIG = /var/lib/gitea/data/sessions           # was: /data/gitea/sessions

   [picture]
   AVATAR_UPLOAD_PATH = /var/lib/gitea/data/avatars         # was: /data/gitea/avatars
   REPOSITORY_AVATAR_UPLOAD_PATH = /var/lib/gitea/data/repo-avatars  # was: /data/gitea/repo-avatars

   [attachment]
   PATH = /var/lib/gitea/data/attachments                   # was: /data/gitea/attachments

   [log]
   ROOT_PATH = /var/lib/gitea/data/log                      # was: /data/gitea/log

   [lfs]
   PATH = /var/lib/gitea/git/lfs                       # was: /data/git/lfs

   [openid]
   ENABLE_OPENID_SIGNIN = false
   ENABLE_OPENID_SIGNUP = false
   ```

   General rules for path conversion:
   - `/data/gitea` → `/var/lib/gitea`
   - `/data/git/*` → `/var/lib/gitea/git/*`
   - Temporary paths → `/tmp/gitea/*`

4. Update docker-compose.yaml:
   ```yaml
   services:
     forgejo:
       image: codeberg.org/forgejo/forgejo:9.0.3-rootless
       volumes:
         - ./data:/var/lib/gitea
         - ./conf:/var/lib/gitea/custom/conf
   ```

5. Set correct permissions:
   ```bash
   # Ensure all files are owned by UID 1000
   sudo chown -R 1000:1000 ./data ./conf
   ```

6. Start the service:
   ```bash
   docker compose up -d
   ```

## Important Notes

- The rootless image runs with a fixed user ID (1000) inside the container
- Option 1 (Compatibility) uses environment variables to maintain the standard structure
- Option 2 (Recommended) uses the native rootless paths for better maintainability
- SSH server needs to be explicitly enabled with `START_SSH_SERVER = true` in app.ini
- The app.ini file should be placed in `/var/lib/gitea/custom/conf/app.ini`
- All user data (attachments, avatars, etc.) is stored under `/var/lib/gitea/data/`
- Git repositories and LFS objects are stored under `/var/lib/gitea/git/`
- Temporary files are stored in `/tmp/gitea/`
- The log directory from standard image might be owned by root, make sure to change ownership to 1000:1000
- OpenID signin and signup are disabled by default for security. If needed, they can be enabled in app.ini:
  ```ini
  [openid]
  ENABLE_OPENID_SIGNIN = false  # Set to true to enable OpenID signin
  ENABLE_OPENID_SIGNUP = false  # Set to true to enable OpenID signup
  ```
- Always use `cp -a` when copying files to preserve ownership and permissions:
  ```bash
  # The -a flag preserves:
  # - ownership (user and group IDs)
  # - permissions (read/write/execute)
  # - timestamps
  # - symbolic links
  sudo cp -a source_file destination_file
  ```

### Known Issues

#### Config Path Changes

Starting with Forgejo version 9.x rootless image, the default config path has changed from `/etc/gitea/app.ini` to `/var/lib/gitea/custom/conf/app.ini`. You have two options to handle this:

1. Move to New Default Path (Recommended):
   ```bash
   # First, backup your data
   docker exec -it forgejo gitea dump --config /etc/gitea/app.ini
   
   # Stop the container
   docker compose down
   
   # Move your config file to the new location
   sudo mkdir -p ./conf
   sudo mv ./data/gitea/conf/app.ini ./conf/
   sudo chown -R 1000:1000 ./conf
   
   # Update docker-compose.yaml to use new paths
   # - Remove GITEA_APP_INI environment variable
   # - Update volume mounts to use /var/lib/gitea paths
   
   # Start container with new config
   docker compose up -d
   
   # Restore if needed
   docker exec -it forgejo gitea restore --config /var/lib/gitea/custom/conf/app.ini --file /path/to/backup.zip
   ```

2. Keep Legacy Path:
   Add this environment variable to your docker-compose.yaml:
   ```yaml
   environment:
     - GITEA_APP_INI=/etc/gitea/app.ini
   ```

   Note: Using the legacy path will show a warning:
   ```
   WARNING: detected configuration file in deprecated default path /etc/gitea/app.ini.
   The new default is /var/lib/gitea/custom/conf/app.ini. To remove this warning, choose one of the options:
   * Move /etc/gitea/app.ini to /var/lib/gitea/custom/conf/app.ini
   * Explicitly override GITEA_APP_INI=/etc/gitea/app.ini in the container environment
   ```

#### Backup and Restore

When performing backup or restore operations, always specify the correct config path:

1. For new default path:
   ```bash
   docker exec -it forgejo gitea dump --config /var/lib/gitea/custom/conf/app.ini
   docker exec -it forgejo gitea restore --config /var/lib/gitea/custom/conf/app.ini --file /path/to/backup.zip
   ```

2. For legacy path:
   ```bash
   docker exec -it forgejo gitea dump --config /etc/gitea/app.ini
   docker exec -it forgejo gitea restore --config /etc/gitea/app.ini --file /path/to/backup.zip
   ```

For more information, see:
- [Gitea Issue #31190](https://github.com/go-gitea/gitea/issues/31190)
- [Gitea Backup and Restore Documentation](https://docs.gitea.com/1.21/administration/backup-and-restore#backup-command-dump)

## Troubleshooting

If you encounter issues:
1. Check the container logs: `docker compose logs forgejo`
2. Verify file permissions are set to UID 1000
3. For Option 2, ensure all paths in app.ini are correctly updated to use `/var/lib/gitea/...`
4. Verify app.ini is in the correct location: `/var/lib/gitea/custom/conf/app.ini`
5. Check ownership and permissions of copied/moved files
6. Verify the directory structure matches the rootless layout

## References

- [Gitea Rootless Migration Guide](https://docs.gitea.com/installation/install-with-docker-rootless#upgrading-from-standard-image)
- [Gitea Issue Discussion](https://github.com/go-gitea/gitea/issues/21647#issuecomment-1298327402)
