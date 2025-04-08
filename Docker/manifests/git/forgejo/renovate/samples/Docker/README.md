# Docker Samples for Renovate Testing

This directory contains Docker configuration examples that demonstrate various update patterns that Renovate can detect and manage.

## Sample Files

- **Dockerfile**: Multi-stage build example with specific version pins
- **docker-compose.yml**: Compose file with multiple services demonstrating different versioning patterns

## Update Patterns Demonstrated

### Dockerfile Examples

The sample Dockerfile demonstrates these update patterns:

1. Base image version pinning (`node:18.19.1-alpine`)
2. Multi-stage builds with different base images
3. Package version pinning in RUN instructions (`curl=8.5.0-r0`)
4. Alpine package dependencies with exact versions

### Docker Compose Examples

The docker-compose.yml file demonstrates these patterns:

1. Full version pinning (`postgres:15.5-alpine`)
2. Major.minor pinning (`redis:7.2-alpine`)
3. Digest pinning (`traefik:v2.10.5@sha256:39f269...`)
4. Latest tag usage (`prom/prometheus:latest`)
5. Custom image referencing (`example/webapp:1.0.0`)

## Renovate Configuration

The main Renovate configuration file has been updated to:

1. Enable Docker-related managers (`dockerfile`, `docker-compose`)
2. Set path matching for sample Docker files
3. Configure pinning strategies for database images
4. Group base image updates to reduce PR noise

### Package Update Grouping Strategy

This setup demonstrates effective use of Renovate's grouping capabilities, which helps reduce PR noise while maintaining meaningful update management:

#### When to Use Package Grouping

1. **Related Technologies**: Group packages that belong to the same technology stack (like Docker base images)
2. **Co-dependent Libraries**: Group libraries that should be updated together to maintain compatibility
3. **CI/CD Components**: Group GitHub Actions or other CI components that work together
4. **Shared Major Version**: Group packages that share major version lines

#### Benefits of Using `groupName` and `groupSlug`

- **Reduced PR Noise**: Instead of multiple PRs for related updates, you get a single PR
- **Consistent Updates**: All grouped dependencies are updated simultaneously
- **Simplified Testing**: Test one update PR instead of multiple individual ones
- **Cleaner Git History**: Fewer merge commits in your repository history

#### Implementation Example

```json5
{
  "description": "Group Docker base image updates",
  "matchDatasources": ["docker"],
  "matchPackageNames": ["node", "nginx", "alpine"],
  "groupName": "Docker base images",
  "groupSlug": "docker-base"
}
```

This rule groups updates for node, nginx, and alpine Docker images into a single PR with the title "Update Docker base images".

## Integration with Health Checks

All service definitions include Docker-native health checks that align with the project's infrastructure management philosophy:

1. Direct container state examination rather than external endpoint probes
2. Specific checks tailored to each service type
3. Appropriate timeouts and retry settings
