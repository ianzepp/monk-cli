# Root Commands Documentation

## Overview

The `monk root` commands provide **administrative tenant management** for localhost development environments. These commands interact with the `/api/root/*` endpoints to manage tenant lifecycle, database operations, and system health.

**Security Note**: Root commands are restricted to **localhost development only** and bypass normal JWT authentication for convenience.

## Command Structure

```bash
monk [--text|--json] root tenant <operation> [arguments] [flags]
```

## Available Commands

### **Tenant Management**

#### **List All Tenants**
```bash
monk root tenant list [--include-trashed] [--include-deleted]
monk root tenant ls    # Alias for list
```

**Options:**
- `--include-trashed` - Include soft-deleted tenants in results
- `--include-deleted` - Include hard-deleted tenants in results

**Examples:**
```bash
# Default: active tenants only (text format)
monk root tenant list

# Include trashed tenants with JSON output
monk --json root tenant list --include-trashed

# All tenants including deleted ones
monk root tenant list --include-trashed --include-deleted
```

#### **Create New Tenant**
```bash
monk root tenant create <name> [--host <hostname>] [--force]
monk root tenant add <name>    # Alias for create
```

**Options:**
- `--host <hostname>` - Database host (default: localhost)
- `--force` - Force creation even if tenant exists

**Examples:**
```bash
# Basic tenant creation
monk root tenant create "My Application"

# Unicode and emoji support
monk root tenant create "测试应用 🚀"

# Custom database host
monk root tenant create "production-app" --host db.example.com

# Force override existing tenant
monk root tenant create "test-app" --force
```

#### **Show Tenant Details**
```bash
monk root tenant show <name>
monk root tenant info <name>   # Alias for show
```

**Examples:**
```bash
# Human-readable tenant details
monk root tenant show "My Application"

# Machine-readable JSON
monk --json root tenant show "My Application"
```

#### **Health Check**
```bash
monk root tenant health <name>
```

**Examples:**
```bash
# Database connectivity and schema validation
monk root tenant health "My Application"

# JSON format for monitoring
monk --json root tenant health "My Application"
```

#### **Tenant Lifecycle Management**

**Soft Delete (Recoverable):**
```bash
monk root tenant trash <name>
```

**Restore from Trash:**
```bash
monk root tenant restore <name>
```

**Hard Delete (Permanent):**
```bash
monk root tenant delete <name> [--force]
monk root tenant purge <name>  # Alias for delete
```

**Examples:**
```bash
# Soft delete with confirmation
monk root tenant trash "old-app"

# Restore from trash
monk root tenant restore "old-app"

# Permanent deletion (requires typing "DELETE")
monk root tenant delete "old-app"

# Skip confirmation with --force
monk root tenant delete "old-app" --force
```

## Output Formats

### **Text Format (Default)**
Human-readable tables and formatted output:

```
NAME                 STATUS     DATABASE             HOST                 CREATED             
--------------------------------------------------------------------------------
My Application       active     tenant_abc123       localhost            2025-08-29          
Test App 🚀         active     tenant_def456       localhost            2025-08-29          
```

### **JSON Format**
Compact single-line machine-readable format:

```bash
monk --json root tenant list
```
```json
{"success":true,"tenants":[{"name":"My Application","database":"tenant_abc123","host":"localhost","created_at":"2025-08-29T10:30:00.000Z","status":"active"}],"count":1}
```

## Unicode Support

All tenant operations fully support Unicode characters:
- **Chinese**: `测试应用`
- **Emoji**: `🚀 Dashboard`  
- **Accented**: `café service`
- **Spaces**: `My Application Name`

Database identifiers use SHA256 hashing for safe PostgreSQL compatibility.

## Security Model

- **Development Only**: Protected by `localhostDevelopmentOnlyMiddleware`
- **No Authentication**: Bypasses JWT requirements for convenience
- **Localhost Restricted**: Only accessible from localhost requests
- **NODE_ENV=development**: Only available in development mode

## Error Handling

Root commands provide clear error messages and guidance:

```bash
# Tenant not found
monk root tenant show "nonexistent"
# Error: Tenant 'nonexistent' not found

# Confirmation required for dangerous operations  
monk root tenant delete "important-app"
# DANGER: This will PERMANENTLY delete tenant 'important-app' and its database!
# Type 'DELETE' to confirm:
```

## Integration with Regular Commands

Root commands are **administrative** and separate from regular **tenant-scoped** operations:

```bash
# Administrative: manage tenants across system
monk root tenant list
monk root tenant create "new-app"

# Regular: work within selected tenant
monk tenant use new-app
monk auth login new-app admin
monk data select users
```

This provides clean separation between **system administration** and **tenant-scoped data operations**.