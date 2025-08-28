# Root Commands Documentation

## CLI Extension: `monk root <scope> <operation>` Commands

This document outlines the design for extending the CLI to use the `/api/root/*` endpoints with a clean, consistent command structure for administrative operations.

## 🏗️ Command Structure Design

```bash
monk root <scope> <operation> [arguments] [flags]
```

## 📋 Proposed Command Set

### **Tenant Management (`monk root tenant`)**

```bash
# List tenants
monk root tenant list [--include-trashed] [--include-deleted] [--json]
monk root tenant ls    # Alias for list

# Create tenant
monk root tenant create <name> [--host <hostname>] [--force]
monk root tenant add <name>    # Alias for create

# Show tenant details
monk root tenant show <name> [--json]
monk root tenant info <name>   # Alias for show

# Update tenant
monk root tenant update <name> [--host <hostname>] [--activate] [--deactivate]

# Delete operations
monk root tenant trash <name>      # Soft delete (set trashed_at)
monk root tenant restore <name>    # Restore from trash
monk root tenant delete <name>     # Hard delete (permanent)
monk root tenant purge <name>      # Alias for hard delete

# Status operations
monk root tenant status <name>     # Show detailed status
monk root tenant health <name>     # Check database connectivity
```

### **System Management (`monk root system`)**

```bash
# System overview
monk root system status    # Overall system health
monk root system info      # System configuration
monk root system stats     # Usage statistics

# Database operations
monk root system backup <tenant> [--output <file>]
monk root system restore <tenant> <file>
monk root system migrate [--dry-run]

# Maintenance
monk root system cleanup [--dry-run]    # Clean up orphaned databases
monk root system vacuum <tenant>        # Database maintenance
```

### **User Management (`monk root user`)**

```bash
# Cross-tenant user operations
monk root user list [--tenant <name>]
monk root user create <tenant> <username> [--access <level>]
monk root user delete <tenant> <username>
monk root user update <tenant> <username> [--access <level>]

# Bulk operations
monk root user export <tenant> [--output <file>]
monk root user import <tenant> <file>
```

### **Configuration Management (`monk root config`)**

```bash
# Global configuration
monk root config show [--json]
monk root config set <key> <value>
monk root config get <key>
monk root config reset

# Template management
monk root config template list
monk root config template create <name> <path>
monk root config template delete <name>
```

## 🎯 Implementation Example

### **Command Structure in `bashly.yml`**

```yaml
name: monk
help: Monk CLI - Command-line interface for PaaS Backend API

commands:
  - name: root
    help: Administrative operations (development only)
    
    commands:
      - name: tenant
        help: Tenant management operations
        
        commands:
          - name: list
            help: List all tenants
            alias: ls
            flags:
              - long: include-trashed
                help: Include soft-deleted tenants
              - long: include-deleted  
                help: Include hard-deleted tenants
              - long: json
                help: Output in JSON format
                
          - name: create
            help: Create new tenant
            alias: add
            args:
              - name: name
                required: true
                help: Tenant name
            flags:
              - long: host
                arg: hostname
                help: Database host (default: localhost)
              - long: force
                help: Force creation even if exists
                
          - name: show
            help: Show tenant details  
            alias: info
            args:
              - name: name
                required: true
                help: Tenant name
            flags:
              - long: json
                help: Output in JSON format
                
          - name: delete
            help: Hard delete tenant (permanent)
            args:
              - name: name
                required: true
                help: Tenant name
            flags:
              - long: force
                help: Skip confirmation
```

### **Command Implementation Examples**

```bash
# src/root_tenant_list_command.sh
function monk_root_tenant_list() {
    local url="${MONK_SERVER_URL}/api/root/tenant"
    local params=""
    
    [[ ${args[--include-trashed]} ]] && params="?include_trashed=true"
    [[ ${args[--include-deleted]} ]] && params="${params:+${params}&}include_deleted=true"
    
    local response=$(curl -s "${url}${params}")
    
    if [[ ${args[--json]} ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.tenants[] | [.name, .status, .database, .created_at] | @tsv' |
        column -t -s $'\t' -N "NAME,STATUS,DATABASE,CREATED"
    fi
}

# src/root_tenant_create_command.sh  
function monk_root_tenant_create() {
    local name="${args[name]}"
    local host="${args[--host]:-localhost}"
    local force="${args[--force]}"
    
    # Validate name
    if [[ "$name" =~ ^(test_|monk_) ]]; then
        echo "Error: Tenant name cannot start with 'test_' or 'monk_'" >&2
        return 1
    fi
    
    # Check if exists (unless force)
    if [[ ! "$force" ]]; then
        local exists=$(monk_root_tenant_show "$name" 2>/dev/null)
        if [[ "$exists" ]]; then
            echo "Error: Tenant '$name' already exists. Use --force to override." >&2
            return 1
        fi
    fi
    
    # Create tenant
    local payload=$(jq -n --arg name "$name" --arg host "$host" '{name: $name, host: $host}')
    local response=$(curl -s -X POST "${MONK_SERVER_URL}/api/root/tenant" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if echo "$response" | jq -e '.success' >/dev/null; then
        echo "✓ Tenant '$name' created successfully"
        echo "  Database: $(echo "$response" | jq -r '.database')"
        echo "  Host: $(echo "$response" | jq -r '.host')"
    else
        echo "✗ Failed to create tenant: $(echo "$response" | jq -r '.error')" >&2
        return 1
    fi
}
```

