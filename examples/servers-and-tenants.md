# Servers and Tenants

Learn how to manage server connections and tenants in monk CLI. Servers are remote API endpoints, and tenants are isolated workspaces within those servers.

## Prerequisites
- Monk CLI installed
- Access to one or more Monk API servers

## Understanding the Hierarchy

```
Monk CLI
└── Servers (API endpoints)
    └── Tenants (isolated workspaces)
        └── Schemas and Data
```

- **Server**: A Monk API instance (e.g., localhost:9001, api.example.com)
- **Tenant**: An isolated workspace within a server (e.g., myproject, production)
- **Context**: Your current server + tenant selection

## Server Management

### List All Servers
```bash
monk config server list
```

Shows all registered servers with health status.

### Add a Server
```bash
monk config server set dev localhost:9001 --description "Development server"
monk config server set staging api.staging.example.com:443 --description "Staging"
monk config server set prod api.example.com:443 --description "Production"
```

### Switch Servers
```bash
monk config server use dev
monk config server use prod
```

Your server selection persists across CLI sessions.

### Check Server Status
```bash
# Check current server
monk config server current

# Ping a specific server
monk config server ping dev

# Check server health
monk config server health dev

# Ping all registered servers
monk config server ping-all

# Get detailed server info
monk config server info dev
```

### Remove a Server
```bash
monk config server delete staging
```

## Tenant Management

Tenants are isolated workspaces within a server. Each tenant has:
- Its own schemas and data
- Separate authentication
- Independent access controls
- Complete isolation from other tenants

### List Tenants
```bash
monk config tenant list
```

Shows tenants on the current server.

### Create a Tenant
```bash
# Note: Use 'monk auth register' instead for automatic setup
monk auth register myproject admin
```

This creates the tenant, user account, and authenticates you automatically.

Alternatively, for manual tenant creation:
```bash
monk config tenant set myproject "My Project"
```

### Switch Tenants
```bash
monk config tenant use myproject
```

### Remove a Tenant
```bash
monk config tenant delete old-project
```

## Complete Workflow

### Setting Up Multiple Environments

```bash
# Add all your servers
monk config server set dev localhost:9001
monk config server set staging api-staging.company.com:443
monk config server set prod api.company.com:443

# Switch to development
monk config server use dev

# Create and use a tenant
monk auth register myapp admin

# Verify setup
monk status
```

### Working Across Environments

```bash
# Development work
monk config server use dev
monk config tenant use myapp
monk describe list
monk data list users

# Switch to staging
monk config server use staging
monk config tenant use myapp
monk data list users  # Same tenant, different server

# Switch to production
monk config server use prod
monk config tenant use myapp
monk data list users  # Production data
```

### Project-Based Organization

```bash
# Create separate tenants for different projects
monk config server use dev

monk auth register fitness-app admin
monk describe create users  # Fitness user schema

monk auth register inventory-sys admin
monk describe create products  # Inventory schema

# Switch between projects easily
monk config tenant use fitness-app
monk data list users  # Fitness users

monk config tenant use inventory-sys
monk data list products  # Inventory products
```

## Multi-Environment Patterns

### Pattern 1: Server per Environment
```
dev server
├── myapp tenant
├── testing tenant

prod server
├── myapp tenant
```

### Pattern 2: Tenant per Environment
```
company server
├── dev-myapp tenant
├── staging-myapp tenant
├── prod-myapp tenant
```

### Pattern 3: Project Tenants
```
dev server
├── fitness-app tenant
├── inventory-sys tenant
├── crm tenant
```

## Checking Your Context

### Quick Status Check
```bash
monk status
```

Shows:
- Current server and health
- Current tenant
- Authentication status
- Available schemas

### Detailed Information
```bash
# Current server
monk config server current

# Server info
monk config server info

# Authentication details
monk auth status

# List schemas in current tenant
monk describe list
```

## Best Practices

### Naming Conventions

**Servers:**
```bash
monk config server set dev ...       # Local development
monk config server set staging ...   # Staging environment
monk config server set prod ...      # Production
```

**Tenants:**
```bash
# Project-based
monk auth register fitness-tracker admin
monk auth register expense-manager admin

# Environment-based
monk auth register dev-api admin
monk auth register prod-api admin
```

### Connection Management

```bash
# Always verify connection after switching
monk config server use prod
monk status --ping

# Check status before operations
monk status
```

### Environment Separation

Keep development and production completely separate:

```bash
# Development
monk config server use dev
monk config tenant use myapp-dev

# Production (different server entirely)
monk config server use prod
monk config tenant use myapp
```

## Data Migration Between Environments

```bash
# Export from staging
monk config server use staging
monk config tenant use myapp
monk data list users > users-export.json

# Import to production
monk config server use prod
monk config tenant use myapp
cat users-export.json | monk data create users
```

## Troubleshooting

### Can't Connect to Server
```bash
# Check server status
monk config server ping dev

# Get server info
monk config server info dev

# Try re-adding server
monk config server delete dev
monk config server set dev localhost:9001
```

### Authentication Issues
```bash
# Check current auth
monk auth status

# Re-authenticate
monk auth login myproject admin

# Or register new
monk auth register newproject admin
```

### Wrong Context
```bash
# Always verify your context
monk status

# Switch if needed
monk config server use correct-server
monk config tenant use correct-tenant
```

### Tenant Not Found
```bash
# List available tenants
monk config tenant list

# Check you're on the right server
monk config server current
```

## Common Commands Reference

```bash
# Server operations
monk config server list                    # List all servers
monk config server set <name> <host:port>  # Add/update server
monk config server use <name>              # Switch server
monk config server delete <name>           # Remove server
monk config server ping <name>             # Check health

# Tenant operations
monk config tenant list                    # List tenants
monk auth register <tenant> <user>         # Create tenant + user
monk config tenant use <name>              # Switch tenant
monk config tenant delete <name>           # Remove tenant

# Status and info
monk status                                # Quick connection status
monk status --ping                         # Status with health checks
monk config server current                 # Current server
monk auth status                           # Auth details
```

## Next Steps

- `monk examples getting-started` - Complete setup walkthrough
- `monk examples describe-and-data` - Work with schemas and data
- `monk examples reading-api-docs` - Learn about API capabilities

Servers and tenants provide the organizational structure for all your work with monk CLI!
