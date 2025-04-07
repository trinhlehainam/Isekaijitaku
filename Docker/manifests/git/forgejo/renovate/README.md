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

1. **config.js** - Main entry point for Renovate:
   - **Required modifications:**
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

2. **default.json** - Default configuration preset:
   - **Important Note:** In Renovate 39.233.5, the main default preset file must be in .json format (not .json5)
   - Use plain JSON format without comments for this specific file
   - Contains recommended presets that work for most repositories

3. **renovate.json5** - Example onboarding configuration:
   - This serves as an example of how to set up Renovate in individual repositories
   - Will be used as a template when onboarding new repositories
   - Can use JSON5 format with comments for better readability

4. **CI/CD Workflow (.forgejo/workflows/renovate.yml)**:
   - Controls the execution schedule and environment for Renovate
   - Uses the official Renovate container image
   - Configures required environment variables and secrets

#### Centralized Configuration Repository

A key component of this setup is a centralized configuration repository (`renovate_account/renovate-config`) that contains shared presets and package rules. With this approach:

1. **Create a dedicated repository** in your Forgejo instance named `renovate-config` under the `renovate_account` user

2. **Define the main default preset** in this repository using a `default.json` file (must be .json, not .json5):
   
   **File Format Notes:**
   - The primary `default.json` file must use plain JSON format (not JSON5)
   - Other reusable presets (like `javascript.json5`, `python.json5`) can use JSON5 format
   ```json5
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": [
       "config:base",
       ":semanticCommits",
       ":timezone(Asia/Tokyo)"
     ],
     "rangeStrategy": "pin",
     "packageRules": [
       {
         "description": "Group all non-major dependencies",
         "matchUpdateTypes": ["minor", "patch"],
         "groupName": "all non-major dependencies", 
         "groupSlug": "all-minor-patch"
       }
     ]
   }
   ```

3. **Extend from this central preset** in each repository's `renovate.json5` file:
   ```json5
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": [
       "local>renovate_account/renovate-config"
     ]
   }
   ```

This approach allows organization-wide control over Renovate behavior while still letting individual repositories add their specific customizations when needed.

#### Implementation Details

1. **Configuration Repository Structure**
   - The centralized repository can contain multiple preset files for different project types
   - Example structure:
     ```
     renovate-config/
     ├── default.json5     # Base configuration for all repositories
     ├── javascript.json5  # JavaScript/Node.js specific settings
     ├── python.json5      # Python specific settings
     └── docker.json5      # Docker image update settings
     ```

2. **Extending Multiple Presets**
   Repositories can extend multiple presets in their configuration:
   ```json5
   {
     "extends": [
       "local>renovate_account/renovate-config",
       "local>renovate_account/renovate-config:javascript"
     ]
   }
   ```

3. **Workflow Scheduling**
   Configure an appropriate schedule in your workflow file to balance timely updates with resource usage:
   ```yaml
   on:
     schedule:
       # Run every day at 2:00 AM
       - cron: '0 2 * * *'
     # Allow manual triggers for testing
     workflow_dispatch:
   ```

4. **Monorepo Support**
   For monorepos with multiple package managers:
   ```json5
   {
     "extends": ["local>renovate_account/renovate-config"],
     "packageRules": [
       {
         "matchPaths": ["frontend/**"],
         "extends": ["local>renovate_account/renovate-config:javascript"]
       },
       {
         "matchPaths": ["backend/**"],
         "extends": ["local>renovate_account/renovate-config:python"]
       }
     ]
   }
   ```

#### Required Repository Secrets

Add these secrets to your Forgejo repository settings:

1. **RENOVATE_TOKEN** (required): Forgejo Personal Access Token with repo and issue access
2. **RENOVATE_GITHUB_COM_TOKEN** (recommended): GitHub token for fetching changelogs and bypassing API rate limits
3. **HUB_DOCKER_COM_USER** (optional): Docker Hub username if accessing private Docker images
4. **HUB_DOCKER_COM_TOKEN** (optional): Docker Hub token or password
5. **No separate infrastructure**: Leverage existing Forgejo runners
6. **Better integration**: Credentials are stored as CI/CD secrets

#### Using Preset Configurations in Your Repositories

After setting up the central `renovate-config` repository, you can leverage its configurations in your other repositories. This eliminates configuration duplication and ensures consistent behavior across your projects.

