# Self-Hosting Renovate with Forgejo/Gitea CI/CD Runner

This guide explains how to set up a self-hosted Renovate instance that works with Forgejo (or Gitea) using Forgejo's built-in CI/CD runner instead of Docker. This approach solves the scheduling limitation of Docker Compose and allows you to store Renovate configuration directly in your Forgejo repository.

## Prerequisites

- A running Forgejo/Gitea instance (v1.14.0 or later)
- Forgejo/Gitea Runner configured and running
- Administrative access to Forgejo/Gitea

## Setup Process

### 1. Forgejo/Gitea Configuration

#### Create a Dedicated Bot Account

1. Log in to Forgejo/Gitea with an administrator account
2. Navigate to Site Administration → Users → Create a New Account
3. Create a new user with these recommended settings:
   - Username: `renovate`
   - Email: `renovate@yourdomain.com` (use a valid email)
   - Set a strong password
   - Ensure the account has a proper full name (e.g., "Renovate Bot")

#### Generate a Personal Access Token (PAT)

1. Log in as the newly created renovate user
2. Go to Settings → Applications → Generate New Token
3. Name your token (e.g., "Renovate Bot PAT")
4. Select the following permissions:
   - `user` (Read)
   - `issue` (Read and Write)
   - `organization` (Read) (for Forgejo/Gitea ≥ 1.20.0)
   - `package` (Read) (if using Forgejo/Gitea packages)
   - `repository` (Read and Write)
5. Generate and securely store the token - you won't be able to see it again

#### Repository Configuration

For each repository you want to monitor with Renovate:

1. Enable Issues in the repository settings
2. Ensure Pull Requests are enabled
3. Add the renovate user as a collaborator with write access
 
### 2. Renovate Configuration with Forgejo CI/CD Runner

Instead of using Docker Compose, we'll configure Renovate to run through Forgejo's built-in CI/CD runner, which offers several advantages:

1. **Scheduling built-in**: Use Forgejo's cron scheduling capabilities
2. **Configuration as code**: Store Renovate configuration in your repository

#### Configuration Files Setup

The repository requires these key configuration files with minimal customization. This setup implements a centralized configuration pattern that reduces duplication and ensures consistency across repositories:

1. **`default.json`** - (In Monitored Repo/Example Setup) Acts as a lookup file. It uses `extends` to point to the actual shared preset configuration files (`default.json5`, `meta.json5`) located within the central `renovate_account/renovate-config` repository. **Note:** This file must be in plain JSON format (not JSON5).
   ```json
   // Example content for default.json in a monitored repository
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": [
       "local>renovate_account/renovate-config:default.json5",
       "local>renovate_account/renovate-config:meta.json5"
     ]
   }
   ```

