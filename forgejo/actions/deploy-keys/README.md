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

## Using Deploy Keys in Workflows

There are two main approaches to using deploy keys in your workflows:

### 1. Using webfactory/ssh-agent (Recommended)

This is the recommended approach as it provides a simpler and more secure way to handle SSH keys:

```yaml
name: CI with webfactory/ssh-agent
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      SSH_CONFIG_PATH: ${{ runner.temp }}/.ssh/config
      SSH_KNOWN_HOSTS_PATH: ${{ runner.temp }}/.ssh/known_hosts
    steps:
      - uses: actions/checkout@v4
      
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
      
      # Configure Git Server
      - name: Configure Git Server
        run: |
          # Create SSH directory in temp
          SSH_DIR="${{ runner.temp }}/.ssh"
          mkdir -p "$SSH_DIR"
          chmod 700 "$SSH_DIR"
          
          # Create SSH config with custom paths
          cat > "$SSH_CONFIG_PATH" << EOF
          Host $GIT_SERVER_DOMAIN
            UserKnownHostsFile $SSH_KNOWN_HOSTS_PATH
            StrictHostKeyChecking yes
          EOF
          chmod 600 "$SSH_CONFIG_PATH"
          
          # Add known hosts
          ssh-keyscan -t rsa,ed25519 $GIT_SERVER_DOMAIN > "$SSH_KNOWN_HOSTS_PATH"
          chmod 644 "$SSH_KNOWN_HOSTS_PATH"
      
      # Now you can use Git commands or actions/checkout
      - name: Clone Private Repository
        uses: actions/checkout@v4
        with:
          repository: owner/private-repo
          ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
          github-server-url: "https://${{ env.GIT_SERVER_DOMAIN }}"
      
      # Cleanup
      - name: Cleanup
        if: always()
        run: rm -rf "${{ runner.temp }}/.ssh"
```

### 2. Manual SSH Setup with Expect

For cases where you need more control over the SSH setup or need to handle keys with passphrases:

```yaml
name: CI with Manual SSH
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
      GIT_SERVER_SSH_PORT: 22
      SSH_CONFIG_PATH: ${{ runner.temp }}/.ssh/config
      SSH_KEY_PATH: ${{ runner.temp }}/.ssh/deploy_key
      SSH_KNOWN_HOSTS_PATH: ${{ runner.temp }}/.ssh/known_hosts
    steps:
      # Install expect for passphrase handling
      - name: Install expect
        run: |
          sudo apt-get update
          sudo apt-get install -y expect
      
      # Setup SSH with expect
      - name: Setup SSH
        env:
          SSH_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          SSH_KEY_PASSPHRASE: ${{ secrets.SSH_KEY_PASSPHRASE }}
        run: |
          # Create SSH directory in temp
          SSH_DIR="${{ runner.temp }}/.ssh"
          mkdir -p "$SSH_DIR"
          chmod 700 "$SSH_DIR"
          
          # Save private key
          echo "$SSH_KEY" > "$SSH_KEY_PATH"
          chmod 600 "$SSH_KEY_PATH"
          
          # Create SSH config
          cat > "$SSH_CONFIG_PATH" << EOF
          Host $GIT_SERVER_DOMAIN
            IdentityFile $SSH_KEY_PATH
            UserKnownHostsFile $SSH_KNOWN_HOSTS_PATH
            StrictHostKeyChecking yes
            Port $GIT_SERVER_SSH_PORT
          EOF
          chmod 600 "$SSH_CONFIG_PATH"
          
          # Add known hosts
          ssh-keyscan -t rsa,ed25519 -p $GIT_SERVER_SSH_PORT $GIT_SERVER_DOMAIN > "$SSH_KNOWN_HOSTS_PATH"
          chmod 644 "$SSH_KNOWN_HOSTS_PATH"
      
      # Clone repository using custom SSH command
      - name: Clone Repository
        env:
          GIT_SSH_COMMAND: "ssh -F $SSH_CONFIG_PATH"
        run: git clone "git@$GIT_SERVER_DOMAIN:owner/repo.git"
      
      # Cleanup
      - name: Cleanup
        if: always()
        run: rm -rf "${{ runner.temp }}/.ssh"
```

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

1. **Permission Denied**
   - Verify key permissions (600 for private key)
   - Check if key is added to repository
   - Verify SSH config file permissions
   - Test SSH connection with verbose logging

2. **Host Verification Failed**
   - Check known_hosts file permissions
   - Verify server fingerprint
   - Ensure proper StrictHostKeyChecking setting
   - Check custom SSH config path

3. **Passphrase Issues**
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
   - [webfactory/ssh-agent](https://github.com/webfactory/ssh-agent)
   - [actions/checkout](https://github.com/actions/checkout)

3. **Related Guides**
   - [Fastlane Match with Deploy Keys](../fastlane/README.md)
   - [GitHub Actions Security Guide](https://docs.github.com/en/actions/security-guides)