# Init Command Documentation

## Overview

The `monk init` command **initializes the CLI configuration directory** with all required configuration files for monk-cli operations. This is typically the first command run when setting up monk-cli on a new system.

**Format Note**: Init command provides text-only output as it's a setup operation. Format flags (`--text`/`--json`) are not applicable.

## Command Structure

```bash
monk init [path] [--force]
```

## Configuration Initialization

### **Default Initialization**
```bash
monk init
```

**Output:**
```
🏗️ Initializing Monk CLI configuration...
Configuration path: /Users/username/.config/monk/cli
✓ CLI directory exists: /Users/username/.config/monk/cli
→ Creating server.json
✓ Created server.json
→ Creating tenant.json  
✓ Created tenant.json
→ Creating auth.json
✓ Created auth.json (secure permissions)
→ Creating env.json
✓ Created env.json
✓ Monk CLI configuration initialized successfully!

CLI configuration files created in: /Users/username/.config/monk/cli
  - server.json: Server endpoint registry
  - tenant.json: Tenant registry (server-scoped)  
  - auth.json: Authentication sessions per server+tenant
  - env.json: Current working context (server+tenant+user)

Next steps:
  1. Add a server: monk server add <name> <hostname:port>
  2. Add a tenant: monk tenant add <name> <display_name>
  3. Select server: monk server use <name>
  4. Select tenant: monk tenant use <name>
  5. Authenticate: monk auth login <tenant> <username>
  6. Start working: monk data select <schema>
```

### **Custom Configuration Directory**
```bash
monk init /path/to/custom/config
```

**Examples:**
```bash
# Custom location
monk init ~/.monk-config

# Project-specific configuration
monk init ./project/.monk

# Temporary configuration
monk init /tmp/monk-test
```

### **Environment Variable Override**
```bash
export MONK_CLI_CONFIG_DIR="/path/to/custom/config"
monk init
```

**Use Cases:**
- **CI/CD Environments**: Isolated configuration per build
- **Development**: Project-specific monk configurations  
- **Testing**: Temporary configurations that don't affect main setup

### **Force Reinitialization**
```bash
monk init --force
```

**Examples:**
```bash
# Reset configuration to defaults
monk init --force

# Reset custom location
monk init /custom/path --force
```

**Behavior:**
- Overwrites existing configuration files
- **Preserves** `env.json` (current server/tenant selection)
- Resets server registry and auth sessions
- Useful for troubleshooting configuration issues

## Configuration Files Created

### **server.json - Server Registry**
```json
{
  "servers": {}
}
```
**Purpose**: Stores server endpoints, health status, and connection details

### **tenant.json - Tenant Registry**  
```json
{
  "tenants": {}
}
```
**Purpose**: Maps tenant names to servers with display names and descriptions

### **auth.json - Authentication Sessions**
```json
{
  "sessions": {}
}
```
**Purpose**: Stores JWT tokens per server+tenant combination
**Security**: Created with 600 permissions (owner read/write only)

### **env.json - Current Context**
```json
{
  "current_server": null,
  "current_tenant": null,
  "current_user": null,
  "recents": []
}
```
**Purpose**: Tracks current working context and recent selections

## Directory Structure

**Default Location**: `~/.config/monk/cli/`

**Custom Location**: Configurable via:
- Command argument: `monk init /custom/path`  
- Environment variable: `MONK_CLI_CONFIG_DIR=/custom/path`

**File Layout:**
```
~/.config/monk/cli/
├── server.json    # Server endpoint registry
├── tenant.json    # Tenant registry (server-scoped)
├── auth.json      # JWT sessions (secure permissions)
└── env.json       # Current context (server+tenant+user)
```

## Migration Handling

### **Legacy Configuration Migration**
If legacy configuration exists (`~/.config/monk/servers.json`), init automatically migrates:

```bash
monk init
# 🏗️ Migrating legacy configuration to new CLI structure...
# ✓ Configuration migrated to ~/.config/monk/cli/
# ⚠️ JWT tokens were not migrated - please re-authenticate with 'monk auth login'
```