## 🌟 Advanced Features

### **Interactive Mode**
```bash
monk root tenant create --interactive
# Prompts for name, host, etc.

monk root tenant delete --interactive  
# Shows tenant details and asks for confirmation
```

### **Batch Operations**
```bash
monk root tenant create --batch tenants.json
# Create multiple tenants from JSON file

monk root tenant export --all --output tenants-backup.json
# Export all tenant configurations
```

### **Pipeline Integration**
```bash
# Output formats for scripting
monk root tenant list --format csv
monk root tenant list --format table  
monk root tenant list --format json

# Machine-readable status codes
monk root tenant status my_app --exit-code
# Returns 0=healthy, 1=warning, 2=error
```

### **Development Workflows**
```bash
# Quick development setup
monk root tenant create dev-$(whoami) --template basic
monk tenant use dev-$(whoami)
monk auth login dev-$(whoami) root

# Cleanup development tenants
monk root tenant list --filter "dev-*" | monk root tenant delete --batch
```

## 🔧 Configuration Integration

Update CLI configuration to support root operations:

```json
// ~/.config/monk/cli/config.json
{
  "root_operations": {
    "enabled": true,
    "require_confirmation": ["delete", "purge"],
    "default_formats": {
      "list": "table",
      "show": "yaml"
    }
  }
}
```

## 📋 API Endpoint Mapping

### **Implemented `/api/root/tenant` Operations (Phase 1 Complete)**

#### **GET /api/root/tenant** - List All Tenants
```bash
curl http://localhost:9001/api/root/tenant
```
**Response:**
```json
{
  "success": true,
  "tenants": [
    {
      "name": "my_app",
      "database": "my_app", 
      "host": "localhost",
      "created_at": "2025-08-28T20:03:03.033Z",
      "updated_at": "2025-08-28T20:03:03.033Z",
      "trashed_at": null,
      "deleted_at": null,
      "status": "active"
    }
  ],
  "count": 2
}
```
**Query Parameters:**
- `?include_trashed=true` - Include soft-deleted tenants
- `?include_deleted=true` - Include hard-deleted tenants

#### **POST /api/root/tenant** - Create New Tenant
```bash
curl -X POST http://localhost:9001/api/root/tenant \
  -H "Content-Type: application/json" \
  -d '{"name": "my_new_app", "host": "localhost"}'
```
**Request Body:**
```json
{
  "name": "My New App! 🚀",  // Required: tenant name (Unicode supported)
  "host": "localhost"        // Optional: defaults to localhost
}
```
**Tenant Name Rules:**
- Minimum 2 characters
- Cannot be exact names: 'monk' or 'test' 
- Unicode characters fully supported (Chinese, emoji, accented chars, etc.)
- Spaces and special characters allowed
- Database uses SHA256 hash for safe PostgreSQL identifiers
**What it does:**
1. Validates tenant name (minimum 2 chars, not exact 'monk'/'test')
2. Creates PostgreSQL database with hashed identifier (enables Unicode support)
3. Initializes tenant database with schema (from `sql/init-tenant.sql`)
4. Creates root user in tenant database
5. Adds tenant record to `monk.tenant` table with both display name and database hash

#### **GET /api/root/tenant/:name** - Get Individual Tenant Details
```bash
curl http://localhost:9001/api/root/tenant/my_app
```
**Response:**
```json
{
  "success": true,
  "tenant": {
    "name": "my_app",
    "database": "my_app",
    "host": "localhost",
    "status": "active",
    "created_at": "2025-08-28T20:03:03.033Z",
    "updated_at": "2025-08-28T20:03:03.033Z"
  }
}
```