1. **Basic Repository Configuration**

   Create a `renovate.json` or `renovate.json5` file in the root of your repository with contents like:

   ```json5
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": ["local>renovate_account/renovate-config"]
   }
   ```

   This references the renovate-config repository under your dedicated Renovate bot account.

2. **Using Specific Presets**

   You can extend specific presets from your central config by using the colon syntax:

   ```json5
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": [
       "local>renovate_account/renovate-config",
       "local>renovate_account/renovate-config:npm-deps"
     ]
   }
   ```

   This extends both the default preset and the npm-specific preset.

3. **Customizing Repository-Specific Settings**

   You can override specific settings from the centralized configuration:

   ```json5
   {
     "$schema": "https://docs.renovatebot.com/renovate-schema.json",
     "extends": ["local>renovate_account/renovate-config"],
     "schedule": ["after 10pm and before 5am"],
     "labels": ["dependencies", "automated"],
     "assignees": ["your-username"]
   }
   ```

#### Configure CI/CD Secrets

In your Forgejo repository settings:

1. Go to Settings → Secrets
2. Add the required secrets:
   - `RENOVATE_TOKEN`: Your Forgejo Personal Access Token created earlier
   - `RENOVATE_GITHUB_COM_TOKEN`: A GitHub token for fetching changelogs and metadata from GitHub repositories

#### Customize the Workflow

The provided `.forgejo/workflows/renovate.yml` file includes:

- Hourly scheduled runs with `cron: "0 * * * *"`
- Manual trigger capability with `workflow_dispatch`
- Container-based approach using the official Renovate image (`ghcr.io/renovatebot/renovate:39.233.5`)
- Environment variables for configuration

You can customize the schedule, container version, and other parameters according to your needs.

#### Renovate Configuration

This setup uses JSON5 format for configuration files, which offers several advantages over standard JSON:

- Support for comments within configuration files
- Allows trailing commas for easier maintenance
- Unquoted keys for cleaner, more readable configuration

The main configuration files are:

- `default.json5` - Primary configuration including platform settings
- `renovate.json5` - Used for onboarding new repositories
- `security.json5` - Security-specific configuration for vulnerability detection
- `config.js` - JavaScript configuration with environment variable support

You can customize these files to control how Renovate behaves:

- Set `repositories` to explicitly list repositories to monitor
- Enable `autodiscover` to find repositories automatically
- Configure dependency update rules and schedules
- Set PR behavior and limits

See the [Renovate Configuration Options](https://docs.renovatebot.com/configuration-options/) documentation for all available options.

### 3. First Run and Onboarding

1. Once the workflow is set up, trigger the workflow manually from your Forgejo repository:
   - Navigate to Actions → Workflows → Renovate
   - Click "Run workflow"

2. Monitor the workflow run to ensure it's successful:
   - Check the logs for connection to Forgejo
   - Verify that Renovate can authenticate with your Forgejo instance

3. Renovate will create an "Onboarding PR" in each repository it has access to
4. Accept the Onboarding PR to confirm that you want Renovate to monitor the repository
5. A `renovate.json5` file will be added to your repository with basic configuration

The workflow will continue to run on the scheduled interval you've configured.

## Troubleshooting

- **Authentication issues**: Verify that your PAT has all required permissions and hasn't expired
- **Repository access issues**: Ensure the Renovate user has collaborator access to repositories
- **API errors**: Check that your Forgejo/Gitea version is compatible (minimum recommended: 1.14.0)
- **Workflow failures**: Check the workflow logs for specific error messages
- **Preset lookup errors**: Ensure your repository references use correct syntax (`local>account/repo` format)

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
- [Use Gitea and Renovate Bot to Automatically Monitor Software Packages](https://about.gitea.com/resources/tutorials/use-gitea-and-renovate-bot-to-automatically-monitor-software-packages)
- [Configure Renovate on your Forgejo or Gitea self-hosted](https://vladiiancu.com/post/configure-renovate-on-your-forgejo-or-gitea-self-hosted/)
- [Gitea Renovate Config](https://gitea.com/gitea/renovate-config/src/branch/main/README.md)
- [SpotOnInc Renovate Config](https://github.com/SpotOnInc/renovate-config)
- [GitLab Renovate Runner](https://gitlab.com/renovate-bot/renovate-runner)