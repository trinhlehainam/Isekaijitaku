# Deploy Keys in Forgejo/Gitea Actions

This guide explains how to set up and use deploy keys in Forgejo/Gitea Actions for secure repository access during CI/CD workflows.

## What are Deploy Keys?

Deploy keys are SSH keys that grant read-only or read-write access to a single repository. They are more secure than using personal SSH keys because:
- They have limited scope (single repository)
- They can be easily revoked without affecting other access
- They can be managed separately from user accounts

## Setting Up Deploy Keys

### 1. Generate SSH Key Pair

```bash
# Generate a new SSH key pair (without passphrase)
ssh-keygen -t ed25519 -C "deploy-key-for-repo@forgejo" -f deploy_key -N ""

# Or with passphrase (recommended for production)
ssh-keygen -t ed25519 -C "deploy-key-for-repo@forgejo" -f deploy_key
```

This creates two files:
- `deploy_key` (private key)
- `deploy_key.pub` (public key)

### 2. Add Public Key to Target Repository

1. Go to your target repository's settings in Forgejo/Gitea
2. Navigate to "Deploy Keys" section
3. Click "Add Deploy Key"
4. Give it a meaningful title
5. Paste the contents of `deploy_key.pub`
6. Check "Allow Write Access" if needed
7. Click "Add Key"

### 3. Add Private Key as Repository Secret

1. Go to your source repository's settings
2. Navigate to "Secrets" section
3. Add a new secret named `SSH_PRIVATE_KEY`
4. Paste the contents of the `deploy_key` file
5. If your key has a passphrase, add it as `SSH_KEY_PASSPHRASE`
6. Save the secret(s)

## Testing SSH Connection

When testing your SSH connection with `ssh -T git@domain`, you might see a message like:

```
Hi USERNAME! You've successfully authenticated with the deploy key named KEY_NAME but Gitea/Forgejo does not provide shell access.
```

This is the **expected behavior** and indicates that:
1. Your SSH key is valid and recognized
2. Authentication was successful
3. The server correctly denies shell access (this is a security feature)

The command will exit with code 1, which is normal. You can safely proceed with using Git operations.

Common test responses:
- Gitea/Forgejo: "successfully authenticated with the deploy key... but does not provide shell access"
- GitHub: "successfully authenticated, but GitHub does not provide shell access"

## Runner Environment Considerations

### Docker-based Runners (GitHub-hosted or containerized self-hosted)

For runners that execute in containers, you should handle home directory variations:
- Some runners may not have `$HOME` or `~` properly set
- Use explicit home directory path via `RUNNER_HOME` environment variable
- Ensure all SSH-related actions use the same home directory

Example home directory setup:
```yaml
env:
  RUNNER_HOME: ${{ github.workspace }}/.runner-home

steps:
  - name: Setup Home Directory
    run: |
      # Ensure we have a home directory
      RUNNER_HOME="${RUNNER_HOME:-${HOME:-${{ github.workspace }}/.runner-home}}"
      echo "RUNNER_HOME=$RUNNER_HOME" >> $GITHUB_ENV
      mkdir -p "$RUNNER_HOME"
      
      # Export for child processes
      export HOME="$RUNNER_HOME"
      echo "HOME=$RUNNER_HOME" >> $GITHUB_ENV
```

### Host Runners (Non-containerized self-hosted)

For runners that execute directly on a host machine:
1. **DO NOT** modify the host's SSH configuration in workflows
2. Instead, configure the host machine's SSH setup once as an administrator:
   ```bash
   # As admin/root on the runner host machine

   GIT_SERVER_DOMAIN=forgejo.yourdomain
   GIT_SERVER_SSH_PORT=2222
   RUNNER_HOME=/home/runner

   mkdir -p $RUNNER_HOME/.ssh
   chmod 700 $RUNNER_HOME/.ssh
   
   # Create global SSH config
   cat > $RUNNER_HOME/.ssh/config << EOF
   Host $GIT_SERVER_DOMAIN
     Port $GIT_SERVER_SSH_PORT
     StrictHostKeyChecking yes
   EOF
   chmod 600 $RUNNER_HOME/.ssh/config
   
   # Add known hosts
   ssh-keyscan -t rsa,ed25519 -p $GIT_SERVER_SSH_PORT $GIT_SERVER_DOMAIN >> $RUNNER_HOME/.ssh/known_hosts
   chmod 644 $RUNNER_HOME/.ssh/known_hosts
   
   # Set ownership
   chown -R runner:runner $RUNNER_HOME/.ssh
   ```

3. Use simpler workflow configurations that rely on the host's SSH setup:

