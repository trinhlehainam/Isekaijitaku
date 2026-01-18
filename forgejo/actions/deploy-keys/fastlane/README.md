---
aliases:
  - "iOS Certificate Management with Fastlane Match"
tags:
  - manifest
---

# iOS Certificate Management with Fastlane Match

This guide explains how to set up and use fastlane match for managing iOS code signing certificates and provisioning profiles using deploy keys.

## What is Fastlane Match?

[fastlane match](https://docs.fastlane.tools/actions/match/) is a tool that helps you sync your iOS code signing certificates and provisioning profiles across your team using Git. It ensures consistent code signing setup and simplifies the process in CI/CD environments.

## Project Structure

Your project should have the following structure:
```
your-ios-project/
├── Gemfile                 # Ruby dependencies
├── Gemfile.lock           # Lock file for dependencies
└── fastlane/              # Fastlane configuration directory
    └── Fastfile           # Fastlane lanes for certificate management
```

## Setup Steps

### 1. Initial Repository Setup

1. Create a new private repository for storing certificates
2. Generate a deploy key pair specifically for fastlane match:
```bash
ssh-keygen -t ed25519 -C "fastlane-match@yourdomain.com" -f match_key
```
3. Add the public key (`match_key.pub`) to your certificates repository as a deploy key with `write access`
4. Store the private key (`match_key`) securely - you'll need it for GitHub Secrets

### 2. Configure Ruby Dependencies

Create a `Gemfile` in your project root:

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.219"  # Use the latest version
```

### 3. Configure App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/access/users)
2. Navigate to "Keys" tab and create a new API key with "Developer" access
3. Download the API key file (.p8) and note the Key ID and Issuer ID
4. Store these values in your CI environment:
   - `APPSTORE_KEY_ID`: The Key ID from the table row
   - `APPSTORE_ISSUER_ID`: Your issuer ID from the top of the page
   - `APPSTORE_P8`: The entire contents of the .p8 file

### 4. Configure Environment Variables

Set up the following environment variables:
```
MATCH_REPO=git@github.com:your-org/certificates.git
APP_IDENTIFIER=com.your.app
TEAM_ID=your_team_id
APPLE_DEVELOPER_USERNAME=your_apple_id@email.com
DEPLOY_KEY=contents_of_match_key_file
```

### 5. Using Fastlane Match

The following lanes are available for certificate management:

```bash
# Sync development certificates
fastlane ios sync_development

# Sync distribution certificates
fastlane ios sync_distribution
```

### 6. CI/CD Integration

For CI/CD integration, ensure you:
1. Set up all required environment variables
2. Configure the deploy key for accessing the certificates repository
3. Use the `sync_certificates` lane with appropriate type

Example CI workflow:
```yaml
jobs:
  sync-certificates:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Set up SSH key
        run: |
          ssh_key_temp=mktemp
          echo "${{ secrets.DEPLOY_KEY }}" > $ssh_key_temp
          chmod 600 $ssh_key_temp
          echo "MATCH_GIT_PRIVATE_KEY=$ssh_key_temp" >> $GITHUB_ENV
      
      - name: Add Known Hosts
        run: |
          ssh-keyscan -H ${{ env.GIT_SERVER_DOMAIN }} >> ~/.ssh/known_hosts

      - name: Sync certificates
        run: bundle exec fastlane ios sync_development
        env:
          APPLE_DEVELOPER_USERNAME: ${{ secrets.APPLE_DEVELOPER_USERNAME }}
          APPSTORE_KEY_ID: ${{ secrets.APPSTORE_KEY_ID }}
          APPSTORE_ISSUER_ID: ${{ secrets.APPSTORE_ISSUER_ID }}
          APPSTORE_P8: ${{ secrets.APPSTORE_P8 }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          MATCH_REPO: ${{ secrets.MATCH_REPO }}
          APP_IDENTIFIER: ${{ secrets.APP_IDENTIFIER }}
          MATCH_GIT_PRIVATE_KEY: ${{ secrets.MATCH_GIT_PRIVATE_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
```

## Troubleshooting

### 1. SSH Issues
- Verify key permissions (600 for private keys, 644 for known_hosts)
- Check if the key is added to the repository
- Test SSH connection with `ssh -T git@github.com`
- Verify the key file path in `DEPLOY_KEY`

### 2. Match Issues
- Check if the repository URL is correct
- Verify all required environment variables are set
- Ensure the Apple Developer account has proper access
- Check App Store Connect API key permissions

## Additional Resources

- [Fastlane Match Documentation](https://docs.fastlane.tools/actions/match/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ruby Setup Action](https://github.com/ruby/setup-ruby)
- [Code Signing Guide](https://docs.fastlane.tools/codesigning/getting-started/)
- [Game.ci iOS Deployment Documentation](https://game.ci/docs/github/deployment/ios)

See the complete example in [project-example/](./project-example/) for a working implementation.
