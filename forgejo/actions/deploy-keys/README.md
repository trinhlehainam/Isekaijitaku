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

## Using Deploy Keys in Workflows

There are two main approaches to using deploy keys in your workflows, both using `actions/checkout` but with different SSH key handling:

### 1. Using SSH Agent (For Keys Without Passphrase)

This approach uses `webfactory/ssh-agent` to handle SSH keys without passphrases:

```yaml
name: Checkout with SSH Agent
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  checkout:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      GIT_SERVER_SSH_PORT: 2222
    steps:
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.DEPLOY_KEY }}
      
      - name: Git SSH Setup
        run: |
          # Create SSH config in home directory
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          
          # Configure SSH for custom port
          cat > ~/.ssh/config << EOF
          Host $GIT_SERVER_DOMAIN
            HostName $GIT_SERVER_DOMAIN
            Port $GIT_SERVER_SSH_PORT
            StrictHostKeyChecking yes
          EOF
          chmod 600 ~/.ssh/config
          
          # Add known hosts
          ssh-keyscan -t rsa,ed25519 -p $GIT_SERVER_SSH_PORT $GIT_SERVER_DOMAIN >> ~/.ssh/known_hosts
          chmod 644 ~/.ssh/known_hosts
          
          # Test SSH connection (success message expected)
          ssh -T "git@$GIT_SERVER_DOMAIN" || true
      
      # Clone repository using actions/checkout
      - name: Clone Repository
        uses: https://github.com/actions/checkout@v4
        with:
          repository: owner/repo
          ssh-key: ${{ secrets.DEPLOY_KEY }}
          github-server-url: "https://${{ env.GIT_SERVER_DOMAIN }}"
          ssh-known-hosts: ${{ vars.SSH_KNOWN_HOSTS }}

### 2. Using Expect (For Keys With Passphrase)

This approach uses `expect` to handle SSH keys that have passphrases:

```yaml
name: Checkout with Passphrase
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  checkout:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      GIT_SERVER_SSH_PORT: 2222
    steps:
      - name: Git SSH Setup
        env:
          SSH_KEY: ${{ secrets.DEPLOY_KEY }}
          SSH_KEY_PASSPHRASE: ${{ secrets.SSH_KEY_PASSPHRASE }}
        run: |
          # Install expect
          sudo apt-get update
          sudo apt-get install -y expect
          
          # Create SSH directory
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          
          # Save private key
          echo "$SSH_KEY" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          
          # Configure SSH
          cat > ~/.ssh/config << EOF
          Host $GIT_SERVER_DOMAIN
            HostName $GIT_SERVER_DOMAIN
            IdentityFile ~/.ssh/deploy_key
            Port $GIT_SERVER_SSH_PORT
            StrictHostKeyChecking yes
          EOF
          chmod 600 ~/.ssh/config
          
          # Add known hosts
          ssh-keyscan -t rsa,ed25519 -p $GIT_SERVER_SSH_PORT $GIT_SERVER_DOMAIN >> ~/.ssh/known_hosts
          chmod 644 ~/.ssh/known_hosts
          
          # Create expect script for adding key with passphrase
          cat > /tmp/add-key.exp << 'EOF'
          #!/usr/bin/expect -f
          set timeout 10
          spawn ssh-add ~/.ssh/deploy_key
          expect "Enter passphrase"
          send "$env(SSH_KEY_PASSPHRASE)\r"
          expect eof
          EOF
          chmod 700 /tmp/add-key.exp
          
          # Run expect script
          /tmp/add-key.exp
          
          # Test SSH connection (success message expected)
          ssh -T "git@$GIT_SERVER_DOMAIN" || true
      
      # Clone repository using actions/checkout
      - name: Clone Repository
        uses: https://github.com/actions/checkout@v4
        with:
          repository: owner/repo
          ssh-key: ${{ secrets.DEPLOY_KEY }}
          github-server-url: "https://${{ env.GIT_SERVER_DOMAIN }}"
          ssh-known-hosts: ${{ vars.SSH_KNOWN_HOSTS }}
      
      # Cleanup
      - name: Cleanup
        if: always()
        run: |
          rm -f ~/.ssh/deploy_key
          rm -f /tmp/add-key.exp
          rm -rf ~/.ssh
```

## Important Notes

1. **SSH Key Types**
   - Without passphrase: Use the SSH Agent approach for simpler setup
   - With passphrase: Use the Expect approach for secure key handling

2. **actions/checkout Configuration**
   - Always use the full URL `https://github.com/actions/checkout@v4`
   - SSH configuration must be in `~/.ssh` directory
   - Use `github-server-url` with `https://` prefix
   - Store SSH known hosts in repository variables

## Best Practices

1. **SSH Configuration**
   - Use custom paths in `runner.temp` directory to avoid conflicts
   - Set proper file permissions:
     - `700` for SSH directory
     - `600` for private keys and config files
     - `644` for known_hosts file
   - Use `StrictHostKeyChecking yes` for security
   - Configure custom SSH command with `-F` flag

2. **Key Security**
   - Use Ed25519 keys (more secure than RSA)
   - Consider using passphrases for production keys
   - Store keys securely in repository secrets
   - Clean up keys and config files after use
   - Never expose keys in logs or outputs

3. **Access Control**
   - Grant minimal required permissions
   - Use read-only access when possible
   - Regularly rotate keys
   - Remove unused deploy keys
   - Use separate keys for different environments

4. **Error Handling**
   - Add proper error handling in scripts
   - Use timeouts for SSH operations
   - Log SSH connection issues
   - Ensure cleanup runs with `if: always()`
   - Handle SSH agent cleanup properly

## Troubleshooting

1. **SSH Authentication**
   - Message "successfully authenticated... but does not provide shell access" is expected
   - Command exits with code 1, which is normal
   - Use `ssh -T` for testing, or `ssh -vT` for verbose output
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