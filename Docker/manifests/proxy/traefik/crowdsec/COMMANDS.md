# CrowdSec Docker Commands Guide

This document provides common commands for managing and monitoring CrowdSec in a Docker environment.

## Basic Commands

### View Metrics
```bash
docker compose exec crowdsec cscli metrics
```

### View Alerts
```bash
docker compose exec crowdsec cscli alerts list
```

## Managing Rules

### List Available Collections
```bash
docker compose exec crowdsec cscli collections list
```

### Install a Collection
```bash
docker compose exec crowdsec cscli collections install <collection-name>
```

### Update Collections
```bash
docker compose exec crowdsec cscli hub update
docker compose exec crowdsec cscli collections upgrade
```

### Enable/Disable Collections
```bash
# Enable a collection
docker compose exec crowdsec cscli collections enable <collection-name>

# Disable a collection
docker compose exec crowdsec cscli collections disable <collection-name>
```

## Managing Decisions

### List Current Decisions
```bash
docker compose exec crowdsec cscli decisions list
```

### Add Manual Decision
```bash
docker compose exec crowdsec cscli decisions add --ip <ip-address> --duration 24h --type ban
```

### Delete Decision
```bash
docker compose exec crowdsec cscli decisions delete --ip <ip-address>
```

## Managing Bouncers

### List Bouncers
```bash
docker compose exec crowdsec cscli bouncers list
```

### Add New Bouncer
```bash
docker compose exec crowdsec cscli bouncers add <bouncer-name>
```

### Delete Bouncer
```bash
docker compose exec crowdsec cscli bouncers delete <bouncer-name>
```

## Managing Parsers

### List Parsers
```bash
docker compose exec crowdsec cscli parsers list
```

### Install Parser
```bash
docker compose exec crowdsec cscli parsers install <parser-name>
```

### Remove Parser
```bash
docker compose exec crowdsec cscli parsers remove <parser-name>
```

## Debugging

### Check Logs
```bash
# View CrowdSec logs
docker compose logs crowdsec

# Follow logs in real-time
docker compose logs -f crowdsec
```

### Debug Mode
```bash
# Enable debug mode
docker compose exec crowdsec cscli config set --debug true

# Disable debug mode
docker compose exec crowdsec cscli config set --debug false
```

## Maintenance

### Backup Configuration
```bash
docker compose cp crowdsec:/etc/crowdsec ./crowdsec-backup
```

### Clean Old Data
```bash
docker compose exec crowdsec cscli database clean --force
```

### Reset CrowdSec
```bash
docker compose exec crowdsec cscli database flush
```

## Integration Testing

### Test Bouncer
```bash
# Test if bouncer is working
docker compose exec crowdsec cscli bouncers test <bouncer-name>
```

### Simulate Attack
```bash
# Add test ban
docker compose exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 1h --type ban

# Verify ban
docker compose exec crowdsec cscli decisions list --ip 1.2.3.4
```

## Best Practices

1. Regularly update CrowdSec and its collections
2. Monitor alerts and decisions regularly
3. Keep backups of your configuration
4. Test new rules in a staging environment first
5. Document any custom configurations or rules
