# Forgejo-GitHub Integration Guide

This guide explains how to integrate Forgejo with GitHub, focusing on repository migration and mirroring options.

## Overview

Forgejo-GitHub integration has two main approaches:
1. Full Repository Migration (one-time transfer of all data)
2. Repository Mirroring (ongoing sync of git commit history only)

Important Notes:
- After migration or when using mirroring, only git commit histories can be synced
- Sync is one-way only (push or pull)
- Issues, PRs, and other metadata cannot be synced between platforms

## Full Repository Migration

To migrate a repository from GitHub to Forgejo with all its data:

1. Create a GitHub personal access token with:
   - Required scope: `repo` (for private repositories) or `public_repo` (for public repositories)
   - Token creation guide: [Creating a personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)
   - Available scopes reference: [OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps#available-scopes)

2. In Forgejo:
   - Click the "+" button in the top right
   - Select "New Migration"
   - Choose "GitHub" as the migration source
   - Enter repository URL: `https://github.com/<owner>/<repo>`
   - Enter your GitHub personal access token
   - **Important**: Leave the "This repository will be a mirror" checkbox UNCHECKED
   - Configure other options as needed
   - Click "Migrate Repository"

3. Migration will import (one-time only):
   - Repository code and history
   - Issues with comments
   - Pull requests with reviews
   - Labels and milestones
   - Releases and tags
   - Wiki (if enabled)
   - Repository description and topics

Note: After migration, any new issues, PRs, or other metadata created on either platform will remain on that platform only.

## Push Mirror Setup

Use mirroring to maintain an ongoing sync of git commit history:

1. Create a GitHub personal access token with:
   - Required scope: `public_repo` (for public repositories) or `repo` (for private repositories)
   - Optional scope: `workflow` (if using GitHub Actions)
   - Token creation guide: [Creating a personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)
   - Available scopes reference: [OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps#available-scopes)

2. Create a matching repository on GitHub:
   - Must have same commit history as Forgejo repository
   - Can be either public or private
   - Repository must exist before setting up mirror

3. In Forgejo repository settings:
   - Navigate to Repository Settings > Mirror Settings
   - Fill Git Remote Repository URL: `https://github.com/<your_github_group>/<your_github_project>.git`
   - Add Authorization:
     - Username: Your GitHub username
     - Password: Your GitHub personal access token
   - Optional: Enable "Sync when new commits are pushed" (Forgejo 1.18+)
   - Click "Add Push Mirror"
   - Reference: [Forgejo Mirror Documentation](https://forgejo.org/docs/latest/user/repo-mirror/#pushing-to-a-remote-repository)

4. The repository will push automatically. Use "Synchronize Now" for manual sync.

## Best Practices

1. **Choose the Right Approach**:
   - Use **Full Migration** when:
     - You want to transfer all historical data from GitHub to Forgejo
     - You need a complete copy of issues, PRs, and other metadata
     - You understand that future issues/PRs will be platform-specific
   - Use **Mirror** when:
     - You only need to sync code changes
     - You don't need to transfer historical issues and PRs
     - You want to maintain an up-to-date code copy on both platforms

2. **Post-Migration Strategy**:
   - Decide which platform will be primary for new issues/PRs
   - Document where users should create new issues
   - Consider adding a note in README files pointing to the primary platform
   - Remember that only code changes can be synced between platforms

3. **Token Security**:
   - Never hardcode tokens in your repository
   - Use environment variables or secure secrets management
   - Regularly rotate tokens
   - Reference: [GitHub Token Security Best Practices](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation)

4. **Monitoring**:
   - Check migration completion status
   - Verify all data was migrated correctly
   - For mirrors: regularly check synchronization status
   - Set up notifications for sync failures

## Limitations

1. Synchronization (applies to both migration and mirroring):
   - Only git commit history can be synced between platforms
   - Sync is one-way only (push or pull)
   - New issues, PRs, wiki changes, and other metadata cannot be synced
   - Each platform maintains its own separate set of:
     - Issues and Pull Requests
     - Wiki content
     - Release information
     - User permissions and collaborators
     - Action/workflow configurations

2. Migration-specific:
   - One-time process for historical data
   - Some GitHub-specific features might not have Forgejo equivalents
   - User references in comments will need manual updates
   - GitHub Actions workflows may need adaptation

## Troubleshooting

1. Migration issues:
   - Verify token has correct permissions
   - Check GitHub API rate limits
   - Ensure sufficient disk space
   - Review migration logs for errors
   - Contact Forgejo admin for large migrations

2. Mirror sync fails:
   - Verify token permissions and expiration
   - Check repository access rights
   - Ensure commit histories match
   - Check network connectivity
   - Review Forgejo logs for errors

## References

1. [Forgejo Documentation](https://forgejo.org/docs/latest/)
2. [GitHub REST API Documentation](https://docs.github.com/en/rest)
3. [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps#available-scopes)
4. [Forgejo Repository Mirrors](https://forgejo.org/docs/latest/user/repo-mirror/)
5. [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)