# Authentication Commands Documentation

## Overview

The `monk auth` commands provide **JWT token management** and authentication workflows for secure access to tenant databases. These commands handle login, logout, token inspection, and session management across multiple servers and tenants.

**Format Note**: Authentication commands support both **text format** (human-readable status) and **JSON format** (machine-readable data) via global `--text` and `--json` flags.

## Command Structure

```bash
monk [--text|--json] auth <operation> [arguments] [flags]
```

## Available Commands

### **Session Management**

#### **List All Sessions**
```bash
monk auth list
```

**Text Format (Default):**
```
Stored JWT Tokens

| SESSION | SERVER | TENANT | USER | CREATED | EXPIRED | CURRENT |
|---|---|---|---|---|---|---|
| local:my-app | local | my-app | admin | 2025-08-29 | no | * |
| local:test-env | local | test-env | user1 | 2025-08-28 | no |   |
| staging:my-app | staging | my-app | admin | 2025-08-27 | yes |   |

Current session: local:my-app (marked with *)
Current session expires: Fri Aug 30 14:30:45 EDT 2025
```

**JSON Format:**
```bash
monk --json auth list
```
```json
{"sessions":[{"session_key":"local:my-app","server":"local","tenant":"my-app","user":"admin","created_at":"2025-08-29T10:30:00Z","expires_at":1756550645,"expires_date":"Fri Aug 30 14:30:45 EDT 2025","is_expired":false,"is_current":true},{"session_key":"local:test-env","server":"local","tenant":"test-env","user":"user1","created_at":"2025-08-28T15:20:00Z","expires_at":1756460000,"expires_date":"Thu Aug 29 12:00:00 EDT 2025","is_expired":false,"is_current":false}],"current_session":"local:my-app"}
```

**Use Cases:**
- View all stored authentication sessions across servers and tenants
- Check which tokens are expired
- Identify current active session
- Audit authentication status before operations

### **Authentication Workflow**

#### **Register New Tenant and User**
```bash
monk auth register <tenant> <username>
```

**Examples:**
```bash
# Register new tenant and user in one step
monk auth register my-new-app admin

# Register with Unicode tenant name
monk auth register "测试应用" admin
```

**What Happens:**
1. Sends registration request to current server's `/auth/register` endpoint
2. Server creates new tenant and database
3. Server creates initial user account
4. Receives JWT token for new tenant+user
5. Stores token in session registry (`~/.config/monk/cli/auth.json`)
6. Adds tenant to local tenant registry
7. Updates current tenant context
8. Enables immediate authenticated operations

**Output:**
```
Registering new tenant: my-new-app, username: admin
Sending registration request to: http://localhost:9001/auth/register
✓ Registration successful
Tenant: my-new-app
Database: tenant_abc123
Username: admin
Token expires in: 86400 seconds
JWT token stored for server+tenant context
Tenant added to local registry for server: local
```

**Use Cases:**
- Quick project setup without manual tenant creation
- Automated tenant provisioning in scripts
- Development and testing workflows
- Self-service tenant creation

**Note**: This is a convenience command that combines `monk root tenant create` + `monk tenant add` + `monk auth login` into a single operation.

#### **Login to Tenant**
```bash
monk auth login <tenant> <username>
```

**Examples:**
```bash
# Basic authentication
monk auth login my-app admin

# Different user roles
monk auth login my-app user123
monk auth login production-app operator

# Unicode tenant names
monk auth login "测试应用" admin
```

**What Happens:**
1. Sends authentication request to current server
2. Receives and validates JWT token
3. Stores token in session registry (`~/.config/monk/cli/auth.json`)
4. Updates current tenant context
5. Enables authenticated API operations

#### **Logout (Clear Token)**
```bash
monk auth logout
```

**Examples:**
```bash
monk auth logout
# Logged out successfully
# Cleared authentication for current server+tenant context
```

**Effect**: Removes JWT token for current server+tenant session

### **Authentication Status**

#### **Check Authentication Status**
```bash
monk auth status
```

**Text Format (Default):**
```
Tenant: my-app
Database: tenant_abc123
Expires: Fri Aug 30 14:30:45 EDT 2025
Server: local
Tenant: my-app  
User: admin
✓ Authenticated
```