2. **`config.js`** - Main entry point for Renovate when run directly (less relevant for CI/CD setup using environment variables for platform config):
   - **Required modifications if used directly:**
     - `gitAuthor`: Update with your bot's email identity (e.g., "Renovate Bot <renovate-bot@example.com>")
     - `endpoint`: Set to your Forgejo/Gitea API endpoint (e.g., "https://git.example.com/api/v1/")
     - `autodiscoverFilter`: Configure which repositories to scan using glob or regex patterns:
     
       **Important Note:** Multiple patterns in autodiscoverFilter are combined using OR logic. A repository that matches ANY pattern will be included.

       **Examples:**
       - `["*/*"]` - All repositories in all organizations/users
       - `["my-org/*"]` - All repositories in the my-org organization
       - `["user1/*", "user2/*"]` - All repositories owned by user1 and user2 (OR logic)
       - `["/project-.*/"]` - Regex to match any repository starting with "project-"
       - `["my-org/important-*"]` - All repositories in my-org starting with "important-"
       
       **Multiple Pattern Examples (OR logic):**
       - `["my-org/frontend-*", "my-org/backend-*"]` - Match repos starting with frontend- OR backend- in my-org
       - `["dev-team/*", "/.*-api$/", "infra/*"]` - Match any dev-team repos OR API repos OR infra repos
       
       **Important: Using Negation Patterns Correctly**
       
       According to Renovate documentation, when using negated patterns (`!pattern`) in autodiscoverFilter:
       
       1. You should use ONLY a single negated pattern as the only item in autodiscoverFilter
       2. Do NOT mix negated patterns with other positive filters - they won't work as expected
       3. A negated pattern means "include ALL repositories EXCEPT those matching the pattern"
       
       **Correct usage of negation:**
       ```js
       module.exports = {
         autodiscover: true,
         autodiscoverFilter: [
           "!/my-org/legacy-.*/"  // Include ALL repositories EXCEPT those matching this pattern
         ]
       };
       ```
       
       **Incorrect usage of negation (will not work as expected):**
       ```js
       // DON'T DO THIS - won't work properly because of OR logic
       module.exports = {
         autodiscoverFilter: [
           "my-org/*",            // Match all repos in my-org
           "!my-org/legacy-*"     // Try to exclude legacy repos (won't work as expected)
         ]
       };
       ```
       
       **Alternative approach for complex filtering:**
       When you need more complex filtering, use only positive patterns and implement repository-level configuration to disable Renovate on specific repos.
       
       **Note:** Future Renovate versions may add better support for exclusions, but these are the current limitations.
       
       **Understanding Minimatch Pattern Syntax:**
       
       Renovate uses the minimatch library which supports these powerful pattern features:
       
       - **Standard Glob:** `*` matches any string within a path segment
         - Example: `my-org/app-*` matches `my-org/app-frontend`, `my-org/app-api`
       
       - **Globstar:** `**` matches across multiple path segments
         - Example: `my-org/**/api` matches `my-org/api`, `my-org/services/api`
       
       - **Character Classes:** `[abc]` matches any character in the brackets
         - Example: `my-org/[abc]*` matches `my-org/api`, `my-org/backend`, `my-org/config`
       
       - **Brace Expansion:** `{a,b}` matches either pattern
         - Example: `my-org/{api,web}-*` matches `my-org/api-gateway`, `my-org/web-frontend`
       
       - **Negation:** Pattern starting with `!` means "match everything EXCEPT this pattern"
         - **Warning:** Must be used alone, not with other patterns
         - **Correct example:** `["!/my-org/temp-.*/"]` matches everything EXCEPT temp repos in my-org
         - Do not mix with positive patterns due to OR logic
       
       - **Regular Expressions:** Patterns enclosed in `/` are treated as regex
         - Example: `["/my-org\/[a-z]+-service/"]` matches lowercase service repos
   - All other settings can remain at their defaults

2. **default.json5** - Default configuration preset:
   - **Important Note:** In Renovate 39.233.5, the main default preset file must be in .json format (not .json5)
   - Use plain JSON format without comments for this specific file
   - Contains recommended presets that work for most repositories

3. **renovate.json5** - Example onboarding configuration:
   - This serves as an example of how to set up Renovate in individual repositories
   - Will be used as a template when onboarding new repositories
   - Can use JSON5 format with comments for better readability

4. **CI/CD Workflow (.forgejo/workflows/renovate.yml)**:
   - Controls the execution schedule and environment for Renovate
   - Uses the official Renovate container image from GitHub Container Registry (ghcr.io)
   - Provides GitHub credentials to avoid image pull rate limits
   - Configures required environment variables and secrets

#### Centralized Configuration Repository

A key component of this setup is a centralized configuration repository (`renovate_account/renovate-config`) that contains shared presets and package rules. With this approach:

1. **Create a dedicated repository** in your Forgejo instance named `renovate-config` under the `renovate_account` user

