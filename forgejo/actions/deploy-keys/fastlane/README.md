# Fastlane Match with Deploy Keys

This guide explains how to set up and use fastlane match with deploy keys for iOS code signing in CI/CD workflows.

## What is Fastlane Match?

[fastlane match](https://docs.fastlane.tools/actions/match/) is a tool that helps you sync your iOS code signing certificates and provisioning profiles across your team using Git. It ensures consistent code signing setup and simplifies the process in CI/CD environments.

## Project Structure

Your project should have the following structure:
```
your-ios-project/
├── Gemfile                 # Ruby dependencies
├── Gemfile.lock           # Lock file for dependencies
└── fastlane/              # Fastlane configuration directory
    ├── Fastfile           # Fastlane lanes and configuration
    └── Matchfile          # Match configuration
```

## Setup Steps

### 1. Initial Repository Setup

1. Create a new private repository for storing certificates
2. Generate a deploy key pair specifically for fastlane match:
```bash
ssh-keygen -t ed25519 -C "fastlane-match@yourdomain.com" -f match_key -N ""
```
3. Add the public key (`match_key.pub`) to your certificates repository as a deploy key with write access
4. Store the private key (`match_key`) securely - you'll need it for GitHub Secrets

### 2. Configure Ruby Dependencies

Create a `Gemfile` in your project root:

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.219"  # Use the latest version
```

### 3. Configure Matchfile

Create `fastlane/Matchfile` in your project:

```ruby
git_url(ENV["MATCH_REPO"])
app_identifier(ENV["APP_IDENTIFIER"])
username(ENV["APPLE_DEVELOPER_USERNAME"])

# For GitHub deploy key authentication
git_private_key(ENV["MATCH_GIT_PRIVATE_KEY"])

# For all available options run `fastlane match --help`
storage_mode("git")

# Readonly mode will never create or update certificates and profiles
readonly(is_ci)

# Create a new keychain for CI
if is_ci
  keychain_name(ENV["TEMP_KEYCHAIN_NAME"] || "app-signing.keychain-db")
  keychain_password(ENV["TEMP_KEYCHAIN_PASSWORD"])
end
```

### 4. Configure Fastfile

Create `fastlane/Fastfile` in your project:

```ruby
default_platform(:ios)

platform :ios do
  # Environment variables for code signing
  TEAM_ID = ENV["TEAM_ID"]
  APP_IDENTIFIER = ENV["APP_IDENTIFIER"]
  MATCH_REPO = ENV["MATCH_REPO"]
  MATCH_TYPE = ENV["MATCH_TYPE"] || "development"
  KEYCHAIN_NAME = "app-signing.keychain-db"
  KEYCHAIN_PASSWORD = ENV["TEMP_KEYCHAIN_PASSWORD"] || SecureRandom.base64

  # Setup keychain for CI environment
  desc "Create a temporary keychain for code signing"
  lane :setup_keychain do
    create_keychain(
      name: KEYCHAIN_NAME,
      password: KEYCHAIN_PASSWORD,
      default_keychain: true,
      unlock: true,
      timeout: 3600,
      lock_when_sleeps: false
    )
  end

  # Sync certificates and profiles using match
  desc "Sync certificates using match"
  lane :sync_certificates do |options|
    # Create temporary keychain in CI
    if is_ci
      setup_keychain
    end

    # Sync certificates and profiles
    match(
      type: options[:type] || MATCH_TYPE,
      app_identifier: APP_IDENTIFIER,
      git_url: MATCH_REPO,
      readonly: is_ci,
      keychain_name: is_ci ? KEYCHAIN_NAME : nil,
      keychain_password: is_ci ? KEYCHAIN_PASSWORD : nil,
      git_private_key: ENV["MATCH_GIT_PRIVATE_KEY"]
    )
  end

  # Build for App Store
  desc "Build for App Store"
  lane :build_appstore do
    sync_certificates(type: "appstore")
    build_ios_app(
      export_method: "app-store"
    )
  end

  # Clean up keychain after build
  desc "Clean up keychain"
  lane :cleanup_keychain do
    if is_ci
      delete_keychain(name: KEYCHAIN_NAME)
    end
  end

  # Error handling
  error do |lane, exception, options|
    cleanup_keychain if is_ci
  end
end
```

### 5. GitHub Actions Workflow

The repository includes a GitHub Actions workflow (`match-workflow.yml`) that handles iOS builds using fastlane match. The workflow uses fastlane match's built-in SSH capabilities for secure repository access:

1. **SSH Key Installation**: Uses `shimataro/ssh-key-action@v2` to install the SSH key
2. **SSH Operations**: All SSH operations are handled by fastlane match internally

Required secrets:
- `SSH_KEY`: The deploy key for accessing the certificates repository
- `SSH_KEY_PASSPHRASE`: Passphrase for the SSH key (also used as match password)
- `TEAM_ID`: Your Apple Developer Team ID
- `APP_IDENTIFIER`: Your app's bundle identifier
- `MATCH_REPOSITORY`: URL of your certificates repository
- `APPLE_DEVELOPER_USERNAME`: Your Apple Developer account email
- `TEMP_KEYCHAIN_PASSWORD`: Password for temporary keychain

Example workflow file (`match-workflow.yml`):
```yaml
name: iOS Build with Match
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  ios-build:
    runs-on: macos-latest
    env:
      GIT_SERVER_DOMAIN: github.com
      TEAM_ID: ${{ secrets.TEAM_ID }}
      APP_IDENTIFIER: ${{ secrets.APP_IDENTIFIER }}
      MATCH_REPOSITORY: ${{ secrets.MATCH_REPOSITORY }}
      APPLE_DEVELOPER_USERNAME: ${{ secrets.APPLE_DEVELOPER_USERNAME }}
      TEMP_KEYCHAIN_PASSWORD: ${{ secrets.TEMP_KEYCHAIN_PASSWORD }}

    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Install SSH Key
        uses: https://github.com/shimataro/ssh-key-action@v2
        with:
          key: ${{ secrets.SSH_KEY }}
          name: id_match_key
          known_hosts: unnecessary
          if_key_exists: replace

      - name: Build iOS App
        env:
          MATCH_PASSWORD: ${{ secrets.SSH_KEY_PASSPHRASE }}
          MATCH_GIT_PRIVATE_KEY: ~/.ssh/id_match_key
        run: bundle exec fastlane build_appstore
```

### Notes

- SSH key installation is handled by `shimataro/ssh-key-action`
- All SSH operations are managed by fastlane match
- The SSH key passphrase is also used as the match password for simplicity
- SSH keys are automatically cleaned up after the workflow completes
- The temporary keychain is created and managed by fastlane
- All sensitive data is stored as GitHub Secrets

## GitHub Actions Integration

### Required Secrets

Set up these secrets in your GitHub repository:
- `SSH_KEY`: The private key content for accessing the certificates repository
- `SSH_KEY_PASSPHRASE`: Passphrase for the SSH key (also used as match password)
- `TEAM_ID`: Your Apple Developer Team ID
- `APP_IDENTIFIER`: Your app's bundle identifier
- `MATCH_REPOSITORY`: The Git URL of your certificates repository
- `APPLE_DEVELOPER_USERNAME`: Your Apple Developer account email
- `TEMP_KEYCHAIN_PASSWORD`: A secure password for the temporary keychain

## Best Practices

### 1. File Structure
- Keep Fastfile and Matchfile in the `fastlane` directory
- Keep Gemfile in the project root
- Use proper file permissions for SSH keys (600 for private keys)

### 2. Ruby Setup
- Use `ruby/setup-ruby` action with `bundler-cache: true`
- Specify exact versions in Gemfile
- Let the action handle bundler installation
- Always use `bundle exec` to run fastlane commands

### 3. Security
- Use custom SSH paths in temp directory to avoid conflicts
- Use readonly mode in CI environments
- Clean up sensitive files after use
- Use proper file permissions (600 for keys and config, 644 for known_hosts)
- Store secrets securely in GitHub Secrets
- Use a dedicated deploy key for the certificates repository
- Use StrictHostKeyChecking for SSH connections

### 4. CI/CD
- Cache Ruby dependencies for faster builds
- Use environment variables for configuration
- Implement proper cleanup procedures
- Test SSH connection before running match

## Troubleshooting

### 1. SSH Issues
- Verify key permissions (600 for private keys, 644 for known_hosts)
- Check if the key is added to the repository
- Test SSH connection with `ssh -T git@github.com`
- Verify the key file path in `MATCH_GIT_PRIVATE_KEY`

### 2. Match Issues
- Check if the repository URL is correct
- Verify the match password
- Ensure the deploy key has proper access
- Run match in verbose mode for debugging

### 3. Build Issues
- Verify team ID and bundle identifier
- Check provisioning profile setup
- Validate keychain access
- Review match logs for certificate issues

## Additional Resources

- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ruby Setup Action](https://github.com/ruby/setup-ruby)
- [Code Signing Guide](https://docs.fastlane.tools/codesigning/getting-started/)

See the complete example in [project-example/](./project-example/) for a working implementation.