**JSON Format:**
```bash
monk --json auth status
```
```json
{"authenticated":true,"has_token":true,"token_info":{"tenant":"my-app","database":"tenant_abc123","exp":1756550645,"exp_date":"Fri Aug 30 14:30:45 EDT 2025"},"current_context":{"server":"local","tenant":"my-app","user":"admin"}}
```

**Unauthenticated State:**
```
✗ Not authenticated
Use 'monk auth login TENANT USERNAME' to authenticate
```

#### **JWT Token Information**
```bash
monk auth info
```

**Text Format (Default):**
```
✓ JWT Token Information:

Subject: admin
Name: Administrator
Tenant: my-app
Database: tenant_abc123
Access Level: full
Issued At: Thu Aug 29 10:30:00 EDT 2025
Expires At: Fri Aug 30 14:30:45 EDT 2025
```

**JSON Format:**
```bash
monk --json auth info
```
```json
{"sub":"admin","name":"Administrator","tenant":"my-app","database":"tenant_abc123","access":"full","iat":1756464200,"exp":1756550645,"exp_date":"Fri Aug 30 14:30:45 EDT 2025","token_valid":true}
```

### **Token Management**

#### **Display Raw Token**
```bash
monk auth token
```

**Output:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsInRlbmFudCI6Im15LWFwcCIsImRhdGFiYXNlIjoidGVuYW50X2FiYzEyMyIsImFjY2VzcyI6ImZ1bGwiLCJpYXQiOjE3NTY0NjQyMDAsImV4cCI6MTc1NjU1MDY0NX0.signature
```

**Usage**: Raw token for external integrations or API testing

#### **Import External Token**
```bash
monk auth import <tenant> <username> [--token <jwt>]
```

**Examples:**
```bash
# Import token via stdin
echo "eyJhbGciOiJIUzI1NiI..." | monk auth import my-app admin

# Import token via flag
monk auth import my-app admin --token "eyJhbGciOiJIUzI1NiI..."
```

**Use Cases**: Integration with OAuth flows, SSO systems, or external authentication

### **Token Validation**

#### **Check Expiration Time**
```bash
monk auth expires
```

**Output:**
```
Fri Aug 30 14:30:45 EDT 2025
```

#### **Check if Token Expired**
```bash
monk auth expired
```

**Exit Codes:**
- `0` - Token is valid
- `1` - Token is expired or missing

**Usage in Scripts:**
```bash
if monk auth expired; then
    echo "Need to re-authenticate"
    monk auth login my-app admin
fi
```

### **API Health Check**

#### **Authenticated Ping**
```bash
monk auth ping [--verbose] [--jwt-token <token>]
```

**Options:**
- `--verbose` - Show detailed server response
- `--jwt-token <token>` - Use specific JWT token instead of stored token

**Text Format (Default):**
```bash
monk auth ping
```
```
pong: authenticated
domain: my-app
database: ok
```

**Verbose Mode:**
```bash
monk auth ping --verbose
# Using current server: local
# ✓ Server is reachable (HTTP 200)
# Response: {"pong":"authenticated","domain":"my-app","database":"ok","timestamp":"2025-08-29T11:30:00Z"}
```

**JSON Format:**
```bash
monk --json auth ping
```
```json
{"pong":"authenticated","domain":"my-app","database":"ok","http_code":200,"timestamp":"2025-08-29T11:30:00Z","success":true,"reachable":true}
```

**Error Cases:**
```bash
monk --json auth ping
```
```json
{"success":false,"reachable":true,"http_code":401,"timestamp":"2025-08-29T11:30:00Z","error":"Authentication failed","message":"JWT token is invalid or expired"}
```

## Session Management

### **Server+Tenant Sessions**
Authentication is **server and tenant specific**:

```bash
# Each combination is a separate session
monk server use local && monk auth login app1 admin    # Session: local:app1
monk server use local && monk auth login app2 user     # Session: local:app2  
monk server use staging && monk auth login app1 admin  # Session: staging:app1
```

### **Session Storage**
**Location**: `~/.config/monk/cli/auth.json`

**Structure**:
```json
{
  "sessions": {
    "local:my-app": {
      "jwt_token": "eyJhbGciOiJIUzI1NiI...",
      "tenant": "my-app",
      "user": "admin", 
      "server": "local",
      "created_at": "2025-08-29T10:30:00Z"
    },
    "staging:my-app": {
      "jwt_token": "eyJhbGciOiJIUzI1NiI...",
      "tenant": "my-app",
      "user": "admin",
      "server": "staging", 
      "created_at": "2025-08-29T11:00:00Z"
    }
  }
}
```

### **Context Switching**
```bash
# Switch server - may need re-authentication
monk server use staging
monk auth status          # May show "Not authenticated"
monk auth login my-app admin

