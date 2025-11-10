# Filesystem Commands Documentation

## Overview

The `monk fs` commands provide **filesystem-like operations** for exploring API data using familiar Unix commands. These commands use the File API to browse schemas and records with path-based navigation and cross-tenant access.

**Format Note**: Filesystem commands use **context-dependent output** optimized for file-like operations. They provide specialized formatting appropriate for directory listings, file content, and metadata display.

## Command Structure

```bash
monk fs <operation> <path> [--tenant <tenant>] [flags]
```

## Path Structure

### **Standard Paths** (Current Tenant)
```bash
/data/                    # Browse schemas in current tenant
/data/users/             # Browse records in users schema
/data/users/123.json     # Access specific record
/data/users/123/email    # Access specific field
/describe/                   # Browse metadata
/describe/schema/            # Browse schema definitions
```

### **Cross-Tenant Paths**
```bash
/tenant/my-app/data/users/           # Browse users in my-app tenant
/tenant/staging:my-app/data/         # Browse data in my-app on staging server
/tenant/prod:my-app/describe/schema/     # Browse schemas in production
```

## Available Commands

### **Directory Listing**

#### **List Directory Contents**
```bash
monk fs ls <path> [--long] [--tenant <tenant>]
```

**Options:**
- `--long` / `-l` - Detailed listing with metadata
- `--tenant` / `-t` - Target specific tenant (format: `tenant-name` or `server:tenant-name`)

**Examples:**

**Browse Current Tenant:**
```bash
# List available schemas
monk fs ls /data/
# users
# products  
# orders

# List records in schema
monk fs ls /data/users/
# 123.json
# 456.json
# 789.json

# Detailed listing
monk fs ls -l /data/users/
# rwx               0 2025-08-29 10:30 123.json
# rwx               0 2025-08-29 11:15 456.json
# rwx               0 2025-08-29 12:00 789.json
```

**Cross-Tenant Access:**
```bash
# Browse different tenant
monk fs ls /tenant/staging-app/data/

# Browse tenant on different server  
monk fs ls /tenant/prod:my-app/data/users/

# Use flag-based targeting
monk fs ls /data/users/ --tenant staging-app
monk fs ls /data/ --tenant prod:my-app
```

### **File Content Display**

#### **Display Record Data**
```bash
monk fs cat <path> [--tenant <tenant>]
```

**Examples:**

**Complete Record:**
```bash
monk fs cat /data/users/123.json
```
```json
{"id":"123","name":"Alice Smith","email":"alice@company.com","status":"active","created_at":"2025-08-29T10:30:00.000Z"}
```

**Specific Field:**
```bash
monk fs cat /data/users/123/email
# alice@company.com

monk fs cat /data/users/123/name  
# Alice Smith
```

**Cross-Tenant Access:**
```bash
# Access record in different tenant
monk fs cat /tenant/staging/data/users/123.json

# Access field in different tenant on different server
monk fs cat /tenant/prod:my-app/data/users/123/email
```

**Schema Definitions:**
```bash
monk fs cat /describe/schema/users.json
```
```yaml
name: users
type: object
properties:
  id:
    type: string
    format: uuid
  name:
    type: string
    minLength: 1
required:
  - name
```

### **File Deletion**

#### **Remove Records or Fields**
```bash
monk fs rm <path> [--force] [--tenant <tenant>]
```

**Options:**
- `--force` / `-f` - Force permanent deletion (default is soft delete)
- `--tenant` / `-t` - Target specific tenant

**Examples:**

**Soft Delete (Default):**
```bash
# Soft delete record (recoverable)
monk fs rm /data/users/123

# Soft delete with confirmation
monk fs rm /data/products/456
# Are you sure you want to delete /data/products/456? (y/N)
```

**Hard Delete:**
```bash
# Permanent deletion
monk fs rm -f /data/users/123

# Delete specific field
monk fs rm /data/users/123/temp_field
```

