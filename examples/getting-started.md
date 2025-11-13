# Basic Setup and First Connection

Get started with monk CLI by initializing configuration and connecting to your first Monk API server.

## Prerequisites
- Monk CLI installed
- Access to a Monk API server (running instance)

## Quick Start Workflow

### 1. Initialize CLI Configuration
```bash
monk init
```
This creates the necessary configuration directories and files.

### 2. Add Your Server
```bash
monk config server add dev localhost:3000 --description "Development server"
```
Replace `localhost:3000` with your actual server endpoint.

### 3. Switch to Your Server
```bash
monk config server use dev
```

### 4. Register Tenant and User
```bash
monk auth register myproject admin
```
This creates both the tenant and user account, and automatically logs you in.

### 5. Verify Connection
```bash
monk config server ping
monk auth status
```

## What This Sets Up

After running these commands, you'll have:
- ✅ CLI configuration initialized
- ✅ Server connection configured
- ✅ Tenant and user account created
- ✅ Authentication established and tenant selected
- ✅ Ready to work with data and schemas

## Expected Output

```bash
$ monk init
✓ CLI configuration initialized

$ monk config server add dev localhost:3000 --description "Development server"
✓ Server 'dev' added successfully

$ monk config server use dev
✓ Switched to server 'dev'

$ monk auth register myproject admin
✓ Success (200)
✓ Registration successful
ℹ Tenant: myproject
ℹ Database: tenant_abc123
ℹ Username: admin
ℹ Token expires in: 86400 seconds
ℹ JWT token stored for server+tenant context
✓ Tenant added to local registry for server: dev

$ monk config server ping
✓ Server 'dev' is healthy

$ monk auth status
Authenticated as: admin@myproject
Token expires: 2024-12-31 23:59:59
```

## Troubleshooting

### Connection Issues
```bash
# Check if server is running
monk config server ping dev

# Get detailed server info
monk config server info dev

# Check server health
monk config server health dev
```

### Authentication Issues
```bash
# Check auth status
monk auth status

# Clear and re-authenticate
monk auth logout
monk auth login myproject admin
```

## Next Steps
Now that you're connected, try:
- `monk examples tenant-management` - Learn about tenant operations
- `monk examples data-crud` - Start working with data
- `monk examples schema-creation` - Define your data structures</content>
<parameter name="filePath">/Users/ianzepp/Workspaces/monk-cli/examples/basic-setup.md