# Switch tenant - need new authentication  
monk tenant use different-app
monk auth login different-app user
```

## Security Features

### **Token Security**
- JWT tokens stored with **600 permissions** (owner read/write only)
- Automatic token validation on API requests
- Clear error messages for expired or invalid tokens
- Session isolation between server+tenant combinations

### **Expiration Handling**
```bash
# Check if token will expire soon
expires=$(monk auth expires)
if [[ $(date -d "$expires" +%s) -lt $(date -d "1 hour" +%s) ]]; then
    echo "Token expires soon, consider re-authenticating"
fi
```

## Error Handling

### **Authentication Failures**
```bash
monk auth login my-app wrongpassword
# Error: Authentication failed
# Invalid credentials for tenant 'my-app'
```

### **Token Issues**
```bash
monk auth info
# Error: No authentication token found
# Use 'monk auth login TENANT USERNAME' to authenticate

monk auth ping
# Error: Authentication failed (HTTP 401)  
# JWT token is invalid or expired
# Use 'monk auth login TENANT USERNAME' to re-authenticate
```

### **Context Issues**
```bash
monk auth status
# Error: No current server selected
# Use 'monk server use <name>' to select a server
```

## Automation Examples

### **Session Health Check**
```bash
#!/bin/bash
# Check authentication status across all servers

servers=$(monk --json server list | jq -r '.servers[].name')
for server in $servers; do
    monk server use $server
    if monk auth expired; then
        echo "$server: authentication expired"
    else
        tenant=$(monk --json auth status | jq -r '.current_context.tenant')
        echo "$server: authenticated to $tenant"
    fi
done
```

### **Automatic Re-authentication**
```bash
#!/bin/bash
# Ensure valid authentication before operations

if monk auth expired; then
    echo "Token expired, re-authenticating..."
    monk auth login $TENANT_NAME $USERNAME
fi

# Proceed with authenticated operations
monk data list users
```

### **Token Export for CI/CD**
```bash
# Export token for external use
token=$(monk auth token)
curl -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     "$API_URL/api/data/users"
```

## JWT Token Structure

monk-cli works with standard JWT tokens containing:

```json
{
  "sub": "admin",           // Username/subject
  "name": "Administrator",  // Display name
  "tenant": "my-app",      // Tenant identifier  
  "database": "tenant_abc123", // Database name
  "access": "full",        // Access level
  "iat": 1756464200,       // Issued at (timestamp)
  "exp": 1756550645        // Expires at (timestamp)
}
```

## Integration with Other Commands

Authentication enables all tenant-scoped operations:

```bash
# Authenticate first
monk auth login my-app admin

# Then access tenant resources
monk data list users          # Accesses authenticated tenant database
monk describe select         # Retrieves schemas for authenticated tenant
monk fs ls /data/              # Browses authenticated tenant filesystem
```

## Best Practices

1. **Environment Isolation**: Maintain separate authentication per server environment
2. **Token Management**: Monitor expiration and re-authenticate proactively  
3. **Role-Based Access**: Use appropriate user roles for different operations
4. **Session Security**: Protect auth.json file and avoid sharing tokens
5. **Context Awareness**: Always verify current authentication before data operations
6. **Automation**: Use `monk auth expired` in scripts for conditional re-authentication

Authentication commands provide **secure, multi-tenant access control** for all monk-cli data operations.