**Cross-Tenant Deletion:**
```bash
# Delete from different tenant
monk fs rm /tenant/test-env/data/users/999

# Use flag-based targeting
monk fs rm /data/users/888 --tenant test-env
```

### **File/Directory Status**

#### **Display Metadata and Schema Information**
```bash
monk fs stat <path> [--tenant <tenant>]
```

**Examples:**

**Record Metadata:**
```bash
monk fs stat /data/users/123.json
```
```
File: /data/users/123.json
Type: record
Schema: users
Size: 245 bytes
Created: 2025-08-29 10:30:00 UTC
Modified: 2025-08-29 15:45:00 UTC
Fields: id, name, email, status, created_at
```

**Schema Information:**
```bash
monk fs stat /data/users/
```
```
Directory: /data/users/
Type: schema
Schema: users
Record Count: 1,247
Total Size: 2.1 MB
Created: 2025-08-15 09:00:00 UTC
Last Record: 2025-08-29 15:45:00 UTC
Fields: 5 (id, name, email, status, created_at)
```

**Tenant-Level Statistics:**
```bash
monk fs stat /data/
```
```
Directory: /data/
Type: tenant_data
Tenant: my-app
Database: tenant_abc123
Schema Count: 8
Total Records: 15,432
Total Size: 45.7 MB
```

## Multi-Tenant Navigation

### **Path-Based Tenant Routing**
```bash
# Current tenant (implicit)
monk fs ls /data/users/

# Explicit tenant specification
monk fs ls /tenant/my-app/data/users/

# Cross-server tenant access
monk fs ls /tenant/staging:my-app/data/users/
```

### **Flag-Based Tenant Targeting**
```bash
# Alternative syntax using flags
monk fs ls /data/users/ --tenant my-app
monk fs ls /data/users/ --tenant staging:my-app

# Useful for scripting
for tenant in app1 app2 app3; do
    echo "=== $tenant ==="
    monk fs ls /data/users/ --tenant $tenant
done
```

## Wildcard and Pattern Support

### **Directory Listings with Patterns**
```bash
# All JSON files
monk fs ls /data/users/*.json

# Records matching pattern
monk fs ls /data/users/user-*.json

# All schemas
monk fs ls /data/*/
```

## Authentication Integration

Filesystem operations respect **authentication context**:

```bash
# Must be authenticated to access data
monk auth login my-app admin
monk fs ls /data/users/              # ✅ Works

# Cross-tenant requires authentication for target tenant
monk fs ls /tenant/other-app/data/   # ❌ May fail if not authenticated to other-app
```

## Automation Examples

### **Data Exploration**
```bash
#!/bin/bash
# Explore tenant data structure

echo "Schemas:"
monk fs ls /data/

echo -e "\nRecord counts:"
for schema in $(monk fs ls /data/); do
    count=$(monk fs ls /data/$schema/ | wc -l)
    echo "  $schema: $count records"
done
```

### **Cross-Tenant Data Audit**
```bash
#!/bin/bash
# Audit data across all tenants

tenants=$(monk --json tenant list | jq -r '.tenants[].name')
for tenant in $tenants; do
    echo "=== Tenant: $tenant ==="
    schemas=$(monk fs ls /data/ --tenant $tenant 2>/dev/null || echo "No access")
    for schema in $schemas; do
        if [ "$schema" != "No" ] && [ "$schema" != "access" ]; then
            count=$(monk fs ls /data/$schema/ --tenant $tenant 2>/dev/null | wc -l)
            echo "  $schema: $count records"
        fi
    done
    echo
done
```

### **Data Verification**
```bash
#!/bin/bash
# Verify critical records exist

critical_users=("admin" "system" "backup")
for user_id in "${critical_users[@]}"; do
    if monk fs stat /data/users/$user_id.json >/dev/null 2>&1; then
        echo "✅ Critical user $user_id exists"
    else
        echo "❌ Critical user $user_id missing!"
    fi
done
```

## Integration with Other Commands