#### **PATCH /api/root/tenant/:name** - Update Tenant Properties
```bash
curl -X PATCH http://localhost:9001/api/root/tenant/my_app \
  -H "Content-Type: application/json" \
  -d '{"host": "new-host.example.com", "is_active": true}'
```
**Status**: ⚠️ Endpoint exists but returns 501 (Not Implemented) - requires `TenantService.updateTenant()` method

#### **DELETE /api/root/tenant/:name** - Delete Tenant (Soft/Hard)
```bash
# Soft delete (default)
curl -X DELETE http://localhost:9001/api/root/tenant/my_app

# Hard delete (permanent)
curl -X DELETE "http://localhost:9001/api/root/tenant/my_app?force=true"
```
**What it does:**
- **Default**: Soft delete (sets `trashed_at` timestamp)
- **With ?force=true**: Hard delete (removes database and tenant record)

#### **PUT /api/root/tenant/:name** - Restore Soft Deleted Tenant
```bash
curl -X PUT http://localhost:9001/api/root/tenant/my_app
```
**What it does:**
- Restores soft deleted tenant (clears `trashed_at` timestamp)

#### **GET /api/root/tenant/:name/health** - Database Health Check
```bash
curl http://localhost:9001/api/root/tenant/my_app/health
```
**Response:**
```json
{
  "success": true,
  "health": {
    "tenant": "my_app",
    "timestamp": "2025-08-28T20:40:40.409Z",
    "checks": {
      "tenant_exists": true,
      "database_exists": true,
      "database_connection": true,
      "schema_table_exists": true,
      "users_table_exists": true,
      "root_user_exists": true
    },
    "status": "healthy",
    "errors": []
  }
}
```

## 🔒 Security Model

The `/api/root/*` endpoints provide **administrative tenant management** functionality that bypasses normal JWT authentication for development convenience.

- **Localhost Development Only**: Protected by `localhostDevelopmentOnlyMiddleware`
- **No JWT Required**: Bypasses normal API authentication (unlike `/api/data/*`, `/api/meta/*`)
- **NODE_ENV=development**: Only available in development mode
- **Direct Database Access**: Uses `TenantService` for direct database operations

## 🎯 Benefits of This Design

1. **Consistent Structure**: All root operations follow same pattern
2. **Intuitive Grouping**: Related operations grouped by scope
3. **Alias Support**: Short forms for common operations (`ls`, `info`, `add`)
4. **Flexible Output**: JSON, table, CSV formats for different use cases
5. **Safety Features**: Confirmation prompts, soft deletes, dry-run modes
6. **Development Friendly**: Quick tenant creation/cleanup workflows
7. **Scriptable**: Machine-readable formats and exit codes
8. **Extensible**: Easy to add new scopes (user, config, system)

This creates a powerful administrative interface while maintaining the existing `monk` commands for normal tenant-scoped operations.

## ✅ Implementation Status

### **Phase 1: Tenant Operations (COMPLETE)**

| **CLI Command** | **API Endpoint** | **Status** | **Tested** |
|-----------------|------------------|------------|------------|
| `monk root tenant list` | `GET /api/root/tenant` | ✅ Working | ✅ |
| `monk root tenant create <name>` | `POST /api/root/tenant` | ✅ Working | ✅ |
| `monk root tenant show <name>` | `GET /api/root/tenant/:name` | ✅ **New** | ✅ |
| `monk root tenant update <name>` | `PATCH /api/root/tenant/:name` | ⚠️ Endpoint exists, not implemented | ⚠️ |
| `monk root tenant trash <name>` | `DELETE /api/root/tenant/:name` | ✅ Working | ✅ |
| `monk root tenant restore <name>` | `PUT /api/root/tenant/:name` | ✅ Working | ✅ |
| `monk root tenant delete <name>` | `DELETE /api/root/tenant/:name?force=true` | ✅ **New** | ✅ |
| `monk root tenant health <name>` | `GET /api/root/tenant/:name/health` | ✅ **New** | ✅ |

### **Phase 2-3: System/User/Config Operations (NOT APPROVED)**

The following operations are documented but **not approved for implementation**:
- ❌ `/api/root/system/*` - System operations (covered by existing `/ping` & `/health`)
- ❌ `/api/root/user/*` - User management (user infrastructure not designed)
- ❌ `/api/root/config/*` - Configuration management (not approved)

## 🚀 Future Expansion Possibilities

If needed in the future, the `/api/root/*` pattern could be extended, but current focus is on tenant management only.

This provides a clean separation between **administrative operations** (root) and **tenant-scoped operations** (data/meta) in the API architecture.