```yaml
name: Checkout with Host Runner
jobs:
  checkout:
    runs-on: self-hosted
    steps:
      - name: Clone Repository
        uses: https://github.com/actions/checkout@v4
        with:
          repository: owner/repo
          ssh-key: ${{ secrets.DEPLOY_KEY }}
          github-server-url: "https://forgejo.yourdomain"
```

## SSH Agent Management

There are two approaches to manage SSH agent in GitHub Actions:

1. **Using webfactory/ssh-agent (Recommended)**
   ```yaml
   - name: Setup SSH Agent 
     uses: webfactory/ssh-agent@v0.9.0
     with:
       ssh-private-key: ${{ secrets.DEPLOY_KEY }}
   ```
   - Automatically handles environment variables
   - Works across all steps in the job
   - Cleans up automatically in post-job phase

2. **Manual SSH Agent Setup**
   ```yaml
   env:
     SSH_AUTH_SOCK: /tmp/ssh-agent.sock  # Set consistent socket path
   
   steps:
     - name: Start ssh-agent
       run: |
         eval "$(ssh-agent -s)"
         # Export variables for other steps
         echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $GITHUB_ENV
         echo "SSH_AGENT_PID=$SSH_AGENT_PID" >> $GITHUB_ENV
   ```
   - Requires manual environment variable export
   - Must use `$GITHUB_ENV` to persist variables
   - Need explicit cleanup in post-job phase

### Important Environment Variables

1. **SSH_AUTH_SOCK**
   - Socket path for SSH agent communication
   - Must be consistent across steps
   - Used by git, rsync, and other SSH tools

2. **SSH_AGENT_PID**
   - Process ID of the SSH agent
   - Used for cleanup
   - Needed to terminate agent properly