### **Data Discovery Workflow**
```bash
# 1. Explore available data
monk fs ls /data/

# 2. Check schema structure  
monk fs stat /data/users/

# 3. Sample records
monk fs ls /data/users/ | head -5

# 4. Examine specific records
monk fs cat /data/users/123.json

# 5. Work with data via data commands
monk data select users 123
```

### **Schema Development Workflow**
```bash
# 1. Check existing schemas
monk fs ls /describe/schema/

# 2. Examine schema definition
monk fs cat /describe/schema/users.json

# 3. Modify schema via describe commands
cat modified-schema.json | monk describe update users

# 4. Verify changes
monk fs cat /describe/schema/users.json
```

## Security and Access Control

### **Tenant Isolation**
- Cross-tenant access requires appropriate authentication
- Path-based routing respects security boundaries
- Authentication failures provide clear error messages

### **Read-Only vs Write Operations**
- `fs ls`, `fs cat`, `fs stat` - **Read-only** (safe exploration)
- `fs rm` - **Write operation** (requires caution and confirmation)

## Error Handling

### **Path Not Found**
```bash
monk fs cat /data/users/999.json
# Error: Record not found: /data/users/999.json
```

### **Schema Not Found**
```bash
monk fs ls /data/nonexistent/
# Error: Schema 'nonexistent' not found
```

### **Authentication Required**
```bash
monk fs ls /tenant/other-app/data/
# Error: No authentication found for staging:other-app
# Use 'monk auth login other-app <username>' on server 'staging' to authenticate
```

### **Invalid Paths**
```bash
monk fs cat /invalid/path
# Error: Invalid path format. Use /data/schema/record or /describe/schema/name
```

## Performance Considerations

### **Efficient Navigation**
```bash
# Good: Direct path access
monk fs cat /data/users/123.json

# Less efficient: Listing large directories
monk fs ls /data/users/  # May be slow with many records
```

### **Cross-Tenant Performance**
```bash
# Local tenant access (fast)
monk fs ls /data/users/

# Cross-tenant access (network overhead)  
monk fs ls /tenant/remote:app/data/users/
```

## Format Behavior

Filesystem commands use **specialized formatting**:

### **Directory Listings**
- **Names only**: Simple file/directory names
- **Long format** (`-l`): Size, timestamps, permissions-style metadata

### **File Content**  
- **JSON Records**: Pretty-formatted for readability
- **Individual Fields**: Raw field values
- **YAML Schemas**: Native YAML format

### **Status Information**
- **Structured Metadata**: File sizes, counts, timestamps
- **Schema Details**: Record counts, field information
- **Tenant Statistics**: Database and storage information

## Best Practices

1. **Exploration First**: Use `fs ls` and `fs stat` to understand data structure
2. **Authentication**: Ensure proper auth for cross-tenant access
3. **Path Validation**: Use `fs stat` to verify paths before operations
4. **Careful Deletion**: Use soft delete (default) unless permanent deletion needed
5. **Pattern Efficiency**: Use specific paths rather than broad pattern matching
6. **Security Awareness**: Remember cross-tenant access requires appropriate permissions

## Comparison with Regular Commands

| Filesystem Style | Regular Command | Use Case |
|------------------|-----------------|----------|
| `monk fs ls /data/users/` | `monk data select users` | Data exploration vs retrieval |
| `monk fs cat /data/users/123.json` | `monk data select users 123` | File-like access vs API operation |
| `monk fs rm /data/users/123` | `echo '{"id":"123"}' \| monk data delete users` | Unix-style vs API-style |
| `monk fs stat /data/users/` | `monk describe select users` | Directory info vs schema definition |

**Choose Filesystem Style When:**
- Exploring unknown data structures
- Need Unix-familiar navigation
- Working across multiple tenants
- Performing file-like operations

**Choose Regular Commands When:**  
- Structured data operations
- Automation and scripting
- Complex queries and filtering
- Bulk data processing

Filesystem commands provide **intuitive data exploration** with Unix-familiar operations for multi-tenant API data navigation.