2. **Define the Core Presets** within this repository:
   - **`default.json5`**: This file should contain your primary, shared Renovate configurations applicable to most repositories. JSON5 format is recommended for readability (allows comments).
     ```json5
     // renovate-config/default.json5 - Example Content
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       "extends": [
         "config:base", // Recommended base configuration from Renovate
         ":dependencyDashboard",
         ":enableVulnerabilityAlertsWithLabel('security')",
         ":ignoreModulesAndTests",
         ":label(renovate)",
         ":prConcurrentLimit20",
         ":prHourlyLimit2",
         ":rebaseStalePrs",
         ":timezone(Asia/Tokyo)" // Set your desired timezone
       ],
       "rangeStrategy": "pin", // Or "update-lockfile", "bump"
       "packageRules": [
         {
           "description": "Group all non-major dependencies",
           "matchUpdateTypes": ["minor", "patch"],
           "groupName": "all non-major dependencies", 
           "groupSlug": "all-minor-patch"
         }
         // Add other organization-wide rules here
       ]
     }
     ```
   - **`meta.json5`**: This file is intended for platform-specific configurations, overrides, or metadata relevant to the Forgejo/Gitea environment. Separating this keeps the `default.json5` focused on general dependency rules.
     ```json5
     // renovate-config/meta.json5 - Example Content
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       // Add Forgejo/Gitea specific settings if needed
       // e.g., hostRules, specific package manager versions, etc.
       "platformCommit": true // Example: Force platform commit support if needed
     }
     ```
   - **Optional Presets**: You can add other `.json5` files for specific project types (e.g., `javascript.json5`, `python.json5`, `docker.json5`) containing relevant rules, which can be extended by repositories as needed.
   - **Advanced Preset Example: Docker in Ansible Templates**
     Renovate can detect and update Docker images in Ansible Jinja2 templates using a custom regex manager defined within a preset (e.g., in your central `renovate-config` repository or a specific `docker.json5` preset):
     ```json5
     // Example definition within a .json5 preset file
     {
       // Ensure the regex manager is enabled globally or within this preset
       "enabledManagers": ["custom.regex"], // ... potentially others
       "customManagers": [
         {
           "description": "Detects/updates Docker images in Ansible Jinja2 templates",
           "customType": "regex",
           "datasourceTemplate": "docker",
           "fileMatch": [
             // Matches docker-compose.yaml.j2, compose.yml.j2 etc.
             "(^|/)(?:docker-)?compose[^/]*\\.ya?ml\\.j2$"
           ],
           "matchStrings": [
             // Regex to find image lines, capturing depName and currentValue/Digest
             // Ref: https://github.com/renovatebot/renovate/issues/10993#issuecomment-2367518146
             "image:\\s*\"?(?<depName>[^\\s:@\"]+)(?::(?<currentValue>[-a-zA-Z0-9.]+))?(?:@(?<currentDigest>sha256:[a-zA-Z0-9]+))?\"?"
           ]
         }
       ]
     }
     ```
     This allows Renovate to track Docker image dependencies even when defined within Ansible's Jinja2 templating structure.

3. **Extend from the Central Presets** in each monitored repository:
   - **Recommended Method (using `default.json` lookup):** Create a `default.json` file (must be plain JSON, no comments) in the monitored repository's configuration directory (e.g., `.github/renovate/`, `.forgejo/renovate/`). This file explicitly tells Renovate which presets to load from the central repository.
     ```json
     // .github/renovate/default.json - In Monitored Repo
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       "extends": [
         "local>renovate_account/renovate-config:default.json5",
         "local>renovate_account/renovate-config:meta.json5"
       ]
     }
     ```
   - **Alternative Method (using `renovate.json5`):** If you don't use the `default.json` lookup, you can create a `renovate.json5` file in the monitored repository and extend the central configuration implicitly or explicitly.
     ```json5
     // .github/renovate/renovate.json5 - In Monitored Repo
     {
       "$schema": "https://docs.renovatebot.com/renovate-schema.json",
       "extends": [
         "local>renovate_account/renovate-config" // Implicitly uses default.json/default.json5 from central repo
         // Or explicitly extend specific files:
         // "local>renovate_account/renovate-config:default.json5",
         // "local>renovate_account/renovate-config:meta.json5"
       ]
       // Add repository-specific overrides here if necessary
     }
     ```

This centralized approach provides consistency while allowing repository-specific adjustments.

## CI/CD Workflow Integration (Forgejo Actions)

