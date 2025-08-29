# Server Commands Documentation

## Overview

The `monk server` commands provide **remote server management** for connecting to multiple Monk API instances. These commands handle server registry, health monitoring, and context switching for multi-environment workflows.

**Format Note**: Server commands support both **text format** (human-readable tables) and **JSON format** (machine-readable data) via global `--text` and `--json` flags.

## Command Structure

```bash
monk [--text|--json] server <operation> [arguments] [flags]
```

## Available Commands

### **Server Registry Management**

#### **Add New Server**
```bash
monk server add <name> <endpoint> [--description <text>]
```

**Examples:**
```bash
# Local development server
monk server add local localhost:9001

# Remote servers with descriptions
monk server add staging api.staging.example.com:443 --description "Staging environment"
monk server add prod api.example.com:443 --description "Production API server"

# Custom ports
monk server add dev localhost:8080 --description "Development server"
```

**What Happens:**
1. Validates endpoint connectivity
2. Adds server to registry (`~/.config/monk/cli/server.json`)
3. Detects protocol (http/https) automatically
4. Records registration timestamp

#### **List All Servers**
```bash
monk server list
```

**Text Format (Default):**
```
Registered Servers

Name            Endpoint                       Status   Auth     Last Ping    Added                Description
--------------------------------------------------------------------------------------------------------
local           http://localhost:9001          up       yes (3)  2025-08-29   2025-08-28           Local development server *
staging         https://api.staging.com:443    down     no       2025-08-28   2025-08-28           Staging environment
production      https://api.example.com:443    up       yes (1)  2025-08-29   2025-08-28           Production API server
```
- `*` indicates current server
- Auth column shows session count
- Status updated from last ping

**JSON Format:**
```bash
monk --json server list
```
```json
{"servers":[{"name":"local","hostname":"localhost","port":9001,"protocol":"http","endpoint":"http://localhost:9001","status":"up","last_ping":"2025-08-29T11:20:29Z","added_at":"2025-08-28T17:41:55Z","description":"Local development server","auth_sessions":3,"is_current":true}],"current_server":"local"}
```

#### **Show Current Server**
```bash
monk server current
```

**Examples:**

**Text Format (Default):**
```
Current Server

Name: local
Endpoint: http://localhost:9001
Status: up
Description: Local development server
Auth Sessions: 3
```

**JSON Format:**
```bash
monk --json server current
```
```json
{"name":"local","hostname":"localhost","port":9001,"protocol":"http","endpoint":"http://localhost:9001","base_url":"http://localhost:9001","status":"up","description":"Local development server","auth_sessions":3}
```

#### **Switch Server Context**
```bash
monk server use <name>
```

**Examples:**
```bash
# Switch to development server
monk server use local

# Switch to production 
monk server use production

# Context affects all subsequent commands
monk auth login my-tenant admin  # Authenticates to selected server
```

#### **Remove Server**
```bash
monk server delete <name>
```

**Examples:**
```bash
# Remove server from registry
monk server delete old-server

# Cleans up associated authentication sessions
```

### **Health Monitoring**

#### **Ping Specific Server**
```bash
monk server ping [name]
```

**Examples:**

**Text Format (Default):**
```bash
monk server ping local
# Using current server: local
# Server is up and responding
# Response time: 12ms
```

**JSON Format:**
```bash
monk --json server ping local  
```
```json
{"server_name":"local","hostname":"localhost","port":9001,"protocol":"http","endpoint":"http://localhost:9001","status":"up","timestamp":"2025-08-29T11:25:00Z","response_time_ms":12,"success":true}
```

**Default Server:**
```bash
monk server ping        # Uses current server
monk server ping local  # Specific server
```

#### **Ping All Servers**
```bash
monk server ping-all
```

**Text Format (Default):**
```
Pinging All Servers

local           http://localhost:9001          up       12ms
staging         https://api.staging.com        down     timeout  
production      https://api.example.com        up       245ms

Summary: 2 up, 1 down (total: 3)
```

**JSON Format:**
```bash
monk --json server ping-all
```
```json
{"servers":[{"server_name":"local","hostname":"localhost","port":9001,"status":"up","response_time_ms":12,"success":true},{"server_name":"staging","hostname":"api.staging.com","port":443,"status":"down","success":false}],"summary":{"total":3,"up":2,"down":1}}
```

## Output Format Support

### **Text Format (Default)**
Optimized for human readability:
- **Tables**: Aligned columns with clear headers
- **Status Indicators**: Current server marked with `*`
- **Health Information**: Response times and status
- **Context Information**: Server selection and auth status