### References
- [shimataro/ssh-key-action](https://github.com/shimataro/ssh-key-action?tab=readme-ov-file#i-want-to-omit-known_hosts) - SSH key installation
- [webfactory/ssh-agent](https://github.com/webfactory/ssh-agent?tab=readme-ov-file#exported-variables) - SSH agent management

## Using Deploy Keys in Workflows

The following examples are for **containerized environments**. For host runners, see the section above.

### 1. Using SSH Agent (For Keys Without Passphrase)

This approach uses `shimataro/ssh-key-action` to handle SSH keys without passphrases:

```yaml
name: Checkout with SSH Agent
jobs:
  checkout:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      GIT_SERVER_SSH_PORT: 2222
      SSH_KEY_NAME: deploy-key
    steps:
      - name: Install SSH Key
        uses: https://github.com/shimataro/ssh-key-action@v2
        with:
          key: ${{ secrets.DEPLOY_KEY }}
          name: ${{ env.SSH_KEY_NAME }}
          # https://github.com/shimataro/ssh-key-action?tab=readme-ov-file#i-want-to-omit-known_hosts
          known_hosts: unnecessary
          if_key_exists: fail # replace / ignore / fail
          config: |
            Host ${{ env.GIT_SERVER_DOMAIN }}
              Port ${{ env.GIT_SERVER_SSH_PORT }}
              StrictHostKeyChecking yes
      
      - name: Add SSH Known Hosts
        run: |
          ssh-keyscan -p ${{ env.GIT_SERVER_SSH_PORT }} -H ${{ env.GIT_SERVER_DOMAIN }} >> "${HOME}/.ssh/known_hosts"
```

### 2. Using Expect (For Keys With Passphrase)

This approach uses `shimataro/ssh-key-action` for key installation and manual SSH agent setup with `expect`:

```yaml
name: Checkout with Passphrase
jobs:
  checkout:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      GIT_SERVER_SSH_PORT: 2222
      SSH_KEY_NAME: deploy-key
      SSH_AUTH_SOCK: /tmp/ssh-agent.sock  # Consistent socket path
    steps:
      - name: Install SSH Key
        uses: https://github.com/shimataro/ssh-key-action@v2
        with:
          key: ${{ secrets.DEPLOY_KEY }}
          name: ${{ env.SSH_KEY_NAME }}
          known_hosts: unnecessary  # We'll add known_hosts manually
          if_key_exists: fail
          config: |
            Host ${{ env.GIT_SERVER_DOMAIN }}
              Port ${{ env.GIT_SERVER_SSH_PORT }}
              StrictHostKeyChecking yes
      
      - name: Add SSH Known Hosts
        run: |
          ssh-keyscan -p ${{ env.GIT_SERVER_SSH_PORT }} -H ${{ env.GIT_SERVER_DOMAIN }} >> "${HOME}/.ssh/known_hosts"

      - name: Start ssh-agent
        run: |
          eval "$(ssh-agent -s)"
          # Export variables for other steps
          echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $GITHUB_ENV
          echo "SSH_AGENT_PID=$SSH_AGENT_PID" >> $GITHUB_ENV
```

## Important Notes

1. **SSH Key Installation**
   - Use `shimataro/ssh-key-action` for key installation
   - Set `if_key_exists` to control behavior when key exists
   - Manually add known hosts for custom SSH ports
   - Keep SSH configuration consistent across steps

2. **Known Hosts Handling**
   - `ssh-key-action` doesn't support custom ports for known_hosts
   - Use manual `ssh-keyscan` with `-p` flag for custom ports
   - Use `-H` flag to hash hostnames in known_hosts
   - Add known hosts after key installation

3. **SSH Configuration**
   - Set explicit key name via `SSH_KEY_NAME` environment variable
   - Use `StrictHostKeyChecking yes` for security
   - Configure custom ports in SSH config
   - Verify host keys before first connection

## Best Practices

1. **SSH Key Management**
   - Use descriptive key names (e.g., `deploy-key`)
   - Set appropriate `if_key_exists` behavior
   - Handle key conflicts explicitly
   - Clean up keys after use

2. **Known Hosts Security**
   - Always verify host keys with `-H` flag
   - Use `StrictHostKeyChecking yes`
   - Add known hosts before any SSH operations
   - Keep known_hosts file permissions at 644

3. **Custom Port Configuration**
   - Set port in SSH config for reuse
   - Use `-p` flag with ssh-keyscan
   - Verify custom port connectivity
   - Document non-standard ports

4. **SSH Agent Management**
   - Use `webfactory/ssh-agent` when possible
   - Set consistent socket paths
   - Export environment variables properly
   - Handle cleanup in post-job phase
   - Use `$GITHUB_ENV` for variable persistence

## Environment Variables in Expect Scripts

When using expect scripts in GitHub Actions, you need to understand the difference between shell and expect environment variable syntax:

1. **Shell Environment Variables**
   ```bash
   # In shell scripts, use standard shell syntax
   echo "$HOME/.ssh/id_rsa"      # Correct
   SSH_DIR="$HOME/.ssh"          # Correct
   ```

2. **Expect Environment Variables**
Example workflow using both:
```yaml
- name: Add Passphrase to ssh-agent
  env:
    SSH_KEY_PASSPHRASE: ${{ secrets.SSH_KEY_PASSPHRASE }}
  run: |
    # Shell script: use $HOME
    SSH_DIR="$HOME/.ssh"
    echo "Using SSH directory: $SSH_DIR"
    
    # Expect script: use $env(HOME)
    cat > /tmp/add-key.exp << 'EOF'
    #!/usr/bin/expect -f
    set timeout 10
    # Use $env() to access environment variables in expect
    spawn ssh-add "$env(HOME)/.ssh/$env(SSH_KEY_NAME)"
    expect "Enter passphrase"
    send "$env(SSH_KEY_PASSPHRASE)\r"
    expect eof
    EOF
    
    # Shell script again: use $HOME
    chmod 700 /tmp/add-key.exp
    /tmp/add-key.exp
```

### Important Notes:
- Shell scripts use standard shell variable syntax (`$VAR` or `${VAR}`)
- Expect scripts must use `$env(VAR)` to access environment variables
- GitHub Actions variables (`${{ env.VAR }}`) only work in workflow YAML
- Environment variables must be explicitly passed to expect scripts

## Troubleshooting

1. **SSH Authentication**
   - Message "successfully authenticated... but does not provide shell access" is expected. [Learn More](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)
   - Command exits with code 1, which is normal
   - Use `ssh -T` for testing, or `ssh -vT` for verbose output, avoid using -v in production that can leak secrets
   - Only Git operations (clone, push, pull) are allowed

2. **Permission Denied**
   - Verify key permissions (600 for private key)
   - Check if key is added to repository
   - Verify SSH config file permissions
   - Test SSH connection with verbose logging

3. **Host Verification Failed**
   - Check known_hosts file permissions
   - Verify server fingerprint
   - Ensure proper StrictHostKeyChecking setting
   - Check custom SSH config path

4. **Passphrase Issues**
   - Verify passphrase in secrets
   - Check expect script syntax
   - Test key loading manually
   - Verify SSH agent is running

## Additional Resources

1. **SSH Documentation**
   - [OpenSSH Manual](https://www.openssh.com/manual.html)
   - [SSH Config File](https://linux.die.net/man/5/ssh_config)
   - [SSH Security Best Practices](https://goteleport.com/blog/ssh-security-best-practices/)

2. **Action Documentation**
   - [actions/checkout](https://github.com/actions/checkout)

3. **Related Guides**
   - [Fastlane Match with Deploy Keys](../fastlane/README.md)
   - [GitHub Actions Security Guide](https://docs.github.com/en/actions/security-guides)
   - [GitHub Actions Checkout Custom SSH Port](https://github.com/actions/checkout/issues/1315#issuecomment-2421067786)