Renovate integrates well with Forgejo Actions (or Gitea Actions) for automated dependency updates using a workflow file (e.g., `.forgejo/workflows/renovate.yml`).

### Workflow File Overview

A workflow file orchestrates the Renovate runs. Key components typically include:

- **Triggers**: Defines when the workflow runs (e.g., scheduled `cron` runs, manual `workflow_dispatch`).
- **Job Setup**: Configures the runner environment.
- **Container Execution**: Runs Renovate within its official Docker container, pulling the image from GitHub Container Registry (`ghcr.io`).
- **Credentials**: Provides necessary credentials (via secrets) for pulling the container image and interacting with APIs.
- **Environment Variables**: Configures Renovate's runtime behavior.

### Required Secrets

Add the following secrets to your Forgejo repository settings (usually under `Settings -> Secrets`) to provide sensitive credentials to the workflow:

1.  **`RENOVATE_TOKEN`**: Forgejo Personal Access Token with `write:repository` scope for API access (required).
2.  **`RENOVATE_GITHUB_COM_USERNAME`**: Your GitHub username. Used for authenticating with `ghcr.io` to pull the Renovate container image.
3.  **`RENOVATE_GITHUB_COM_TOKEN`**: GitHub Personal Access Token (classic or fine-grained with `read:packages` scope). Needed for:
    - Authenticating with `ghcr.io` (along with the username) to prevent rate limits.
    - Fetching changelogs and release notes from GitHub.com repositories.
4.  **`DOCKER_USERNAME`** (Optional): Your Docker Hub username if you need higher rate limits for Docker Hub images.
5.  **`DOCKER_PASSWORD`** (Optional): Your Docker Hub access token (not password) with read-only access.

*Note on Naming:* Forgejo/Gitea CI often disallows secrets prefixed with `GITHUB_` or `GITEA_`, hence the `RENOVATE_` prefix is recommended for the GitHub credentials used here.

### Runtime Environment Variables

These environment variables are typically set within the workflow's `env:` block (often using the secrets defined above) to configure how Renovate operates:

-   `RENOVATE_TOKEN`: Set using `${{ secrets.RENOVATE_TOKEN }}`. Provides the Forgejo API token to Renovate.
-   `LOG_LEVEL`: Controls the verbosity of Renovate's logs (e.g., `info`, `debug`).
-   `DOCKER_USERNAME`, `DOCKER_PASSWORD`: Set using secrets if needed for Docker Hub authentication.

*Note:* In this setup, core configurations like the platform endpoint and autodiscovery settings are typically defined within the `config.js` file, not directly as environment variables in the workflow.

### Example Workflow (`.forgejo/workflows/renovate.yml`)