### **JSON Format** 
Compact single-line machine-readable data:
- **Automation Friendly**: Easy parsing with `jq`
- **Complete Data**: All fields available for processing
- **Consistent Structure**: Predictable JSON schema
- **Pipeline Safe**: Single-line output for reliable piping

## Multi-Environment Workflows

### **Environment Setup**
```bash
# Development
monk server add dev localhost:9001 --description "Local development"
monk server use dev

# Staging  
monk server add staging api-staging.company.com:443 --description "Staging environment"

# Production
monk server add prod api.company.com:443 --description "Production API"
```

### **Environment Switching**
```bash
# Work in development
monk server use dev
monk tenant use my-app
monk auth login my-app admin
monk data select users

# Switch to staging
monk server use staging  
monk tenant use my-app      # Same tenant, different server
monk auth login my-app admin # Re-authenticate for staging
monk data select users      # Now working with staging data
```

### **Health Monitoring Across Environments**
```bash
# Check all environments
monk server ping-all

# Monitor specific environment
monk server ping production

# JSON output for monitoring scripts
monk --json server ping-all | jq '.summary'
```

## Authentication Integration

Server registry tracks authentication sessions per server:

```bash
# Authentication is server-scoped
monk server use local
monk auth login my-app admin     # Creates session: local:my-app

monk server use staging  
monk auth login my-app admin     # Creates session: staging:my-app

# Sessions are independent per server
monk server list                 # Shows auth count per server
```

## Configuration Management

### **Server Registry Location**
`~/.config/monk/cli/server.json`

### **Custom Configuration Directory**
```bash
# Use custom config location
export MONK_CLI_CONFIG_DIR="/path/to/custom/config"
monk server add dev localhost:9001
```

### **Configuration Structure**
```json
{
  "servers": {
    "local": {
      "hostname": "localhost",
      "port": 9001,
      "protocol": "http", 
      "description": "Local development server",
      "added_at": "2025-08-29T10:30:00Z",
      "last_ping": "2025-08-29T11:20:00Z",
      "status": "up"
    }
  }
}
```

## Error Handling

### **Connection Errors**
```bash
monk server ping unreachable
# Error: Server is down or not responding
```

### **Registry Errors**
```bash
monk server use nonexistent
# Error: Server 'nonexistent' not found
# Use 'monk server list' to see available servers
```

### **No Server Selected**
```bash
monk server current
# Error: No current server selected  
# Use 'monk server use <name>' to select a server
```

## Automation Examples

### **Server Health Monitoring**
```bash
#!/bin/bash
# Monitor all servers and report status

servers=$(monk --json server list | jq -r '.servers[].name')
for server in $servers; do
    status=$(monk --json server ping $server | jq -r '.status' 2>/dev/null || echo "error")
    echo "$server: $status"
done
```

### **Environment Deployment Check**
```bash
#!/bin/bash  
# Verify all environments are healthy before deployment

result=$(monk --json server ping-all)
down_count=$(echo "$result" | jq '.summary.down')

if [ "$down_count" -gt 0 ]; then
    echo "❌ Some servers are down, aborting deployment"
    echo "$result" | jq -r '.servers[] | select(.success == false) | "  - \(.server_name): \(.status)"'
    exit 1
else
    echo "✅ All servers healthy, proceeding with deployment"
fi
```

### **Configuration Backup**
```bash
# Export server configuration
monk --json server list > server-backup.json

# Restore server configuration
jq -r '.servers[] | "monk server add \(.name) \(.endpoint) --description \"\(.description)\""' server-backup.json | bash
```

## Protocol Detection

Server commands automatically detect protocols:

```bash
monk server add api api.example.com:443    # Auto-detects HTTPS (port 443)
monk server add local localhost:9001       # Auto-detects HTTP (other ports)
monk server add secure https://api.com:443 # Explicit protocol override
```

## Best Practices

1. **Descriptive Names**: Use environment-based naming (dev, staging, prod)
2. **Regular Health Checks**: Monitor server connectivity with ping commands
3. **Context Awareness**: Always verify current server before operations
4. **Environment Isolation**: Maintain separate tenant configurations per server
5. **Backup Configuration**: Export server registry for team sharing

## Integration with Other Commands

Server selection affects all API-dependent commands:

```bash
# Set server context
monk server use production

# Affects these operations:
monk tenant list                # Lists tenants for production server
monk auth login my-app admin    # Authenticates to production
monk data select users          # Accesses production database
monk meta select schema         # Retrieves production schemas
```

Server commands provide the **foundation layer** for all monk-cli multi-environment operations.