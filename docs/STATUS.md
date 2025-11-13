# Status Command Documentation

## Overview

The `monk status` command provides a **comprehensive overview** of your current CLI context, including server connectivity, tenant selection, authentication state, and available schemas. This command is essential for understanding your current working environment before performing operations.

**Format Note**: Status command supports both **text format** (human-readable dashboard) and **JSON format** (machine-readable data) via global `--text` and `--json` flags.

## Command Structure

```bash
monk [--text|--json] status
```

## Usage Examples

### **Text Format (Default)**
```bash
monk status
```

**Output Example:**
```
Current Status

Server: local (localhost:9001)
  Status: up
  Description: Local development server

Tenant: Exercise Tracker
  Database: tenant_abc123def456
  Host: localhost

Authentication: ✓ Authenticated
  User: admin
  Expires: Fri Aug 30 14:30:45 EDT 2025

Available Schemas: 3
  users, posts, comments
```

### **JSON Format**
```bash
monk --json status
```

**Output Example:**
```json
{"server":{"name":"local","endpoint":"http://localhost:9001","status":"up","description":"Local development server"},"tenant":{"name":"Exercise Tracker","database":"tenant_abc123def456","host":"localhost"},"authentication":{"authenticated":true,"user":"admin","expires":"2025-08-30T14:30:45.000Z","expires_date":"Fri Aug 30 14:30:45 EDT 2025"},"schemas":{"count":3,"schemas":["users","posts","comments"]}}
```

## Output Components

### **Server Information**
- **Name**: Current server name from registry
- **Endpoint**: Server URL and port
- **Status**: Connection health (up/down)
- **Description**: Server description from registry

### **Tenant Information**
- **Name**: Current tenant/project name
- **Database**: Underlying database identifier
- **Host**: Database host location

### **Authentication State**
- **Status**: Authentication status (authenticated/not authenticated)
- **User**: Current authenticated username
- **Expires**: JWT token expiration time

### **Available Schemas**
- **Count**: Number of available schemas
- **List**: Schema names available for data operations

## State Scenarios

### **Fully Configured State**
```
Current Status

Server: production (api.example.com:443)
  Status: up
  Description: Production API server

Tenant: Customer Portal
  Database: tenant_xyz789abc012
  Host: db.production.example.com

Authentication: ✓ Authenticated
  User: api_user
  Expires: Fri Aug 30 16:45:12 EDT 2025

Available Schemas: 7
  users, customers, orders, products, reviews, categories, inventory
```

### **Missing Authentication**
```
Current Status

Server: local (localhost:9001)
  Status: up
  Description: Local development server

Tenant: Test Project
  Database: tenant_test123
  Host: localhost

Authentication: ✗ Not authenticated
  Use 'monk auth login TENANT USERNAME' to authenticate

Available Schemas: 0
  No schemas available (authentication required)
```

### **No Server Selected**
```
Current Status

Server: ✗ No server selected
  Use 'monk config server use <name>' to select a server

Tenant: ✗ No tenant selected
  Use 'monk config tenant use <name>' or 'monk project use <name>' to select a tenant

Authentication: ✗ Not authenticated
  Server selection required before authentication

Available Schemas: 0
  Server and tenant selection required
```

### **Server Down**
```
Current Status

Server: staging (api.staging.com:443)
  Status: down
  Description: Staging environment

Tenant: Development App
  Database: tenant_dev456
  Host: localhost

Authentication: ✗ Not authenticated
  Server is down, cannot authenticate

Available Schemas: 0
  Server connectivity required
```

## Use Cases

### **Environment Verification**
```bash
# Before performing operations, verify your context
monk status

# Expected output shows current server, tenant, and auth state
# Proceed with operations if everything looks correct
```

### **Troubleshooting**
```bash
# Commands not working? Check status
monk status

# Look for:
# - Server status (up/down)
# - Authentication state
# - Correct tenant selection
```

### **Context Switching Verification**
```bash
# Switch to different environment
monk config server use production
monk config tenant use "Customer Portal"

# Verify the switch worked
monk status
```

### **Automation Scripts**
```bash
#!/bin/bash
# Check if properly authenticated before operations

status=$(monk --json status)
auth_status=$(echo "$status" | jq -r '.authentication.authenticated')

if [ "$auth_status" != "true" ]; then
    echo "Not authenticated, aborting"
    exit 1
fi

echo "Authenticated as $(echo "$status" | jq -r '.authentication.user')"
echo "Proceeding with operations..."
```

## Integration with Other Commands

### **Pre-Operation Check**
```bash
# Standard workflow before data operations
monk status                    # Verify context
monk auth login my-app admin   # Authenticate if needed
monk data list users         # Proceed with operations
```

### **Multi-Environment Management**
```bash
# Check all environments
for server in local staging production; do
    echo "=== $server ==="
    monk config server use $server
    monk status
    echo
done
```

### **Project Context**
```bash
# After project initialization
monk project init "New App" --create-user admin --auto-login
monk status                    # Shows new project context
```

## Error Handling

### **Common Issues**

**No Server Selected:**
```
Server: ✗ No server selected
Use 'monk config server use <name>' to select a server
```
**Solution**: `monk config server use <server-name>`

**Authentication Required:**
```
Authentication: ✗ Not authenticated
Use 'monk auth login TENANT USERNAME' to authenticate
```
**Solution**: `monk auth login <tenant> <username>`

**Server Unreachable:**
```
Server: remote (api.remote.com:443)
  Status: down
```
**Solution**: Check server connectivity or switch to available server

### **Recovery Commands**
```bash
# Reset to working state
monk config server use local
monk config tenant use "known-project"
monk auth login my-project admin
monk status                    # Verify recovery
```

## Best Practices

### **Regular Status Checks**
- Run `monk status` before critical operations
- Use in scripts to verify environment state
- Check after context switches

### **JSON Output for Automation**
```bash
# Extract specific information
server=$(monk --json status | jq -r '.server.name')
tenant=$(monk --json status | jq -r '.tenant.name')
auth_user=$(monk --json status | jq -r '.authentication.user')

echo "Current context: $server/$tenant as $auth_user"
```

### **Troubleshooting Workflow**
```bash
# When commands fail:
1. monk status              # Check overall state
2. monk config server ping         # Verify server connectivity
3. monk auth status         # Check authentication
4. monk data list         # Test data access
```

## Output Format Details

### **Text Format Features**
- **Visual indicators**: ✓ for success, ✗ for issues
- **Hierarchical layout**: Nested information structure
- **Actionable messages**: Clear next steps when issues exist
- **Human-readable dates**: Localized timestamp formats

### **JSON Format Features**
- **Complete data**: All status information available
- **Consistent structure**: Predictable field names
- **Null handling**: Missing fields represented as null
- **Timestamp formats**: ISO 8601 for machine processing

---

The `monk status` command provides **essential context awareness** for all CLI operations, ensuring you always know your current working environment before executing commands.