```yaml
name: Renovate Dependencies

on:
  schedule:
    - cron: '0 18 * * *' # Adjust schedule (UTC)
  workflow_dispatch: # Allows manual runs

jobs:
  renovate:
    runs-on: ubuntu-latest # Or your preferred runner
    container:
      # Official Renovate image from GitHub Container Registry
      # Pin to a specific stable version is recommended
      image: ghcr.io/renovatebot/renovate:39.236.2
      credentials:
        # Use secrets for ghcr.io authentication
        username: ${{ secrets.RENOVATE_GITHUB_COM_USERNAME }}
        password: ${{ secrets.RENOVATE_GITHUB_COM_TOKEN }}
      env:
        # --- Core Runtime Configuration ---
        RENOVATE_TOKEN: ${{ secrets.RENOVATE_TOKEN }}
        # --- Logging ---
        LOG_LEVEL: info
        # --- Optional Docker Hub Auth ---
        # DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
        # DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Explanation of Workflow Configuration

*   **Container Credentials**: `RENOVATE_GITHUB_COM_USERNAME` and `RENOVATE_GITHUB_COM_TOKEN` secrets authenticate with `ghcr.io` to pull the Renovate Docker image securely and avoid rate limits.
*   **Environment Variables (`env:`)**: These configure Renovate's operation:
    *   `RENOVATE_TOKEN`: Provides the necessary Forgejo API key (from the secret).
    *   `LOG_LEVEL`: Adjusts logging detail.
    *   Optional Docker Hub credentials can be passed if needed by your dependencies.
    *   (Other settings like endpoint, platform, and discovery are handled by `config.js`)

This integrated setup ensures Renovate runs with the correct authentication and configuration within your CI/CD pipeline.

## Onboarding New Repositories

After setting up the central configuration repository and the CI/CD workflow, follow these steps to enable Renovate for a new repository:

1. **Ensure Access**: Confirm the `renovate_account` user (or the user associated with `RENOVATE_TOKEN`) has at least `Write` access to the repository.
2. **Update Filter (if needed)**: If your `RENOVATE_AUTODISCOVER_FILTER` doesn't already include the new repository, update the filter pattern in your workflow file's environment variables.
3. **Create Config Files**: Add the necessary configuration file(s) to the repository (usually in `.github/renovate/` or `.forgejo/renovate/`):
   *   If using the **Recommended Method**, add `default.json` pointing to the central presets (see step 3 in Centralized Configuration Setup).
   *   If using the **Alternative Method**, add `renovate.json5` extending the central presets.
   *   _Initially, you might let Renovate create the onboarding PR first, which will add a basic `renovate.json5`, and then you can modify or replace it with your preferred setup (`default.json` or a more specific `renovate.json5`)._
4. **Trigger Renovate**: Wait for the next scheduled run or trigger the workflow manually.
5. **Merge the Onboarding PR**: Renovate should create an initial onboarding pull request. Review and merge this PR to complete the setup.

## Troubleshooting

### GitHub Actions Compatibility

Forgejo CI environments require specific handling for artifact actions:

1. **Official GitHub Actions limitations**
   - GitHub's `actions/upload-artifact` and `actions/download-artifact` v4+ use APIs unavailable in Forgejo
   - The default.json preset constrains these actions to v3.x for compatibility
   - This limitation applies to all Forgejo/GHES environments until GitHub adds native support

2. **Forgejo-specific forks**
   - Alternative implementation: `forgejo/upload-artifact@v4` and `forgejo/download-artifact@v4`
   - These forks implement container-native access patterns compatible with Forgejo CI
   - The workflow in this repository demonstrates using these Forgejo-specific forks

3. **Concurrency limitations**
   - Forgejo/Gitea CI doesn't fully support GitHub Actions concurrency features
   - The workflow is configured to avoid these features to prevent race conditions

### Common Issues

1. **API Rate Limits**: Verify that your PAT has all required permissions and hasn't expired
- **Repository access issues**: Ensure the Renovate user has collaborator access to repositories
- **API errors**: Check that your Forgejo/Gitea version is compatible (minimum recommended: 1.14.0)
- **Workflow failures**: Check the workflow logs for specific error messages
- **Preset lookup errors**: Ensure your repository references use correct syntax (`local>account/repo` format)
- **Missing changelogs**: If PRs don't include changelogs, check your `RENOVATE_GITHUB_COM_TOKEN` permissions

## Platform-Specific Notes

- Gitea versions older than v1.14.0 cannot add reviewers to PRs
- Platform-native automerge requires Gitea v1.24.0+ or Forgejo v10.0.0+
- If using Gitea older than v1.16.0, you must enable [clone filters](https://docs.gitea.io/en-us/clone-filters/)
- Forgejo Workflows/Actions require Forgejo v3.4.0+ or Gitea v1.20.0+

## Further Documentation

For detailed configuration and customization, refer to these official resources:

- [Renovate Gitea/Forgejo Platform Documentation](https://docs.renovatebot.com/modules/platform/gitea/)
- [Self-hosted Renovate Configuration Options](https://docs.renovatebot.com/self-hosted-configuration/)
- [Renovate Self-Hosting Examples](https://docs.renovatebot.com/examples/self-hosting/)
- [Gitea Renovate Config](https://gitea.com/gitea/renovate-config/src/branch/main/README.md)
- [SpotOnInc Renovate Config](https://github.com/SpotOnInc/renovate-config)
- [GitLab Renovate Runner](https://gitlab.com/renovate-bot/renovate-runner)