**What's Migrated:**
- ✅ Server endpoints and current server selection
- ❌ JWT tokens (security - require re-authentication)

### **Backward Compatibility**
- Detects and migrates legacy `servers.json` format
- Preserves existing server selections where possible
- Provides clear guidance for re-authentication

## Environment-Specific Setup

### **Development Environment**
```bash
# Local development setup
monk init
monk server add local localhost:9001 --description "Local dev server"
monk server use local
monk tenant add my-app "My Application"  
monk tenant use my-app
monk auth login my-app admin
```

### **CI/CD Environment**
```bash
#!/bin/bash
# CI pipeline setup script

export MONK_CLI_CONFIG_DIR="/tmp/monk-ci-${BUILD_ID}"
monk init

monk server add ci "$API_HOST:$API_PORT" --description "CI environment"
monk server use ci
monk tenant add "$TENANT_NAME" "$TENANT_DISPLAY_NAME"
monk tenant use "$TENANT_NAME"

# Import token from CI secrets
echo "$JWT_TOKEN" | monk auth import "$TENANT_NAME" "$CI_USER"

# Run tests
monk data select users
```

### **Multi-Environment Setup**
```bash
# Development
export MONK_CLI_CONFIG_DIR="~/.config/monk/dev"
monk init
monk server add local localhost:9001

# Staging  
export MONK_CLI_CONFIG_DIR="~/.config/monk/staging"
monk init
monk server add staging api.staging.com:443

# Production
export MONK_CLI_CONFIG_DIR="~/.config/monk/prod" 
monk init
monk server add prod api.example.com:443
```

## Troubleshooting

### **Permission Issues**
```bash
monk init
# Error: Permission denied creating /Users/username/.config/monk/cli
```
**Solution**: Ensure parent directory exists and has write permissions

### **Configuration Conflicts**
```bash
# Reset corrupted configuration
monk init --force

# Start fresh with clean state
rm -rf ~/.config/monk/cli
monk init
```

### **Custom Directory Issues**
```bash
# Verify custom directory creation
ls -la /custom/path
monk init /custom/path

# Check environment variable
echo $MONK_CLI_CONFIG_DIR
monk init
```

## Integration with Other Commands

Init creates the foundation for all monk-cli operations:

```bash
# 1. Initialize configuration
monk init

# 2. Set up server access
monk server add local localhost:9001
monk server use local

# 3. Configure tenant access
monk tenant add my-app "My Application"
monk tenant use my-app

# 4. Authenticate
monk auth login my-app admin

# 5. Start working with data
monk data select users
monk describe select users
monk fs ls /data/
```

## Configuration Management

### **Backup Configuration**
```bash
# Backup entire configuration
tar -czf monk-config-backup.tar.gz ~/.config/monk/cli/

# Backup specific files
cp ~/.config/monk/cli/server.json server-backup.json
cp ~/.config/monk/cli/tenant.json tenant-backup.json
```

### **Team Configuration Sharing**
```bash
# Export server configuration for team
monk --json server list > team-servers.json

# Team members import
jq -r '.servers[] | "monk server add \(.name) \(.endpoint) --description \"\(.description)\""' team-servers.json | bash
```

### **Environment-Specific Config**
```bash
# Development team shared setup
cat > setup-dev.sh << 'EOF'
#!/bin/bash
monk init
monk server add local localhost:9001 --description "Local development"
monk server add dev-shared dev.team.com:9001 --description "Shared dev server"
monk tenant add app1 "Application 1"
monk tenant add app2 "Application 2"
EOF

chmod +x setup-dev.sh && ./setup-dev.sh
```

## Best Practices

1. **Run First**: Always run `monk init` before other commands on new systems
2. **Custom Paths**: Use custom config directories for project isolation
3. **Force Sparingly**: Only use `--force` when configuration is corrupted
4. **Environment Variables**: Use `MONK_CLI_CONFIG_DIR` for automated setups
5. **Backup Important**: Back up configuration before major changes
6. **Team Coordination**: Share server configurations but not auth tokens

The init command provides **essential configuration foundation** for all monk-cli multi-environment operations.