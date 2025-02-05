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
name: CI with webfactory/ssh-agent and actions/checkout
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      GIT_SERVER_DOMAIN: forgejo.yourdomain
    steps:
      - uses: actions/checkout@v4
      
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
      
      # Optional: Configure Git server
      - name: Configure Git Server
        run: |
          ssh-keyscan -t rsa,ed25519 $GIT_SERVER_DOMAIN >> ~/.ssh/known_hosts
      
      # Now you can use Git commands
      - name: Clone Private Repository
        run: actions/checkout@v4
        with:
          github-server-url: https://$GIT_SERVER_DOMAIN
          repository: owner/private-repo.git
          ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

### 2. Manual SSH Setup with Expect

For cases where you need more control over the SSH setup or need to handle keys with passphrases:

```yaml
name: CI with Manual SSH
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH with expect
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          SSH_KEY_PASSPHRASE: ${{ secrets.SSH_KEY_PASSPHRASE }}
          GIT_SERVER_DOMAIN: forgejo.yourdomain
          GIT_SERVER_SSH_PORT: 22
        run: |
          # Install expect
          sudo apt-get update && sudo apt-get install -y expect
          
          # Setup SSH
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          
          # Add key using expect script
          expect -f - << 'EOF'
          spawn ssh-add ~/.ssh/deploy_key
          expect "Enter passphrase"
          send "$env(SSH_KEY_PASSPHRASE)\r"
          expect eof
          interact
          EOF
          
          # Add known hosts
          ssh-keyscan -t rsa,ed25519 -p $GIT_SERVER_SSH_PORT $GIT_SERVER_DOMAIN >> ~/.ssh/known_hosts
          chmod 644 ~/.ssh/known_hosts
          
          # Clone private repository
          git clone git@$GIT_SERVER_DOMAIN:$GIT_SERVER_SSH_PORT/owner/private-repo.git
          cd private-repo
          git status

          # Clean up keys after use
          rm -f ~/.ssh/deploy_key
          rm -f /tmp/add-key.exp
```

## Best Practices

1. **Key Security**
   - Use Ed25519 keys (more secure than RSA)
   - Consider using passphrases for production keys
   - Store keys securely in repository secrets
   - Clean up keys after use

2. **Access Control**
   - Grant minimal required permissions
   - Use read-only access when possible
   - Regularly rotate keys
   - Remove unused deploy keys

3. **Error Handling**
   - Add proper error handling in scripts
   - Use timeouts for SSH operations
   - Log SSH connection issues
   - Clean up on failure

## Troubleshooting

1. **Permission Denied**
   - Verify the public key is added to repository
   - Check key permissions (600 for private key)
   - Ensure key is loaded in ssh-agent

2. **Host Verification Failed**
   - Add host to known_hosts using ssh-keyscan
   - Verify the server's fingerprint

3. **Passphrase Issues**
   - Check if passphrase is correctly set in secrets
   - Verify expect script syntax
   - Try key without passphrase for testing

## Using Deploy Keys with Fastlane Match

For detailed instructions on using deploy keys with fastlane match, including example configurations and workflows, please see the [fastlane documentation](../fastlane/README.md).

## Additional Resources

1. **SSH Documentation**
   - [Forgejo SSH Guide](https://docs.codeberg.org/security/ssh-key/)
   - [SSH Agent Forwarding](https://developer.github.com/v3/guides/using-ssh-agent-forwarding/)
   - [Troubleshooting SSH Connections](https://docs.github.com/en/authentication/troubleshooting-ssh)
   - [expect Command Guide](https://linux.die.net/man/1/expect)
   - [ssh-add automatically without a password prompt](https://unix.stackexchange.com/a/90869)
   - [expect](https://linux.die.net/man/1/expect)

2. **Action Documentation**
   - [webfactory/ssh-agent](https://github.com/webfactory/ssh-agent)
   - [actions/checkout](https://github.com/actions/checkout)