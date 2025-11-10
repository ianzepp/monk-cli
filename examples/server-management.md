# Server Management Basics

Learn how to view, add, update, and delete server connections in monk CLI.

## Prerequisites
- Monk CLI installed
- Access to Monk API servers

## Commands

### List All Servers
```bash
monk server list
```
Shows all registered servers with their health status.

### Add a New Server
```bash
monk server add dev localhost:3000 --description "Development server"
monk server add staging api.staging.example.com:443 --description "Staging environment"
monk server add prod api.example.com:443 --description "Production environment"
```

### Switch Between Servers
```bash
monk server use dev
monk server use staging
monk server use prod
```

### Check Server Health
```bash
monk server ping dev
monk server health dev
monk server ping-all
```

### Get Server Information
```bash
monk server info dev
monk server current
```

### Update Server Details
```bash
# Servers are identified by name, so to "update" you need to:
# 1. Delete the old server
monk server delete old-dev

# 2. Add the updated server
monk server add dev new-host.example.com:3000 --description "Updated development server"
```

### Remove a Server
```bash
monk server delete staging
```

## Common Workflows

### Setting Up Multiple Environments
```bash
# Add all your environments
monk server add dev localhost:3000 --description "Local development"
monk server add staging staging-api.example.com:443 --description "Staging environment"
monk server add prod prod-api.example.com:443 --description "Production environment"

# Switch to development
monk server use dev

# Check everything is working
monk server list
monk server ping dev
```

### Environment Switching
```bash
# Switch to staging for testing
monk server use staging
monk server current

# Switch back to development
monk server use dev
```

## Tips
- Server names should be short and memorable (dev, staging, prod)
- Always test server connections with `monk server ping` after adding
- Use `--description` to help remember what each server is for
- The current server selection persists across CLI sessions

## Next Steps
Try `monk examples tenant-management` to learn about managing tenants within servers.</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/server-management.md