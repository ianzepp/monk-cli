# Tenant Commands Documentation

## Overview

The `monk config tenant` commands provide **tenant registry management** for organizing and switching between different tenant contexts. These commands manage the local CLI configuration for tenant access across multiple servers.

**Format Note**: Tenant commands support both **text format** (human-readable tables) and **JSON format** (machine-readable data) via global `--text` and `--json` flags.

## Command Structure

```bash
monk [--text|--json] tenant <operation> [arguments] [flags]
```

## Available Commands

### **Tenant Registry Management**

#### **List Registered Tenants**
```bash
monk config tenant list [--server <server_name>]
```

**Options:**
- `--server <name>` - Target specific server (defaults to current server)

**Examples:**

**Text Format (Default):**
```bash
monk config tenant list
```
```
Registered Tenants for Server: local

Name                 Display Name                   Auth     Added                Description
-------------------------------------------------------------------------------------
my-app               My Application                 yes      2025-08-29           Production application *
test-env             Test Environment               no       2025-08-29           Testing sandbox
staging              Staging Environment            yes      2025-08-28           Pre-production

Current tenant: my-app (marked with *)
```

**JSON Format:**
```bash
monk --json tenant list
```
```json
{"tenants":[{"name":"my-app","display_name":"My Application","description":"Production application","server":"local","added_at":"2025-08-29T10:30:00Z","authenticated":true,"is_current":true},{"name":"test-env","display_name":"Test Environment","description":"Testing sandbox","server":"local","authenticated":false,"is_current":false}],"current_tenant":"my-app","server":"local"}
```

**Cross-Server Listing:**
```bash
monk config tenant list --server staging
monk --json tenant list --server production
```

#### **Register New Tenant**
```bash
monk config tenant add <name> <display_name> [--description <text>]
```

**Examples:**
```bash
# Basic tenant registration
monk config tenant add my-app "My Application"

# With description
monk config tenant add test-env "Test Environment" --description "Development testing sandbox"

# Unicode support
monk config tenant add 测试应用 "测试应用程序" --description "中文测试环境"
```

**What Happens:**
1. Adds tenant to local registry (`~/.config/monk/cli/tenant.json`)
2. Associates tenant with current server
3. Enables tenant selection and authentication

#### **Switch to Tenant**
```bash
monk config tenant use <name>
```

**Examples:**
```bash
# Switch active tenant context
monk config tenant use my-app

# Switch to different tenant
monk config tenant use test-env
```

**Context Change:**
- Sets current tenant for all subsequent commands
- Affects `auth`, `data`, `describe`, and `fs` operations
- Persists across CLI sessions

#### **Remove Tenant from Registry**
```bash
monk config tenant delete <name>
```

**Examples:**
```bash
# Remove tenant from local registry
monk config tenant delete old-project

# Removes from CLI config only (doesn't affect server)
```

**Safety Note**: Only removes from local CLI registry. Use `monk root tenant delete` for server-side tenant deletion.

## Tenant Registry vs Server Tenants

Understanding the difference between **local registry** and **server tenants**:

### **Local Tenant Registry (`monk config tenant`)**
- **Purpose**: CLI configuration and context management
- **Storage**: `~/.config/monk/cli/tenant.json`
- **Scope**: Per-server tenant organization
- **Operations**: Add, list, use, delete from local config

### **Server Tenant Management (`monk root tenant`)**
- **Purpose**: Actual tenant creation and database management
- **Storage**: Server database and `/api/root/*` endpoints
- **Scope**: Server-wide tenant administration
- **Operations**: Create, trash, restore, delete actual tenants

### **Typical Workflow:**
```bash
# 1. Create tenant on server (administrative)
monk root tenant create "my-new-app"

# 2. Register in local CLI (for easy access)
monk config tenant add my-new-app "My New Application"

# 3. Select for use
monk config tenant use my-new-app

# 4. Authenticate and work
monk auth login my-new-app admin
monk data list users
```

## Authentication Integration

Tenant registry tracks authentication status:

```bash
# Check authentication status
monk config tenant list
# Auth column shows "yes" for authenticated tenants

# Authenticate with tenant
monk auth login my-app admin

# Authentication is server+tenant specific
monk config tenant list --server staging  # May show different auth status
```

## Output Format Support

### **Text Format (Default)**
Human-readable tables with:
- Authentication status indicators
- Current tenant marking (*)
- Formatted timestamps
- Server context information

### **JSON Format**
Compact machine-readable data:
```json
{
  "tenants": [
    {
      "name": "my-app",
      "display_name": "My Application", 
      "description": "Production application",
      "server": "local",
      "added_at": "2025-08-29T10:30:00Z",
      "authenticated": true,
      "is_current": true
    }
  ],
  "current_tenant": "my-app",
  "server": "local"
}
```

**Perfect for automation:**
```bash
# Get current tenant name
monk --json tenant list | jq -r '.current_tenant'

# List unauthenticated tenants  
monk --json tenant list | jq -r '.tenants[] | select(.authenticated == false) | .name'

# Count tenants per server
for server in $(monk --json server list | jq -r '.servers[].name'); do
  count=$(monk --json tenant list --server $server | jq '.tenants | length')
  echo "$server: $count tenants"
done
```

## Configuration Files

Tenant registry is stored in JSON configuration:

**Location**: `~/.config/monk/cli/tenant.json`

**Structure:**
```json
{
  "tenants": {
    "my-app": {
      "display_name": "My Application",
      "description": "Production application",
      "server": "local", 
      "added_at": "2025-08-29T10:30:00Z"
    },
    "test-env": {
      "display_name": "Test Environment",
      "description": "Development testing",
      "server": "local",
      "added_at": "2025-08-29T11:00:00Z" 
    }
  }
}
```

## Error Handling

### **Server Selection Errors**
```bash
monk config tenant list
# Error: No server specified and no current server selected
# Use 'monk config server use <name>' to select a server or use --server flag
```

### **Tenant Not Found**
```bash
monk config tenant use nonexistent
# Error: Tenant 'nonexistent' not found
```

### **Empty Registry**
```bash
monk config tenant list  
# Registered Tenants for Server: local
# No tenants configured for this server
# Use 'monk config tenant add <name> <display_name>' to add tenants
```

## Multi-Server Support

Tenants are **server-scoped** in the registry:

```bash
# Add tenants to different servers
monk config server use local
monk config tenant add local-app "Local Development"

monk config server use staging  
monk config tenant add staging-app "Staging Environment"

monk config server use production
monk config tenant add prod-app "Production Application"

# List tenants for specific server
monk config tenant list --server local
monk config tenant list --server staging
monk config tenant list --server production
```

## Best Practices

1. **Descriptive Names**: Use clear, descriptive display names
2. **Server Organization**: Keep tenants organized per server environment
3. **Authentication Tracking**: Monitor auth status via tenant list
4. **Context Awareness**: Always check current tenant before data operations
5. **Registry Cleanup**: Remove unused tenants from local registry

## Integration with Other Commands

Tenant selection affects all tenant-scoped operations:

```bash
# Set context
monk config tenant use my-app

# Affects these commands:
monk auth login my-app admin    # Authenticates to selected tenant
monk data list users          # Operates on tenant database  
monk describe select         # Accesses tenant schemas
monk fs ls /data/              # Browses tenant data
```

Tenant commands provide essential **context management** for efficient multi-tenant development workflows.