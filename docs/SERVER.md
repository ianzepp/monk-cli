# Server Commands Documentation

## Overview

The `monk config server` commands provide **remote server management** for connecting to multiple Monk API instances. These commands handle server registry, health monitoring, and context switching for multi-environment workflows.

**Format Note**: Server commands support both **text format** (human-readable tables) and **JSON format** (machine-readable data) via global `--text` and `--json` flags.

## Command Structure

```bash
monk [--text|--json] config server <operation> [arguments] [flags]
```

## Available Commands

### **Server Registry Management**

#### **Add New Server**
```bash
monk config server add <name> <endpoint> [--description <text>]
```

**Examples:**
```bash
# Local development server
monk config server add local localhost:9001

# Remote servers with descriptions
monk config server add staging api.staging.example.com:443 --description "Staging environment"
monk config server add prod api.example.com:443 --description "Production API server"

# Custom ports
monk config server add dev localhost:8080 --description "Development server"
```

**What Happens:**
1. Validates endpoint connectivity
2. Adds server to registry (`~/.config/monk/cli/server.json`)
3. Detects protocol (http/https) automatically
4. Records registration timestamp

#### **List All Servers**
```bash
monk config server list
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
monk config server current
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
monk config server use <name>
```

**Examples:**
```bash
# Switch to development server
monk config server use local

# Switch to production 
monk config server use production

# Context affects all subsequent commands
monk auth login my-tenant admin  # Authenticates to selected server
```

#### **Remove Server**
```bash
monk config server delete <name>
```

**Examples:**
```bash
# Remove server from registry
monk config server delete old-server

# Cleans up associated authentication sessions
```

### **Health Monitoring**

#### **Ping Specific Server**
```bash
monk config server ping [name]
```

**Examples:**

**Text Format (Default):**
```bash
monk config server ping local
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
monk config server ping        # Uses current server
monk config server ping local  # Specific server
```

#### **Server Information**
```bash
monk config server info [name]
```

**Examples:**

**Text Format (Default):**
```bash
monk config server info local
# Using current server: local

# Server Information: local

# Connection:
#   Endpoint: http://localhost:9001
#   Hostname: localhost
#   Port: 9001
#   Protocol: http

# API Details:
#   Name: Monk API (Hono)
#   Version: 2.0.0-rc2
#   Description: Lightweight PaaS backend API built with Hono

# Available Endpoints:
#   auth: /auth/*
#   docs: /docs[/*.md]
#   root: /root/* (localhost development only)
#   data: /api/data/:schema[/:record] (protected)
#   describe: /api/describe/:schema (protected)
#   find: /api/find/:schema (protected)
#   bulk: /api/bulk (protected)

# Documentation:
#   Overview: /README.md
#   auth: /docs/auth
#   data: /docs/data
#   describe: /docs/describe
#   Errors: /docs/errors
```

**JSON Format:**
```bash
monk --json server info local
```
```json
{"server_name":"local","hostname":"localhost","port":9001,"protocol":"http","endpoint":"http://localhost:9001","api":{"name":"Monk API (Hono)","version":"2.0.0-rc2","description":"Lightweight PaaS backend API built with Hono","endpoints":{"auth":"/auth/*","docs":"/docs[/*.md]","root":"/root/* (localhost development only)","data":"/api/data/:schema[/:record] (protected)","describe":"/api/describe/:schema (protected)","find":"/api/find/:schema (protected)","bulk":"/api/bulk (protected)"},"documentation":{"overview":"/README.md","apis":{"auth":"/docs/auth","data":"/docs/data","describe":"/docs/describe"},"errors":"/docs/errors"}},"status":"up","success":true}
```

**Default Server:**
```bash
monk config server info        # Uses current server
monk config server info local  # Specific server
```

#### **Server Health Check**
```bash
monk config server health [name]
```

**Examples:**

**Text Format (Default):**
```bash
monk config server health local
# Using current server: local

# Server Health: local

# Connection:
#   Endpoint: http://localhost:9001/health
#   Hostname: localhost
#   Port: 9001
#   Protocol: http

# Health Status:
#   Status: healthy
#   Version: 2.0.0-rc2
#   API Name: Monk API (Hono)
#   Uptime: 3h 24m
#   Timestamp: 2025-08-29T11:30:00Z

# Database Health:
#   Status: connected
#   Connected: true

# Server is healthy and operational
```

**JSON Format:**
```bash
monk --json server health local
```
```json
{"server_name":"local","hostname":"localhost","port":9001,"protocol":"http","endpoint":"http://localhost:9001","health":{"status":"healthy","version":"2.0.0-rc2","name":"Monk API (Hono)","uptime":"3h 24m","timestamp":"2025-08-29T11:30:00Z","database":{"status":"connected","connected":true},"checks":null},"success":true}
```

**Default Server:**
```bash
monk config server health        # Uses current server
monk config server health local  # Specific server
```

**Difference from `ping`:**
- `ping`: Simple connectivity check (faster, basic up/down status)
- `health`: Detailed health information from `/health` endpoint (slower, includes version, uptime, database status)
- `info`: API metadata and available endpoints from root endpoint

#### **Ping All Servers**
```bash
monk config server ping-all
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
monk config server add dev localhost:9001 --description "Local development"
monk config server use dev

# Staging  
monk config server add staging api-staging.company.com:443 --description "Staging environment"

# Production
monk config server add prod api.company.com:443 --description "Production API"
```

### **Environment Switching**
```bash
# Work in development
monk config server use dev
monk config tenant use my-app
monk auth login my-app admin
monk data list users

# Switch to staging
monk config server use staging  
monk config tenant use my-app      # Same tenant, different server
monk auth login my-app admin # Re-authenticate for staging
monk data list users      # Now working with staging data
```

### **Health Monitoring Across Environments**
```bash
# Check all environments
monk config server ping-all

# Monitor specific environment
monk config server ping production

# JSON output for monitoring scripts
monk --json server ping-all | jq '.summary'
```

## Authentication Integration

Server registry tracks authentication sessions per server:

```bash
# Authentication is server-scoped
monk config server use local
monk auth login my-app admin     # Creates session: local:my-app

monk config server use staging  
monk auth login my-app admin     # Creates session: staging:my-app

# Sessions are independent per server
monk config server list                 # Shows auth count per server
```

## Configuration Management

### **Server Registry Location**
`~/.config/monk/cli/server.json`

### **Custom Configuration Directory**
```bash
# Use custom config location
export MONK_CLI_CONFIG_DIR="/path/to/custom/config"
monk config server add dev localhost:9001
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
monk config server ping unreachable
# Error: Server is down or not responding
```

### **Registry Errors**
```bash
monk config server use nonexistent
# Error: Server 'nonexistent' not found
# Use 'monk config server list' to see available servers
```

### **No Server Selected**
```bash
monk config server current
# Error: No current server selected  
# Use 'monk config server use <name>' to select a server
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
jq -r '.servers[] | "monk config server add \(.name) \(.endpoint) --description \"\(.description)\""' server-backup.json | bash
```

## Protocol Detection

Server commands automatically detect protocols:

```bash
monk config server add api api.example.com:443    # Auto-detects HTTPS (port 443)
monk config server add local localhost:9001       # Auto-detects HTTP (other ports)
monk config server add secure https://api.com:443 # Explicit protocol override
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
monk config server use production

# Affects these operations:
monk config tenant list                # Lists tenants for production server
monk auth login my-app admin    # Authenticates to production
monk data list users          # Accesses production database
monk describe select         # Retrieves production schemas
```

Server commands provide the **foundation layer** for all monk-cli multi-environment operations.